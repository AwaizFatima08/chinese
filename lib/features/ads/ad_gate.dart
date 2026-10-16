import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/services/ad_service.dart';

/// Applies the [InterstitialPolicy] using counters kept on the device.
class AdGate {
  AdGate(this._prefs, this._clock, this._ads, {InterstitialPolicy? policy})
    : _policy = policy ?? const InterstitialPolicy();

  final SharedPreferences _prefs;
  final Clock _clock;
  final AdService _ads;
  final InterstitialPolicy _policy;

  static const _sinceKey = 'ads.lessonsSinceLastAd';
  static const _lastKey = 'ads.lastShownMs';

  /// Counts a finished lesson toward the next ad.
  Future<void> recordLessonDone() async {
    await _prefs.setInt(_sinceKey, (_prefs.getInt(_sinceKey) ?? 0) + 1);
  }

  /// Shows a full-screen ad if the policy allows. Call only on the
  /// lesson-complete screen, never during a lesson.
  Future<void> maybeShow({required int lessonsCompletedToday}) async {
    if (!_ads.canShowAds) return;
    final lastMs = _prefs.getInt(_lastKey);
    final last = lastMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastMs);
    final ok = _policy.shouldShow(
      lessonsCompletedToday: lessonsCompletedToday,
      lessonsSinceLastAd: _prefs.getInt(_sinceKey) ?? 0,
      now: _clock.now(),
      lastShown: last,
    );
    if (!ok) return;
    await _prefs.setInt(_sinceKey, 0);
    await _prefs.setInt(_lastKey, _clock.now().millisecondsSinceEpoch);
    await _ads.showInterstitial();
  }
}

final adGateProvider = Provider<AdGate>(
  (ref) => AdGate(
    ref.watch(sharedPreferencesProvider),
    ref.watch(clockProvider),
    ref.watch(adServiceProvider),
  ),
);
