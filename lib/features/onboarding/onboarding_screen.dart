import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/services/system_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../l10n/l10n.dart';
import '../../languages/models.dart';
import '../home/home_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;
  static const _count = 5;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _go(int page) async {
    setState(() => _page = page);
    await _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(onboardingDone: true));
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = _page == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _WelcomePage(),
                  _LanguagePage(),
                  _LevelPage(),
                  _GoalPage(),
                  _VoicePage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _count; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? context.scheme.primary
                                : context.scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: last ? _finish : () => _go(_page + 1),
                    child: Text(
                      _page == 0
                          ? l.onbGetStarted
                          : last
                          ? l.onbStart
                          : l.commonNext,
                    ),
                  ),
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _go(_page - 1),
                      child: Text(l.commonBack),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, this.body, required this.child});

  final String title;
  final String? body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Text(
          title,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!, style: context.text.bodyLarge),
        ],
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: Brand.vermilion,
              borderRadius: BorderRadius.circular(36),
            ),
            alignment: Alignment.center,
            child: const Text(
              '15',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l.onbWelcomeTitle,
            textAlign: TextAlign.center,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.onbWelcomeBody,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).value;
    final registry = ref.watch(languageRegistryProvider).value;
    return _PageFrame(
      title: l.onbLanguageTitle,
      child: Column(
        children: [
          for (final lang
              in registry?.available ?? const <LanguageSummary>[]) ...[
            Card(
              color: content?.pack.id == lang.id
                  ? context.scheme.primaryContainer
                  : null,
              child: ListTile(
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(languageId: lang.id)),
                leading: Text(lang.flag, style: const TextStyle(fontSize: 32)),
                title: Text(
                  lang.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(lang.nativeName),
                trailing: content?.pack.id == lang.id
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          for (final c
              in registry?.comingSoon ?? const <ComingSoonLanguage>[]) ...[
            Card(
              child: ListTile(
                enabled: false,
                leading: Text(c.flag, style: const TextStyle(fontSize: 32)),
                title: Text(c.name),
                subtitle: Text('${c.nativeName} · ${l.onbComingSoon}'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LevelPage extends ConsumerWidget {
  const _LevelPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).value;
    final settings = ref.watch(settingsProvider);
    if (content == null) {
      return MessageView(message: l.commonLoading, loading: true);
    }
    final current = settings.levelFor(content.pack.id);
    return _PageFrame(
      title: l.onbLevelTitle,
      child: Column(
        children: [
          for (final info in content.pack.levels) ...[
            Card(
              color: info.number == current
                  ? context.scheme.primaryContainer
                  : null,
              child: ListTile(
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setLevel(content.pack.id, info.number),
                title: Text(
                  info.number == 1
                      ? l.onbLevelBeginner
                      : '${info.name} · ${info.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  info.number == 1 ? l.onbLevelBeginnerBody : info.description,
                ),
                trailing: info.number == current
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _GoalPage extends ConsumerWidget {
  const _GoalPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final goal = ref.watch(settingsProvider.select((s) => s.dailyGoalMinutes));
    return _PageFrame(
      title: l.onbGoalTitle,
      body: l.onbGoalBody,
      child: Column(
        children: [
          for (final m in const [5, 10, 15]) ...[
            Card(
              color: m == goal ? context.scheme.primaryContainer : null,
              child: ListTile(
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(dailyGoalMinutes: m)),
                leading: const Icon(Icons.timer_outlined),
                title: Text(
                  l.commonMinutesLong(m),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: m == goal
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _VoicePage extends ConsumerWidget {
  const _VoicePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ready = ref.watch(speakerReadyProvider);
    return _PageFrame(
      title: l.onbVoiceTitle,
      child: ready.when(
        loading: () => MessageView(message: l.commonLoading, loading: true),
        error: (_, _) => Text(l.onbVoiceMissing),
        data: (ok) => Column(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.volume_off_rounded,
              size: 64,
              color: ok ? context.appColors.success : context.scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              ok ? l.onbVoiceReady : l.onbVoiceMissing,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (ok)
              OutlinedButton.icon(
                onPressed: () => unawaited(
                  ref
                      .read(speakerProvider)
                      .speak(
                        ref.read(contentProvider).value?.pack.voiceTestPhrase ??
                            '',
                      ),
                ),
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(l.onbVoiceTest),
              )
            else ...[
              Text(l.voiceInstallHint, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: openVoiceSettings,
                icon: const Icon(Icons.settings_voice_rounded),
                label: Text(l.voiceOpenSettings),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(speakerReadyProvider),
                child: Text(l.voiceCheckAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
