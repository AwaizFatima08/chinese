import 'progress_models.dart';

/// Days until the next review once a word reaches each Leitner box.
/// Index 0 is unused for scheduling (a shaky word comes back tomorrow).
const List<int> srsIntervalDays = [1, 1, 3, 7, 14, 30, 60];

const int maxBox = 6;

/// Applies one review result to a word's state.
///
/// A correct answer moves the word up one box; a wrong answer drops it two
/// boxes (never below 1 once learned) and counts a lapse. Either way the
/// next review date comes from the box it lands in, so a forgotten word is
/// seen again the next day.
WordProgress applyReview(
  WordProgress? previous, {
  required int wordId,
  required bool correct,
  required int today,
}) {
  final box = previous?.box ?? 0;
  final int newBox;
  if (correct) {
    newBox = (box + 1).clamp(1, maxBox);
  } else {
    newBox = box <= 1 ? 0 : (box - 2).clamp(1, maxBox);
  }
  return WordProgress(
    wordId: wordId,
    box: newBox,
    dueDay: today + srsIntervalDays[newBox],
    reps: (previous?.reps ?? 0) + 1,
    lapses: (previous?.lapses ?? 0) + (correct ? 0 : 1),
    lastDay: today,
  );
}

/// State for a word met for the first time in a lesson.
WordProgress applyFirstLearning(
  WordProgress? previous, {
  required int wordId,
  required WordOutcome outcome,
  required int today,
}) {
  final clean = outcome == WordOutcome.clean;
  final base = previous?.box ?? 0;
  final box = clean ? (base < 1 ? 1 : base) : base;
  return WordProgress(
    wordId: wordId,
    box: box,
    dueDay: today + 1,
    reps: (previous?.reps ?? 0) + 1,
    lapses: (previous?.lapses ?? 0) + (clean ? 0 : 1),
    lastDay: today,
  );
}
