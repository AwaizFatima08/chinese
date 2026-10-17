import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/services/speaker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../l10n/l10n.dart';
import '../progress/progress_state.dart';
import 'complete_view.dart';
import 'exercise.dart';
import 'feedback_bar.dart';
import 'session.dart';
import 'views/choice_view.dart';
import 'views/grammar_view.dart';
import 'views/intro_view.dart';
import 'views/order_view.dart';
import 'views/speak_view.dart';
import 'views/type_view.dart';
import 'views/write_view.dart';

/// Hard ceiling on a day's study, in seconds (15 minutes).
const dailyCapSeconds = 15 * 60;

/// Runs a lesson (or the spaced-repetition review when [lessonId] is null).
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, this.lessonId});

  final String? lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late final SessionRequest _request = widget.lessonId == null
      ? SessionRequest.review(
          seed: ref.read(clockProvider).now().millisecondsSinceEpoch,
        )
      : SessionRequest.lesson(
          widget.lessonId!,
          seed: ref.read(clockProvider).now().millisecondsSinceEpoch,
        );

  bool _answered = false;
  bool _correct = false;
  String? _reveal;
  bool _nudgeShown = false;

  // Kept in a field because `ref` cannot be used inside dispose().
  late final Speaker _speaker;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
  }

  @override
  void dispose() {
    unawaited(_speaker.stop());
    super.dispose();
  }

  void _onAnswered(bool correct, {String? reveal}) {
    if (_answered) return;
    ref.read(sessionProvider(_request).notifier).answered(correct: correct);
    setState(() {
      _answered = true;
      _correct = correct;
      _reveal = reveal;
    });
  }

  Future<void> _advance() async {
    unawaited(ref.read(speakerProvider).stop());
    ref.read(sessionProvider(_request).notifier).next();
    setState(() {
      _answered = false;
      _correct = false;
      _reveal = null;
    });
    await _maybeNudge();
  }

  /// At 15 minutes of study today, suggest stopping.
  Future<void> _maybeNudge() async {
    if (_nudgeShown) return;
    final s = ref.read(sessionProvider(_request));
    if (s.finished) return;
    final before = ref.read(progressProvider).value?.todayLog.seconds ?? 0;
    if (before + s.seconds < dailyCapSeconds) return;
    _nudgeShown = true;
    final l = context.l10n;
    final finish = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l.lessonNudgeTitle),
        content: Text(l.lessonNudgeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.lessonNudgeKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: Text(l.lessonNudgeFinish),
          ),
        ],
      ),
    );
    if (finish == true && mounted) await _leaveSaving();
  }

  /// Saves what was learned so far and closes the lesson.
  Future<void> _leaveSaving() async {
    final notifier = ref.read(sessionProvider(_request).notifier);
    final result = notifier.result(completed: false);
    if (result.seconds >= 5 || result.outcomes.isNotEmpty) {
      await ref.read(progressProvider.notifier).saveSession(result);
    }
    if (mounted) context.pop();
  }

  Future<void> _confirmLeave() async {
    final s = ref.read(sessionProvider(_request));
    if (s.index == 0 || s.finished) {
      if (mounted) context.pop();
      return;
    }
    final l = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.lessonLeaveTitle),
        content: Text(l.lessonLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.lessonStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.lessonLeave),
          ),
        ],
      ),
    );
    if (leave == true && mounted) await _leaveSaving();
  }

  String _phaseLabel(BuildContext context, Phase p) {
    final l = context.l10n;
    return switch (p) {
      Phase.meet => l.phaseMeet,
      Phase.recall => l.phaseRecall,
      Phase.speak => l.phaseSpeak,
      Phase.write => l.phaseWrite,
      Phase.sentences => l.phaseSentences,
      Phase.grammar => l.phaseGrammar,
      Phase.review => l.phaseReview,
    };
  }

  Widget _body(Exercise ex) => switch (ex) {
    IntroExercise() => IntroView(exercise: ex),
    ChoiceExercise() => ChoiceView(exercise: ex, onAnswered: _onAnswered),
    SpeakExercise() => SpeakView(exercise: ex, onAnswered: _onAnswered),
    WriteExercise() => WriteView(exercise: ex, onAnswered: _onAnswered),
    TypeExercise() => TypeView(exercise: ex, onAnswered: _onAnswered),
    SentenceChoiceExercise() => SentenceChoiceView(
      exercise: ex,
      onAnswered: _onAnswered,
    ),
    OrderExercise() => OrderView(exercise: ex, onAnswered: _onAnswered),
    ShadowExercise() => ShadowView(exercise: ex, onAnswered: _onAnswered),
    GrammarExplainExercise() => GrammarExplainView(exercise: ex),
    GrammarChoiceExercise() => GrammarChoiceView(
      exercise: ex,
      onAnswered: _onAnswered,
    ),
  };

  bool _canSkip(Exercise ex) =>
      ex is SpeakExercise || ex is ShadowExercise || ex is WriteExercise;

  bool _isScored(Exercise ex) =>
      ex is ChoiceExercise ||
      ex is TypeExercise ||
      ex is SentenceChoiceExercise ||
      ex is OrderExercise ||
      ex is GrammarChoiceExercise;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final contentAsync = ref.watch(contentProvider);
    final progressAsync = ref.watch(progressProvider);
    if (contentAsync.hasError || progressAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: MessageView(
          message: l.commonError,
          icon: Icons.error_outline_rounded,
          actionLabel: l.commonRetry,
          onAction: () {
            ref
              ..invalidate(contentProvider)
              ..invalidate(progressProvider);
          },
        ),
      );
    }
    if (contentAsync.value == null || progressAsync.value == null) {
      return Scaffold(
        body: MessageView(message: l.commonLoading, loading: true),
      );
    }

    final session = ref.watch(sessionProvider(_request));
    final scheme = context.scheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        body: SafeArea(
          child: session.finished
              ? CompleteView(request: _request)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _confirmLeave,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: l.commonClose,
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: session.progress,
                                minHeight: 10,
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _phaseLabel(context, session.current!.phase),
                        style: context.text.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          // Position only: re-queuing a missed exercise must not
                          // rebuild the screen under the feedback panel.
                          key: ValueKey(session.index),
                          child: _body(session.current!),
                        ),
                      ),
                    ),
                    _footer(session.current!),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _footer(Exercise ex) {
    final l = context.l10n;
    if (!ex.needsAnswer) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: _advance,
          child: Text(
            ex is GrammarExplainExercise ? l.exGrammarGotIt : l.commonContinue,
          ),
        ),
      );
    }
    if (_answered) {
      return FeedbackBar(
        correct: _correct,
        scored: _isScored(ex),
        reveal: _reveal,
        onContinue: _advance,
      );
    }
    if (_canSkip(ex)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextButton(onPressed: _advance, child: Text(l.commonSkip)),
      );
    }
    return const SizedBox(height: 16);
  }
}
