import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad unit ids. Debug and profile builds always use Google's public test ids.
/// Release builds read real ids from `--dart-define` (see docs/ads.md); if
/// they are missing, release builds show no ads rather than test ads.
class AdUnits {
  const AdUnits._();

  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const _banner = String.fromEnvironment('AD_BANNER_ID');
  static const _interstitial = String.fromEnvironment('AD_INTERSTITIAL_ID');
  static const _rewarded = String.fromEnvironment('AD_REWARDED_ID');

  /// True when at least one ad unit is usable in this build.
  static bool get anyConfigured =>
      banner != null || interstitial != null || rewarded != null;

  static String? get banner =>
      kReleaseMode ? (_banner.isEmpty ? null : _banner) : _testBanner;
  static String? get interstitial => kReleaseMode
      ? (_interstitial.isEmpty ? null : _interstitial)
      : _testInterstitial;
  static String? get rewarded =>
      kReleaseMode ? (_rewarded.isEmpty ? null : _rewarded) : _testRewarded;
}

/// Decides when a full-screen ad may appear. Pure so it can be unit tested.
///
/// Rules, chosen to keep a short daily study habit pleasant:
/// - never during a lesson, only on the lesson-complete screen;
/// - never after the first lesson of the day;
/// - at most one ad per two completed lessons;
/// - at least [minGap] since the previous full-screen ad.
class InterstitialPolicy {
  const InterstitialPolicy({
    this.lessonsPerAd = 2,
    this.minGap = const Duration(minutes: 4),
  });

  final int lessonsPerAd;
  final Duration minGap;

  bool shouldShow({
    required int lessonsCompletedToday,
    required int lessonsSinceLastAd,
    required DateTime now,
    required DateTime? lastShown,
  }) {
    if (lessonsCompletedToday < 2) return false;
    if (lessonsSinceLastAd < lessonsPerAd) return false;
    if (lastShown != null && now.difference(lastShown) < minGap) return false;
    return true;
  }
}

/// Ads and the privacy-consent flow behind one interface, so screens never
/// touch the AdMob SDK directly and tests run ad-free.
abstract class AdService {
  /// Starts the consent flow and the ads SDK. Safe to call more than once.
  Future<void> init();

  /// Whether ads may be requested right now (consent given, unit ids set).
  bool get canShowAds;

  /// Whether the user can reopen their privacy choices.
  Future<bool> get privacyOptionsRequired;

  Future<void> showPrivacyOptions();

  /// A banner widget, or an empty box when ads are off.
  Widget banner(BuildContext context);

  /// Shows a full-screen ad if one is ready. Completes when it is dismissed.
  Future<void> showInterstitial();

  /// Shows a rewarded ad; true when the learner earned the reward.
  Future<bool> showRewarded();
}

class NoAdService implements AdService {
  const NoAdService();

  @override
  Future<void> init() async {}

  @override
  bool get canShowAds => false;

  @override
  Future<bool> get privacyOptionsRequired async => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Widget banner(BuildContext context) => const SizedBox.shrink();

  @override
  Future<void> showInterstitial() async {}

  @override
  Future<bool> showRewarded() async => false;
}

/// AdMob implementation with Google's User Messaging Platform consent.
class AdMobService implements AdService {
  bool _initStarted = false;
  bool _canRequest = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  @override
  bool get canShowAds => _canRequest;

  @override
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    // No real ad units (a release build without --dart-define ids): stay
    // fully ad-free, with no consent form and no SDK start.
    if (!AdUnits.anyConfigured) return;
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          if (!done.isCompleted) done.complete();
        },
        (error) {
          debugPrint('Consent update failed: ${error.message}');
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
      _canRequest = await ConsentInformation.instance.canRequestAds();
      if (!_canRequest) return;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      await MobileAds.instance.initialize();
      _loadInterstitial();
      _loadRewarded();
    } on Object catch (e) {
      debugPrint('Ads init failed: $e');
      _canRequest = false;
    }
  }

  @override
  Future<bool> get privacyOptionsRequired async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } on Object catch (e) {
      debugPrint('Privacy options failed: $e');
    }
  }

  void _loadInterstitial() {
    final id = AdUnits.interstitial;
    if (id == null || !_canRequest) return;
    InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (e) =>
            debugPrint('Interstitial failed: ${e.message}'),
      ),
    );
  }

  void _loadRewarded() {
    final id = AdUnits.rewarded;
    if (id == null || !_canRequest) return;
    RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => debugPrint('Rewarded failed: ${e.message}'),
      ),
    );
  }

  @override
  Widget banner(BuildContext context) {
    final id = AdUnits.banner;
    if (!_canRequest || id == null) return const SizedBox.shrink();
    return _BannerSlot(adUnitId: id);
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
    );
    await ad.show();
    await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await done.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    return earned;
  }
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot({required this.adUnitId});

  final String adUnitId;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
          MediaQuery.orientationOf(context),
          width,
        );
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, e) {
          debugPrint('Banner failed: ${e.message}');
          a.dispose();
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
