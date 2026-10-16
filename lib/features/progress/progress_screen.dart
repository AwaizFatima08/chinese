import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../data/progress_models.dart';
import '../../l10n/l10n.dart';
import '../path/path_logic.dart';
import 'progress_state.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).value;
    final p = ref.watch(progressProvider).value;
    if (content == null || p == null) {
      return MessageView(message: l.commonLoading, loading: true);
    }
    final settings = ref.watch(settingsProvider);
    final logic = PathLogic(p);
    final hours = p.totalSeconds ~/ 3600;
    final minutes = (p.totalSeconds % 3600) ~/ 60;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            l.progTitle,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(
            _Stat(
              icon: Icons.local_fire_department_rounded,
              label: l.progStreak,
              value: l.progStreakDays(p.streak),
            ),
            _Stat(
              icon: Icons.timer_outlined,
              label: l.progTotalTime,
              value: l.progTimeValue(hours, minutes),
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            _Stat(
              icon: Icons.menu_book_rounded,
              label: l.progWordsLearned,
              value: '${p.learnedCount}',
            ),
            _Stat(
              icon: Icons.workspace_premium_rounded,
              label: l.progWordsMastered,
              value: '${p.masteredCount}',
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            _Stat(
              icon: Icons.draw_rounded,
              label: l.progCharsWritten,
              value: '${p.charactersWritten.length}',
            ),
            _Stat(
              icon: Icons.replay_rounded,
              label: l.progDue,
              value: '${p.dueCount}',
            ),
          ),
          const SizedBox(height: 24),
          Text(l.progWeek, style: context.text.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: _WeekChart(
                days: p.week,
                goalMinutes: settings.dailyGoalMinutes,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l.progLevels, style: context.text.titleMedium),
          const SizedBox(height: 12),
          for (final info in content.pack.levels) ...[
            Builder(
              builder: (context) {
                final level = content.levels[info.id]!;
                return SoftCard(
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setLevel(content.pack.id, info.number);
                    context.go('/path');
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${info.name} · ${info.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.pathLevelProgress(
                              logic.completedIn(level),
                              level.lessons.length,
                            ),
                            style: context.text.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: logic.fractionDone(level),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/words'),
            icon: const Icon(Icons.search_rounded),
            label: Text(l.progBrowse),
          ),
        ],
      ),
    );
  }
}

/// Two stat cards of equal height that grow with the text size.
class _StatRow extends StatelessWidget {
  const _StatRow(this.left, this.right);

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: context.scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seven bars of minutes studied, with the daily goal marked.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days, required this.goalMinutes});

  final List<DayLog> days;
  final int goalMinutes;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final maxMin = days.fold<int>(
      goalMinutes,
      (m, d) => d.minutes > m ? d.minutes : m,
    );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    d.minutes > 0 ? '${d.minutes}' : '',
                    style: context.text.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: maxMin == 0
                        ? 4
                        : (90 * d.minutes / maxMin).clamp(4, 90).toDouble(),
                    decoration: BoxDecoration(
                      color: d.minutes >= goalMinutes
                          ? context.appColors.success
                          : d.minutes > 0
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Day number 0 is a Thursday (1970-01-01), so day % 7 maps to a weekday.
                  Text(
                    _weekdays[(d.day + 3) % 7],
                    style: context.text.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
