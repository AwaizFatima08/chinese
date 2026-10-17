import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/misc_widgets.dart';
import '../../data/progress_models.dart';
import '../../l10n/l10n.dart';
import '../ads/ad_gate.dart';
import '../lesson/feedback_bar.dart';
import '../lesson/session_result.dart';
import '../progress/progress_state.dart';
import 'speak_providers.dart';
import 'speak_steps.dart';
import 'step_views.dart';
import 'melody_view.dart';
import 'talk_view.dart';

/// Runs one practice set: a short series of listening, speaking and
/// vocabulary steps, then saves stars, study time and word progress.
class SpeakSessionScreen extends ConsumerStatefulWidget {
  const SpeakSessionScreen({super.key, required this.setId});

  /// A set id from [SpeakContent.groups], or `review`.
  final String setId;

  @override
  ConsumerState<SpeakSessionScreen> createState() => _SpeakSessionScreenState();
}

class _SpeakSessionScreenState extends ConsumerState<SpeakSessionScreen>
    with SingleTickerProviderStateMixin {
  List<SpeakStep>? _steps;
  Map<int, WordProgress> _known = const {};
  int _index = 0;
  bool _answered = false;
  bool _correct = false;
  String? _reveal;
  bool _finished = false;
  SessionResult? _result;
  final _scores = <double>[];
  final _vocabOk = <int, bool>{};
  final _clock = Stopwatch()..start();
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  // Kept in a field because `ref` cannot be used inside dispose().
  late final _speaker = ref.read(speakerProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final content = await ref.read(speakContentProvider.future);
    final progress = await ref.read(speakProgressProvider.future);
    final seed = ref.read(clockProvider).now().millisecondsSinceEpoch;
    final builder = SpeakStepBuilder(content, seed: seed);
    final steps = widget.setId == 'review'
        ? builder.forReview(
            progress.dueWordIds(dayNumber(ref.read(clockProvider).now())),
          )
        : builder.forSet(widget.setId);
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _known = progress.words;
    });
  }

  @override
  void dispose() {
    unawaited(_speaker.stop());
    _pop.dispose();
    super.dispose();
  }

  SpeakStep? get _current {
    final s = _steps;
    return s != null && _index < s.length ? s[_index] : null;
  }

  double get _progress {
    final s = _steps;
    if (s == null || s.isEmpty) return 0;
    return (_index / s.length).clamp(0, 1);
  }

  void _onAnswered(bool correct, double score, {String? reveal, int? vocabId}) {
    if (_answered) return;
    _scores.add(score);
    if (vocabId != null) {
      _vocabOk[vocabId] = (_vocabOk[vocabId] ?? true) && correct;
    }
    setState(() {
      _answered = true;
      _correct = correct;
      _reveal = reveal;
    });
  }

  Future<void> _advance() async {
    unawaited(_speaker.stop());
    final steps = _steps!;
    if (_index + 1 >= steps.length) {
      await _complete();
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _correct = false;
      _reveal = null;
    });
  }

  SessionResult _buildResult({required bool completed}) {
    final outcomes = <int, WordOutcome>{};
    final reviews = <int, bool>{};
    for (final e in _vocabOk.entries) {
      final known = _known[e.key];
      if (known != null && known.isLearned) {
        reviews[e.key] = e.value;
      } else {
        outcomes[e.key] = e.value ? WordOutcome.clean : WordOutcome.shaky;
      }
    }
    final accuracy = _scores.isEmpty
        ? 0.0
        : _scores.reduce((a, b) => a + b) / _scores.length;
    final stars = !completed
        ? 0
        : accuracy >= 0.85
        ? 3
        : accuracy >= 0.65
        ? 2
        : 1;
    return SessionResult(
      lessonId: widget.setId == 'review' ? null : widget.setId,
      lessonType: null,
      completed: completed,
      stars: stars,
      accuracy: accuracy,
      outcomes: outcomes,
      correctByWord: reviews,
      charactersWritten: const {},
      seconds: _clock.elapsed.inSeconds,
      language: speakLanguage,
    );
  }

  Future<void> _complete() async {
    final result = _buildResult(completed: true);
    await ref.read(progressProvider.notifier).saveSession(result);
    ref.invalidate(speakProgressProvider);
    if (result.lessonId != null) {
      await ref.read(adGateProvider).recordLessonDone();
    }
    if (!mounted) return;
    setState(() {
      _finished = true;
      _result = result;
    });
    unawaited(_pop.forward());
  }

  Future<void> _leaveSaving() async {
    final result = _buildResult(completed: false);
    if (result.seconds >= 5 || result.outcomes.isNotEmpty) {
      await ref.read(progressProvider.notifier).saveSession(result);
      ref.invalidate(speakProgressProvider);
    }
    if (mounted) context.pop();
  }

  Future<void> _confirmLeave() async {
    if (_finished || _index == 0 && !_answered) {
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

  Future<void> _backToSpeak() async {
    final progress = ref.read(progressProvider).value;
    await ref
        .read(adGateProvider)
        .maybeShow(lessonsCompletedToday: progress?.todayLog.lessons ?? 0);
    if (mounted) context.pop();
  }

  String _phaseLabel(BuildContext context, SpeakPhase p) {
    final l = context.l10n;
    return switch (p) {
      SpeakPhase.learn => l.speakPhaseLearn,
      SpeakPhase.listen => l.speakPhaseListen,
      SpeakPhase.say => l.speakPhaseSay,
      SpeakPhase.stress => l.speakPhaseStress,
      SpeakPhase.recall => l.speakPhaseRecall,
      SpeakPhase.shadow => l.speakPhaseShadow,
      SpeakPhase.melody => l.speakPhaseMelody,
      SpeakPhase.talk => l.speakPhaseTalk,
    };
  }

  Widget _body(SpeakStep step) => switch (step) {
    TipStep() => TipView(step: step),
    ListenPickStep() => ListenPickView(step: step, onAnswered: _onAnswered),
    SayWordStep() => SayWordView(step: step, onAnswered: _onAnswered),
    SayTextStep() => SayTextView(step: step, onAnswered: _onAnswered),
    StressPickStep() => StressPickView(step: step, onAnswered: _onAnswered),
    VocabIntroStep() => VocabIntroView(step: step),
    VocabRecallStep() => VocabRecallView(step: step, onAnswered: _onAnswered),
    MelodyStep() => MelodyView(step: step, onAnswered: _onAnswered),
    TalkTurnStep() => TalkTurnView(step: step, onAnswered: _onAnswered),
  };

  bool _isScoredChoice(SpeakStep s) =>
      s is ListenPickStep || s is StressPickStep || s is VocabRecallStep;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final steps = _steps;
    if (steps == null) {
      return Scaffold(
        body: MessageView(message: l.commonLoading, loading: true),
      );
    }
    if (steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: MessageView(
          message: l.commonError,
          icon: Icons.error_outline_rounded,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        body: SafeArea(
          child: _finished
              ? _completeView(context)
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
                                value: _progress,
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
                        _phaseLabel(context, _current!.phase),
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
                          key: ValueKey(_index),
                          child: _body(_current!),
                        ),
                      ),
                    ),
                    _footer(_current!),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _footer(SpeakStep step) {
    final l = context.l10n;
    if (!step.needsAnswer) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: _advance,
          child: Text(step is TipStep ? l.speakStart : l.commonContinue),
        ),
      );
    }
    if (_answered) {
      return FeedbackBar(
        correct: _correct,
        scored: _isScoredChoice(step),
        reveal: _reveal,
        onContinue: _advance,
      );
    }
    return const SizedBox(height: 16);
  }

  Widget _completeView(BuildContext context) {
    final l = context.l10n;
    final result = _result!;
    final pct = (result.accuracy * 100).round();
    final minutes = (result.seconds / 60).ceil();
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
            l.speakDoneTitle,
            style: context.text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (result.lessonId != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 3; i++)
                  Icon(
                    i <= result.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 44,
                    color: context.appColors.gold,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            l.speakDoneAccuracy(pct),
            style: context.text.titleLarge?.copyWith(
              color: context.scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.commonMinutes(minutes < 1 ? 1 : minutes),
            style: context.text.bodyMedium,
          ),
          const Spacer(),
          FilledButton(onPressed: _backToSpeak, child: Text(l.speakBack)),
        ],
      ),
    );
  }
}
