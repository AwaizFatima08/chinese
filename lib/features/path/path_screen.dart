import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../l10n/l10n.dart';
import '../../languages/language_content.dart';
import '../../languages/models.dart';
import '../progress/progress_state.dart';
import 'path_logic.dart';

sealed class _Row {
  const _Row();
}

class _UnitHeader extends _Row {
  const _UnitHeader(this.title);
  final String title;
}

class _LessonRow extends _Row {
  const _LessonRow(this.lesson, this.state);
  final Lesson lesson;
  final LessonState state;
}

class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).value;
    final progress = ref.watch(progressProvider).value;
    if (content == null || progress == null) {
      return MessageView(message: l.commonLoading, loading: true);
    }
    final settings = ref.watch(settingsProvider);
    final current = settings.levelFor(content.pack.id);
    final level = content.levels['hsk$current'] ?? content.levels.values.first;
    final logic = PathLogic(progress, unlockAll: settings.unlockAll);
    final states = logic.statesFor(level);

    final rows = <_Row>[];
    for (final unit in level.units) {
      rows.add(_UnitHeader(unit.title));
      for (final lesson in unit.lessons) {
        rows.add(_LessonRow(lesson, states[lesson.id]!));
      }
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              l.pathTitle,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final info in content.pack.levels)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(info.name),
                      selected: info.number == current,
                      onSelected: (_) => ref
                          .read(settingsProvider.notifier)
                          .setLevel(content.pack.id, info.number),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: _LevelHeader(level: level, logic: logic),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                return switch (row) {
                  _UnitHeader() => Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      row.title,
                      style: context.text.titleSmall?.copyWith(
                        color: context.scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _LessonRow() => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LessonTile(
                      lesson: row.lesson,
                      state: row.state,
                      stars: progress.lessons[row.lesson.id]?.stars ?? 0,
                      onTap: () => _showLesson(
                        context,
                        content,
                        row.lesson,
                        row.state,
                        progress.lessons[row.lesson.id]?.stars ?? 0,
                      ),
                    ),
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLesson(
    BuildContext context,
    LanguageContent content,
    Lesson lesson,
    LessonState state,
    int stars,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LessonSheet(
        content: content,
        lesson: lesson,
        state: state,
        stars: stars,
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.level, required this.logic});

  final Level level;
  final PathLogic logic;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final done = logic.completedIn(level);
    final total = level.lessons.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${level.info.name} · ${level.info.title}',
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(level.info.description, style: context.text.bodyMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: logic.fractionDone(level),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.pathLevelProgress(done, total),
              style: context.text.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.state,
    required this.stars,
    required this.onTap,
  });

  final Lesson lesson;
  final LessonState state;
  final int stars;
  final VoidCallback onTap;

  String _typeLabel(BuildContext context) => switch (lesson.type) {
    LessonType.vocab => context.l10n.pathLessonWords,
    LessonType.grammar => context.l10n.pathLessonGrammar,
    LessonType.checkpoint => context.l10n.pathLessonCheckpoint,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final locked = state == LessonState.locked;
    final (Color bg, Widget icon) = switch (state) {
      LessonState.done => (
        context.appColors.successContainer,
        Icon(Icons.check_rounded, color: context.appColors.success),
      ),
      LessonState.current => (
        scheme.primary,
        Icon(Icons.play_arrow_rounded, color: scheme.onPrimary),
      ),
      LessonState.open => (
        scheme.primaryContainer,
        Icon(Icons.play_arrow_rounded, color: scheme.onPrimaryContainer),
      ),
      LessonState.locked => (
        scheme.surfaceContainerHighest,
        Icon(Icons.lock_rounded, color: scheme.outline, size: 20),
      ),
    };
    return Opacity(
      opacity: locked ? 0.65 : 1,
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: bg, child: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_typeLabel(context)} · ${lesson.title}',
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    lesson.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
            if (state == LessonState.done)
              StarRow(filled: stars, size: 18)
            else
              Text(
                context.l10n.commonMinutes(lesson.minutes),
                style: context.text.labelMedium?.copyWith(
                  color: scheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonSheet extends StatelessWidget {
  const _LessonSheet({
    required this.content,
    required this.lesson,
    required this.state,
    required this.stars,
  });

  final LanguageContent content;
  final Lesson lesson;
  final LessonState state;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locked = state == LessonState.locked;
    final words = [
      for (final id in lesson.wordIds)
        if (content.words[id] != null) content.words[id]!,
    ];
    final points = [
      for (final id in lesson.grammarIds)
        if (content.grammar[id] != null) content.grammar[id]!,
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(l.pathAbout(lesson.minutes), style: context.text.bodyMedium),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: switch (lesson.type) {
                  LessonType.vocab => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.pathNewWords, style: context.text.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in words)
                            Chip(
                              label: Text('${w.text}  ${w.romanization}'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                  LessonType.grammar => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.pathGrammarPoints, style: context.text.titleSmall),
                      const SizedBox(height: 8),
                      for (final p in points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '• ${p.title}',
                            style: context.text.bodyLarge,
                          ),
                        ),
                    ],
                  ),
                  LessonType.checkpoint => Text(
                    l.pathCheckpointBody,
                    style: context.text.bodyLarge,
                  ),
                },
              ),
            ),
            const SizedBox(height: 20),
            if (locked)
              Text(
                l.pathLocked,
                style: context.text.bodyMedium?.copyWith(
                  color: context.scheme.outline,
                ),
              )
            else
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/lesson/${lesson.id}');
                },
                child: Text(
                  state == LessonState.done ? l.pathRedo : l.pathStartLesson,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
