import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/services/system_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../data/settings.dart';
import '../../l10n/l10n.dart';
import '../../languages/models.dart';
import '../home/home_shell.dart';
import '../progress/progress_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).value;
    if (content == null) {
      return MessageView(message: l.commonLoading, loading: true);
    }
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final voiceOk = ref.watch(speakerReadyProvider).value ?? false;
    final ads = ref.watch(adServiceProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              l.setTitle,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _Section(l.setLearning),
          ListTile(
            leading: Text(
              content.pack.flag,
              style: const TextStyle(fontSize: 28),
            ),
            title: Text(l.setLanguage),
            subtitle: Text('${content.pack.name} · ${content.pack.nativeName}'),
            onTap: () => _chooseLanguage(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l.setDailyGoal),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.setDailyGoalBody),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (final m in const [5, 10, 15])
                      ButtonSegment(value: m, label: Text(l.commonMinutes(m))),
                  ],
                  selected: {s.dailyGoalMinutes},
                  onSelectionChanged: (v) => notifier.update(
                    (x) => x.copyWith(dailyGoalMinutes: v.first),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_open_rounded),
            title: Text(l.setUnlockAll),
            subtitle: Text(l.setUnlockAllBody),
            value: s.unlockAll,
            onChanged: (v) => notifier.update((x) => x.copyWith(unlockAll: v)),
          ),
          _Section(l.setVoice),
          SwitchListTile(
            secondary: const Icon(Icons.slow_motion_video_rounded),
            title: Text(l.setSlow),
            subtitle: Text(l.setSlowBody),
            value: s.slowSpeech,
            onChanged: (v) => notifier.update((x) => x.copyWith(slowSpeech: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: Text(l.setAutoPlay),
            value: s.autoPlay,
            onChanged: (v) => notifier.update((x) => x.copyWith(autoPlay: v)),
          ),
          ListTile(
            leading: Icon(
              voiceOk ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            title: Text(voiceOk ? l.setVoiceTest : l.voiceOpenSettings),
            subtitle: voiceOk ? null : Text(l.setVoiceNone),
            onTap: voiceOk
                ? () => unawaited(
                    ref
                        .read(speakerProvider)
                        .speak('你好！欢迎学习中文。', slow: s.slowSpeech),
                  )
                : openVoiceSettings,
          ),
          _Section(l.setDisplay),
          ListTile(
            leading: const Icon(Icons.abc_rounded),
            title: Text(l.setRoman(content.pack.romanizationLabel)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<RomanizationMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: RomanizationMode.always,
                    label: Text(l.setRomanAlways),
                  ),
                  ButtonSegment(
                    value: RomanizationMode.tapToReveal,
                    label: Text(l.setRomanTap),
                  ),
                  ButtonSegment(
                    value: RomanizationMode.hidden,
                    label: Text(l.setRomanHidden),
                  ),
                ],
                selected: {s.romanization},
                onSelectionChanged: (v) =>
                    notifier.update((x) => x.copyWith(romanization: v.first)),
              ),
            ),
          ),
          if (content.pack.hasTones)
            SwitchListTile(
              secondary: const Icon(Icons.palette_outlined),
              title: Text(l.setToneColors),
              subtitle: Text(l.setToneColorsBody),
              value: s.toneColors,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(toneColors: v)),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: Text(l.setHaptics),
            value: s.haptics,
            onChanged: (v) => notifier.update((x) => x.copyWith(haptics: v)),
          ),
          _Section(l.setPrivacy),
          FutureBuilder<bool>(
            future: ads.privacyOptionsRequired,
            builder: (context, snap) => snap.data == true
                ? ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(l.setPrivacyOptions),
                    onTap: () => unawaited(ads.showPrivacyOptions()),
                  )
                : const SizedBox.shrink(),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l.setAbout),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/about'),
          ),
          _Section(l.setData),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: context.scheme.error,
            ),
            title: Text(
              l.setResetLanguage,
              style: TextStyle(color: context.scheme.error),
            ),
            onTap: () => _confirmReset(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.setResetConfirmTitle),
        content: Text(l.setResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.setResetConfirm),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(progressProvider.notifier).resetLanguage();
      messenger.showSnackBar(SnackBar(content: Text(l.setResetDone)));
    }
  }

  void _chooseLanguage(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.read(settingsProvider).languageId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final reg = ref.watch(languageRegistryProvider).value;
            final available = reg?.available ?? ['zh'];
            return ListView(
              shrinkWrap: true,
              children: [
                for (final id in available)
                  _LanguageTile(id: id, selected: id == current),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    l.setMoreLanguages,
                    style: context.text.titleSmall,
                  ),
                ),
                for (final c in reg?.comingSoon ?? const <ComingSoonLanguage>[])
                  ListTile(
                    enabled: false,
                    leading: Text(c.flag, style: const TextStyle(fontSize: 28)),
                    title: Text(c.name),
                    subtitle: Text('${c.nativeName} · ${l.onbComingSoon}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.id, required this.selected});

  final String id;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).value;
    final name = content != null && content.pack.id == id
        ? '${content.pack.name} · ${content.pack.nativeName}'
        : id;
    return ListTile(
      leading: Text(
        content != null && content.pack.id == id ? content.pack.flag : '',
        style: const TextStyle(fontSize: 28),
      ),
      title: Text(name),
      trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
      onTap: () async {
        await ref
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(languageId: id));
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: context.text.labelMedium?.copyWith(
          color: context.scheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
