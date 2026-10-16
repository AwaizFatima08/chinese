import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/progress_models.dart';
import '../../data/progress_repository.dart';
import '../lesson/session_result.dart';

/// Everything the UI needs to know about the learner's progress right now.
@immutable
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.today,
    required this.lessons,
    required this.words,
    required this.todayLog,
    required this.week,
    required this.streak,
    required this.totalSeconds,
    required this.repairDay,
    required this.charactersWritten,
  });

  final int today;
  final Map<String, LessonResult> lessons;
  final Map<int, WordProgress> words;
  final DayLog todayLog;

  /// The last seven days, oldest first, ending today.
  final List<DayLog> week;
  final int streak;
  final int totalSeconds;

  /// A missed day a rewarded ad could repair, or -1.
  final int repairDay;
  final Map<String, int> charactersWritten;

  int get learnedCount => words.values.where((w) => w.isLearned).length;
  int get masteredCount => words.values.where((w) => w.isMastered).length;

  /// Words due for review today, most overdue first. Shaky words (box 0)
  /// count too: they are the ones that most need another look.
  List<int> dueWordIds({int? limit}) {
    final due = words.values.where((w) => w.dueDay <= today).toList()
      ..sort((a, b) {
        final byDue = a.dueDay.compareTo(b.dueDay);
        return byDue != 0 ? byDue : a.box.compareTo(b.box);
      });
    final ids = due.map((w) => w.wordId);
    return (limit == null ? ids : ids.take(limit)).toList();
  }

  int get dueCount => words.values.where((w) => w.dueDay <= today).length;

  bool isLessonDone(String id) => lessons.containsKey(id);
}

class ProgressNotifier extends AsyncNotifier<ProgressSnapshot> {
  ProgressRepository get _repo => ref.read(progressRepositoryProvider);
  String get _lang => ref.read(settingsProvider).languageId;

  @override
  Future<ProgressSnapshot> build() {
    ref.watch(settingsProvider.select((s) => s.languageId));
    return _load();
  }

  Future<ProgressSnapshot> _load() async {
    final today = ref.today;
    final lang = _lang;
    final practice = await _repo.practiceDays();
    final freezes = await _repo.freezeDays();
    final logs = await _repo.logsBetween(today - 6, today);
    final byDay = {for (final l in logs) l.day: l};
    return ProgressSnapshot(
      today: today,
      lessons: await _repo.lessonResults(lang),
      words: await _repo.wordProgress(lang),
      todayLog:
          byDay[today] ??
          DayLog(day: today, seconds: 0, lessons: 0, reviews: 0),
      week: [
        for (var d = today - 6; d <= today; d++)
          byDay[d] ?? DayLog(day: d, seconds: 0, lessons: 0, reviews: 0),
      ],
      streak: computeStreak(
        today: today,
        practiceDays: practice,
        freezeDays: freezes,
      ),
      totalSeconds: await _repo.totalSeconds(),
      repairDay: missedDayToRepair(
        today: today,
        practiceDays: practice,
        freezeDays: freezes,
      ),
      charactersWritten: await _repo.charactersWritten(lang),
    );
  }

  Future<void> _refresh() async {
    state = AsyncData(await _load());
  }

  /// Saves everything a lesson or review session produced.
  Future<void> saveSession(SessionResult r) async {
    final today = ref.today;
    if (r.outcomes.isNotEmpty) {
      await _repo.recordLearning(_lang, today, r.outcomes);
    }
    if (r.correctByWord.isNotEmpty) {
      await _repo.recordReviews(_lang, today, r.correctByWord);
    }
    for (final ch in r.charactersWritten) {
      await _repo.recordCharacterWritten(_lang, ch, today);
    }
    final lessonDone = r.completed && r.lessonId != null;
    if (lessonDone) {
      await _repo.completeLesson(_lang, r.lessonId!, r.stars, today);
    }
    await _repo.addStudy(
      today,
      seconds: r.seconds,
      lessons: lessonDone ? 1 : 0,
      reviews: r.completed && r.lessonId == null ? 1 : 0,
    );
    await _refresh();
  }

  /// Marks [day] as covered by a streak freeze (after a rewarded ad).
  Future<void> repairStreak(int day) async {
    await _repo.addFreeze(day);
    await _refresh();
  }

  Future<void> resetLanguage() async {
    await _repo.resetLanguage(_lang);
    await _refresh();
  }

  Future<void> resetEverything() async {
    await _repo.resetEverything();
    await _refresh();
  }
}

final progressProvider =
    AsyncNotifierProvider<ProgressNotifier, ProgressSnapshot>(
      ProgressNotifier.new,
    );
