import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../l10n/l10n.dart';
import '../../languages/models.dart';
import '../ads/ad_gate.dart';
import '../path/path_logic.dart';
import '../progress/progress_state.dart';
import 'session.dart';

/// Shown when every exercise is done: saves the result, celebrates, and
/// offers the next step.
class CompleteView extends ConsumerStatefulWidget {
  const CompleteView({super.key, required this.request});

  final SessionRequest request;

  @override
  ConsumerState<CompleteView> createState() => _CompleteViewState();
}

class _CompleteViewState extends ConsumerState<CompleteView>
    with SingleTickerProviderStateMixin {
  SessionResult? _result;
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_save()));
  }

  Future<void> _save() async {
    final result = ref
        .read(sessionProvider(widget.request).notifier)
        .result(completed: true);
    await ref.read(progressProvider.notifier).saveSession(result);
    if (result.lessonId != null) {
      await ref.read(adGateProvider).recordLessonDone();
    }
    if (!mounted) return;
    setState(() => _result = result);
    unawaited(_pop.forward());
  }

  Future<void> _leave({String? goToLesson}) async {
    final progress = ref.read(progressProvider).value;
    await ref
        .read(adGateProvider)
        .maybeShow(lessonsCompletedToday: progress?.todayLog.lessons ?? 0);
    if (!mounted) return;
    if (goToLesson != null) {
      context.pushReplacement('/lesson/$goToLesson');
    } else {
      context.pop();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final result = _result;
    if (result == null) {
      return MessageView(message: l.commonLoading, loading: true);
    }
    final content = ref.watch(contentProvider).requireValue;
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider).value;
    final isReview = result.lessonId == null;

    Lesson? next;
    if (!isReview && progress != null) {
      final level = content.levelOfLesson(result.lessonId!);
      if (level != null) {
        next = PathLogic(
          progress,
          unlockAll: settings.unlockAll,
        ).nextLesson(level);
      }
    }
    final todayMinutes = ((progress?.todayLog.seconds ?? 0) / 60).round();
    final goalReached = todayMinutes >= settings.dailyGoalMinutes;
    final minutes = (result.seconds / 60).round();
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          ScaleTransition(
            scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 96,
              color: context.appColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isReview ? l.reviewDoneTitle : l.lessonDoneTitle,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!isReview) ...[
            const SizedBox(height: 12),
            StarRow(filled: result.stars, size: 44),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Stat(
                Icons.menu_book_rounded,
                l.lessonDoneWords(result.wordsPracticed),
              ),
              _Stat(
                Icons.check_circle_outline_rounded,
                l.lessonDoneAccuracy((result.accuracy * 100).round()),
              ),
              _Stat(Icons.timer_outlined, l.lessonDoneTime(minutes)),
            ],
          ),
          if (goalReached) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appColors.successContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, color: context.appColors.success),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l.homeGoalDone,
                      style: context.text.titleSmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (next != null && !goalReached) ...[
            FilledButton(
              onPressed: () => _leave(goToLesson: next!.id),
              child: Text(l.lessonDoneNext),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _leave, child: Text(l.lessonDoneHome)),
          ] else ...[
            FilledButton(onPressed: _leave, child: Text(l.lessonDoneHome)),
            if (next != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _leave(goToLesson: next!.id),
                child: Text(l.lessonDoneNext),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: context.scheme.primary),
        const SizedBox(width: 6),
        Text(text, style: context.text.titleSmall),
      ],
    );
  }
}
