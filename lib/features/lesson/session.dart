import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/progress_models.dart';
import '../../languages/models.dart';
import '../progress/progress_state.dart';
import 'exercise.dart';
import 'exercise_builder.dart';
import 'session_result.dart';

export 'session_result.dart';

/// Which session to run. Value equality keeps the provider stable.
@immutable
class SessionRequest {
  const SessionRequest.lesson(String this.lessonId, {required this.seed})
    : review = false;
  const SessionRequest.review({required this.seed})
    : lessonId = null,
      review = true;

  final String? lessonId;
  final bool review;
  final int seed;

  @override
  bool operator ==(Object other) =>
      other is SessionRequest &&
      other.lessonId == lessonId &&
      other.review == review &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(lessonId, review, seed);
}

@immutable
class SessionState {
  const SessionState({
    required this.queue,
    required this.index,
    required this.scored,
    required this.wrong,
    required this.wrongByWord,
    required this.seenWords,
    required this.written,
    required this.seconds,
    required this.retried,
  });

  final List<Exercise> queue;
  final int index;
  final int scored;
  final int wrong;
  final Map<int, int> wrongByWord;
  final Set<int> seenWords;
  final Set<String> written;
  final int seconds;
  final Set<Exercise> retried;

  bool get finished => index >= queue.length;
  Exercise? get current => finished ? null : queue[index];
  double get progress => queue.isEmpty ? 1 : index / queue.length;

  SessionState copyWith({
    List<Exercise>? queue,
    int? index,
    int? scored,
    int? wrong,
    Map<int, int>? wrongByWord,
    Set<int>? seenWords,
    Set<String>? written,
    int? seconds,
    Set<Exercise>? retried,
  }) => SessionState(
    queue: queue ?? this.queue,
    index: index ?? this.index,
    scored: scored ?? this.scored,
    wrong: wrong ?? this.wrong,
    wrongByWord: wrongByWord ?? this.wrongByWord,
    seenWords: seenWords ?? this.seenWords,
    written: written ?? this.written,
    seconds: seconds ?? this.seconds,
    retried: retried ?? this.retried,
  );
}

/// Longest time one step may add to the study clock; a phone left on the
/// table should not count as study.
const _maxStepSeconds = 75;

class SessionNotifier extends Notifier<SessionState> {
  SessionNotifier(this.request);

  final SessionRequest request;
  late DateTime _stepStart;

  Lesson? get lesson {
    final id = request.lessonId;
    if (id == null) return null;
    return ref.read(contentProvider).requireValue.lessonById(id);
  }

  @override
  SessionState build() {
    final content = ref.read(contentProvider).requireValue;
    final tools = ref.read(languageToolsProvider)!;
    final progress = ref.read(progressProvider).value;
    final builder = ExerciseBuilder(content, tools);
    final List<Exercise> exercises;
    if (request.review) {
      final due = progress?.dueWordIds(limit: 12) ?? const <int>[];
      exercises = builder.forReview(due, seed: request.seed);
    } else {
      exercises = builder.forLesson(
        content.lessonById(request.lessonId!)!,
        seed: request.seed,
        progress: progress?.words ?? const {},
      );
    }
    _stepStart = ref.read(clockProvider).now();
    return SessionState(
      queue: exercises,
      index: 0,
      scored: 0,
      wrong: 0,
      wrongByWord: const {},
      seenWords: const {},
      written: const {},
      seconds: 0,
      retried: const {},
    );
  }

  int _tick() {
    final now = ref.read(clockProvider).now();
    final spent = now
        .difference(_stepStart)
        .inSeconds
        .clamp(0, _maxStepSeconds);
    _stepStart = now;
    return spent;
  }

  /// Records the answer to the current exercise. Wrong scored answers come
  /// back once at the end of the session.
  void answered({required bool correct}) {
    final ex = state.current;
    if (ex == null) return;
    var s = state;
    if (ex is WriteExercise && correct) {
      s = s.copyWith(written: {...s.written, ex.char});
    }
    if (ex is IntroExercise) return;
    final scores = _scores(ex);
    if (!scores) {
      state = s;
      return;
    }
    final isRetry = state.retried.contains(ex);
    if (!isRetry) {
      s = s.copyWith(scored: s.scored + 1, wrong: s.wrong + (correct ? 0 : 1));
    }
    if (!correct) {
      final byWord = {...s.wrongByWord};
      for (final id in ex.wordIds) {
        byWord[id] = (byWord[id] ?? 0) + 1;
      }
      s = s.copyWith(wrongByWord: byWord);
      if (!isRetry) {
        s = s.copyWith(queue: [...s.queue, ex], retried: {...s.retried, ex});
      }
    }
    state = s;
  }

  bool _scores(Exercise ex) => switch (ex) {
    ChoiceExercise() ||
    TypeExercise() ||
    SentenceChoiceExercise() ||
    OrderExercise() ||
    GrammarChoiceExercise() => true,
    _ => false,
  };

  /// Moves to the next exercise.
  void next() {
    final ex = state.current;
    final seen = {...state.seenWords};
    if (ex is IntroExercise) seen.add(ex.word.id);
    state = state.copyWith(
      index: state.index + 1,
      seenWords: seen,
      seconds: state.seconds + _tick(),
    );
  }

  /// Adds the time spent on the current step without moving on.
  void tickTime() => state = state.copyWith(seconds: state.seconds + _tick());

  /// Builds what to save. [completed] is false when the learner left early.
  SessionResult result({required bool completed}) {
    final s = state;
    final accuracy = s.scored == 0 ? 1.0 : 1 - s.wrong / s.scored;
    final stars = !completed
        ? 0
        : accuracy >= 0.9
        ? 3
        : accuracy >= 0.7
        ? 2
        : 1;
    final l = lesson;
    final outcomes = <int, WordOutcome>{};
    final reviews = <int, bool>{};
    if (request.review) {
      for (final ex in s.queue) {
        for (final id in ex.wordIds) {
          reviews[id] = (s.wrongByWord[id] ?? 0) == 0;
        }
      }
    } else if (l != null && l.type == LessonType.vocab) {
      for (final id in l.wordIds) {
        if (s.seenWords.contains(id)) {
          outcomes[id] = (s.wrongByWord[id] ?? 0) == 0
              ? WordOutcome.clean
              : WordOutcome.shaky;
        }
      }
    } else if (l != null && l.type == LessonType.checkpoint && completed) {
      for (final ex in s.queue) {
        for (final id in ex.wordIds) {
          if (l.wordIds.contains(id)) {
            reviews[id] = (s.wrongByWord[id] ?? 0) == 0;
          }
        }
      }
    }
    return SessionResult(
      lessonId: request.lessonId,
      lessonType: l?.type,
      completed: completed,
      stars: stars,
      accuracy: accuracy.clamp(0, 1),
      outcomes: outcomes,
      correctByWord: reviews,
      charactersWritten: s.written,
      seconds: s.seconds + _tick(),
    );
  }
}

final sessionProvider = NotifierProvider.autoDispose
    .family<SessionNotifier, SessionState, SessionRequest>(SessionNotifier.new);
