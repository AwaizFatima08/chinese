import 'package:flutter/foundation.dart';

import '../../data/progress_models.dart';
import '../../languages/models.dart';

/// What a finished (or abandoned) session produced, ready to be saved.
@immutable
class SessionResult {
  const SessionResult({
    required this.lessonId,
    required this.lessonType,
    required this.completed,
    required this.stars,
    required this.accuracy,
    required this.outcomes,
    required this.correctByWord,
    required this.charactersWritten,
    required this.seconds,
    this.language,
  });

  final String? lessonId;
  final LessonType? lessonType;
  final bool completed;
  final int stars;

  /// Share of scored questions answered right the first time, 0..1.
  final double accuracy;

  /// Newly met words and how they went (vocabulary lessons).
  final Map<int, WordOutcome> outcomes;

  /// Already-known words and whether they were recalled (reviews, checkpoints).
  final Map<int, bool> correctByWord;
  final Set<String> charactersWritten;
  final int seconds;

  /// The language this result belongs to; the current learning language when
  /// null. Spoken-English practice sets it to `en`.
  final String? language;

  int get wordsPracticed => outcomes.length + correctByWord.length;
}
