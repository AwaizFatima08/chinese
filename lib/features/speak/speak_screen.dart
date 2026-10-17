import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../data/progress_models.dart';
import '../../l10n/l10n.dart';
import 'speak_content.dart';
import 'speak_providers.dart';

/// The Speak tab: accent, pronunciation and vocabulary practice for people
/// who already speak English and want to sound clearer.
class SpeakScreen extends ConsumerWidget {
  const SpeakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final contentAsync = ref.watch(speakContentProvider);
    final progressAsync = ref.watch(speakProgressProvider);
    final settings = ref.watch(settingsProvider);

    if (contentAsync.hasError) {
      return MessageView(
        message: l.commonError,
        icon: Icons.error_outline_rounded,
        actionLabel: l.commonRetry,
        onAction: () => ref.invalidate(speakContentProvider),
      );
    }
    final content = contentAsync.value;
    if (content == null) {
      return MessageView(message: l.commonLoading, loading: true);
    }
    final progress = progressAsync.value;
    final due =
        progress?.dueWordIds(dayNumber(ref.read(clockProvider).now())).length ??
        0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              l.speakTitle,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(l.speakSubtitle, style: context.text.bodyLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Text(l.speakAccent, style: context.text.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'US', label: Text(l.speakUS)),
                      ButtonSegment(value: 'UK', label: Text(l.speakUK)),
                    ],
                    selected: {settings.englishAccent},
                    onSelectionChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .update((s) => s.copyWith(englishAccent: v.first)),
                  ),
                ),
              ],
            ),
          ),
          if (due > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                color: context.scheme.primaryContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.replay_rounded,
                    color: context.scheme.onPrimaryContainer,
                  ),
                  title: Text(
                    l.speakReviewTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.scheme.onPrimaryContainer,
                    ),
                  ),
                  subtitle: Text(
                    l.speakReviewBody(due),
                    style: TextStyle(color: context.scheme.onPrimaryContainer),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/speak/review'),
                ),
              ),
            ),
          for (final g in content.groups)
            _GroupTile(group: g, progress: progress),
          _Notice(icon: Icons.info_outline_rounded, text: l.speakIpaNote),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.progress});

  final PracticeGroup group;
  final SpeakProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (title, body, icon) = switch (group.kind) {
      SetKind.sounds => (
        l.speakSecSounds,
        l.speakSecSoundsBody,
        Icons.hearing_rounded,
      ),
      SetKind.stress => (
        l.speakSecStress,
        l.speakSecStressBody,
        Icons.format_bold_rounded,
      ),
      SetKind.vocab => (
        l.speakSecVocab,
        l.speakSecVocabBody,
        Icons.menu_book_rounded,
      ),
      SetKind.shadow => (
        l.speakSecShadow,
        l.speakSecShadowBody,
        Icons.record_voice_over_rounded,
      ),
      SetKind.twister => (
        l.speakSecTwisters,
        l.speakSecTwistersBody,
        Icons.speed_rounded,
      ),
      SetKind.melody => (
        l.speakSecMelody,
        l.speakSecMelodyBody,
        Icons.show_chart_rounded,
      ),
      SetKind.talk => (l.speakSecTalk, l.speakSecTalkBody, Icons.forum_rounded),
      SetKind.review => ('', '', Icons.replay_rounded),
    };
    final done = group.sets.where((s) => progress?.starsFor(s.id) != 0).length;

    final children = <Widget>[];
    if (group.kind == SetKind.vocab) {
      final byUnit = <String, List<PracticeSet>>{};
      for (final s in group.sets) {
        final unit = s.id.split(':')[1];
        byUnit.putIfAbsent(unit, () => []).add(s);
      }
      for (final e in byUnit.entries) {
        children.add(
          ExpansionTile(
            tilePadding: const EdgeInsets.only(left: 32, right: 16),
            title: Text(group.unitTitles['voc:${e.key}'] ?? e.key),
            children: [
              for (final s in e.value) _SetTile(set: s, progress: progress),
            ],
          ),
        );
      }
    } else {
      children.addAll([
        for (final s in group.sets) _SetTile(set: s, progress: progress),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(icon, color: context.scheme.primary),
          title: Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text('$body\n${l.speakDoneCount(done, group.sets.length)}'),
          children: children,
        ),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.set, required this.progress});

  final PracticeSet set;
  final SpeakProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stars = progress?.starsFor(set.id) ?? 0;
    final title = set.kind == SetKind.twister
        ? l.speakTwisterSet(set.title)
        : set.title;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text(title),
      subtitle: set.subtitle.isEmpty
          ? null
          : Text(set.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 3; i++)
            Icon(
              i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: context.appColors.gold,
            ),
        ],
      ),
      onTap: () => context.push('/speak/${Uri.encodeComponent(set.id)}'),
    );
  }
}
