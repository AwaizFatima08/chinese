import 'package:flutter/foundation.dart';

/// Days since 1970-01-01 in the learner's local calendar. Used for every
/// "which day" decision so streaks and due dates ignore time of day.
int dayNumber(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
).difference(DateTime.utc(1970)).inDays;

/// Spaced-repetition state of one word.
@immutable
class WordProgress {
  const WordProgress({
    required this.wordId,
    required this.box,
    required this.dueDay,
    required this.reps,
    required this.lapses,
    required this.lastDay,
  });

  final int wordId;

  /// Leitner box: 0 shaky, 1-6 increasingly stable.
  final int box;
  final int dueDay;
  final int reps;
  final int lapses;
  final int lastDay;

  bool get isLearned => box >= 1;
  bool get isMastered => box >= 4;
}

@immutable
class LessonResult {
  const LessonResult({
    required this.lessonId,
    required this.stars,
    required this.completedDay,
    required this.attempts,
  });

  final String lessonId;
  final int stars;
  final int completedDay;
  final int attempts;
}

@immutable
class DayLog {
  const DayLog({
    required this.day,
    required this.seconds,
    required this.lessons,
    required this.reviews,
  });

  final int day;
  final int seconds;
  final int lessons;
  final int reviews;

  int get minutes => (seconds / 60).round();
}

/// How one word fared in a lesson or review session.
enum WordOutcome {
  /// Answered without mistakes.
  clean,

  /// Needed retries or was answered wrongly at least once.
  shaky,
}
