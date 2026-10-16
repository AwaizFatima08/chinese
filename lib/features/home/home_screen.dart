import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/services/system_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../l10n/l10n.dart';
import '../../languages/models.dart';
import '../path/path_logic.dart';
import '../progress/progress_state.dart';
import 'home_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider);
    final progress = ref.watch(progressProvider);
    if (content.hasError || progress.hasError) {
      return MessageView(
        message: l.commonError,
        icon: Icons.error_outline_rounded,
        actionLabel: l.commonRetry,
        onAction: () => ref
          ..invalidate(contentProvider)
          ..invalidate(progressProvider),
      );
    }
    final c = content.value;
    final p = progress.value;
    if (c == null || p == null) {
      return MessageView(message: l.commonLoading, loading: true);
    }
    final settings = ref.watch(settingsProvider);
    final level =
        c.levels['hsk${settings.levelFor(c.pack.id)}'] ?? c.levels.values.first;
    final logic = PathLogic(p, unlockAll: settings.unlockAll);
    final next = logic.nextLesson(level);
    final goal = settings.dailyGoalMinutes;
    final doneMinutes = (p.todayLog.seconds / 60).floor();
    final voiceMissing = ref.watch(speakerReadyProvider).value == false;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.homeTitle,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(child: _StreakChip(days: p.streak)),
            ],
          ),
          const SizedBox(height: 12),
          _GoalCard(doneMinutes: doneMinutes, goalMinutes: goal),
          if (voiceMissing) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.volume_off_rounded,
              text: l.homeVoiceBanner,
              onTap: openVoiceSettings,
            ),
          ],
          if (p.repairDay >= 0) ...[
            const SizedBox(height: 12),
            _RepairCard(day: p.repairDay),
          ],
          const SizedBox(height: 16),
          if (next != null)
            _LessonCard(lesson: next, levelName: level.info.name)
          else
            SoftCard(
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: context.appColors.gold,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.homeLevelDone, style: context.text.titleMedium),
                        Text(
                          l.homeLevelDoneBody,
                          style: context.text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _ReviewCard(due: p.dueCount, doneToday: p.todayLog.reviews > 0),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final active = days > 0;
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: active ? scheme.primary : scheme.outline,
            size: 22,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.homeStreak(days),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.doneMinutes, required this.goalMinutes});

  final int doneMinutes;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reached = doneMinutes >= goalMinutes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(
              value: goalMinutes == 0 ? 0 : doneMinutes / goalMinutes,
              size: 76,
              strokeWidth: 9,
              child: reached
                  ? Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: context.appColors.success,
                    )
                  : Text(
                      '$doneMinutes',
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.homeGoalTitle, style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    reached
                        ? l.homeGoalDone
                        : l.homeGoalProgress(doneMinutes, goalMinutes),
                    style: context.text.titleSmall?.copyWith(
                      color: reached ? context.appColors.success : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (reached) ...[
                    const SizedBox(height: 2),
                    Text(l.homeGoalDoneBody, style: context.text.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: context.scheme.tertiaryContainer,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: context.scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.scheme.onTertiaryContainer),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.scheme.onTertiaryContainer,
          ),
        ],
      ),
    );
  }
}

class _RepairCard extends ConsumerWidget {
  const _RepairCard({required this.day});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = context.scheme;
    return SoftCard(
      color: scheme.secondaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: scheme.secondary,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeRepairTitle, style: context.text.titleMedium),
                Text(l.homeRepairBody, style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final earned = await ref.read(adServiceProvider).showRewarded();
              if (earned) {
                await ref.read(progressProvider.notifier).repairStreak(day);
                messenger.showSnackBar(
                  SnackBar(content: Text(l.homeRepairDone)),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text(l.homeRepairNoVideo)),
                );
              }
            },
            child: Text(l.homeRepairButton),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.due, required this.doneToday});

  final int due;
  final bool doneToday;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ready = due > 0;
    return SoftCard(
      onTap: ready ? () => context.push('/review') : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: context.scheme.secondaryContainer,
            child: Icon(
              doneToday && !ready ? Icons.check_rounded : Icons.replay_rounded,
              color: context.scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeReviewTitle, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  ready ? l.homeReviewBody(due) : l.homeReviewNone,
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
          if (ready)
            Text(
              l.commonMinutes(3),
              style: context.text.labelMedium?.copyWith(
                color: context.scheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.levelName});

  final Lesson lesson;
  final String levelName;

  IconData get _icon => switch (lesson.type) {
    LessonType.vocab => Icons.translate_rounded,
    LessonType.grammar => Icons.account_tree_rounded,
    LessonType.checkpoint => Icons.flag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    return Card(
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l.homeNextTitle} · $levelName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l.commonMinutes(lesson.minutes),
                  style: context.text.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lesson.title,
              style: context.text.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lesson.subtitle,
              style: context.text.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/lesson/${lesson.id}'),
              child: Text(l.homeStartLesson),
            ),
          ],
        ),
      ),
    );
  }
}
