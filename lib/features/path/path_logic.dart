import '../../languages/models.dart';
import '../progress/progress_state.dart';

/// Where a lesson stands on the learning path.
enum LessonState { done, current, open, locked }

/// Pure rules for the learning path: which lessons are open and what comes
/// next. Lessons unlock in order within a level; every level can be started
/// at its first lesson, so a learner who already knows HSK 1 can jump ahead.
class PathLogic {
  const PathLogic(this.progress, {this.unlockAll = false});

  final ProgressSnapshot progress;
  final bool unlockAll;

  /// State of every lesson of [level], in order.
  Map<String, LessonState> statesFor(Level level) {
    final out = <String, LessonState>{};
    var previousDone = true;
    var currentAssigned = false;
    for (final lesson in level.lessons) {
      final done = progress.isLessonDone(lesson.id);
      if (done) {
        out[lesson.id] = LessonState.done;
      } else if (previousDone || unlockAll) {
        if (!currentAssigned) {
          out[lesson.id] = LessonState.current;
          currentAssigned = true;
        } else {
          out[lesson.id] = LessonState.open;
        }
      } else {
        out[lesson.id] = LessonState.locked;
      }
      previousDone = done;
    }
    return out;
  }

  /// The lesson to do next in [level], or null when the level is finished.
  Lesson? nextLesson(Level level) {
    for (final lesson in level.lessons) {
      if (!progress.isLessonDone(lesson.id)) return lesson;
    }
    return null;
  }

  int completedIn(Level level) =>
      level.lessons.where((l) => progress.isLessonDone(l.id)).length;

  double fractionDone(Level level) {
    final total = level.lessons.length;
    return total == 0 ? 0 : completedIn(level) / total;
  }
}
