import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import '../account/account_controller.dart';
import '../progress/progress_state.dart';

/// True once the teacher voice engine has been prepared for the current language.
final speakerReadyProvider = FutureProvider<bool>((ref) async {
  final content = await ref.watch(contentProvider.future);
  return ref.read(speakerProvider).init(content.pack.ttsLocale);
});

/// Starts the consent flow and ads SDK; true when ads may be shown.
final adsReadyProvider = FutureProvider<bool>((ref) async {
  final ads = ref.watch(adServiceProvider);
  await ads.init();
  return ads.canShowAds;
});

/// Bottom navigation around the four main tabs, with the banner ad slot.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A new day may have started while the app was in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
        ..invalidate(progressProvider)
        ..invalidate(speakerReadyProvider);
      unawaited(ref.read(accountProvider.notifier).sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final l = context.l10n;
    // Warm up the voice and ads once the main screens appear.
    ref
      ..watch(speakerReadyProvider)
      ..watch(adsReadyProvider)
      ..watch(accountProvider);
    final ads = ref.watch(adServiceProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: shell),
          // Banner ads live only on these tabs, never inside a lesson.
          if (ref.watch(adsReadyProvider).value ?? false)
            SafeArea(top: false, bottom: false, child: ads.banner(context)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today_rounded),
            label: l.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route_rounded),
            label: l.navPath,
          ),
          NavigationDestination(
            icon: const Icon(Icons.record_voice_over_outlined),
            selectedIcon: const Icon(Icons.record_voice_over_rounded),
            label: l.navSpeak,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: l.navProgress,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}
