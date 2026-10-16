import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'progress_models.dart';
import 'srs.dart';

/// The single write path for everything the learner has done. Every
/// mutation is stored before callers refresh their state.
abstract interface class ProgressRepository {
  Future<Map<int, WordProgress>> wordProgress(String lang);
  Future<void> recordLearning(
    String lang,
    int today,
    Map<int, WordOutcome> outcomes,
  );
  Future<void> recordReviews(
    String lang,
    int today,
    Map<int, bool> correctByWord,
  );
  Future<Map<String, LessonResult>> lessonResults(String lang);
  Future<void> completeLesson(
    String lang,
    String lessonId,
    int stars,
    int today,
  );
  Future<void> addStudy(
    int day, {
    required int seconds,
    int lessons = 0,
    int reviews = 0,
  });
  Future<DayLog> dayLog(int day);
  Future<List<DayLog>> logsBetween(int from, int to);
  Future<int> totalSeconds();
  Future<Set<int>> practiceDays();
  Future<Set<int>> freezeDays();
  Future<void> addFreeze(int day);
  Future<void> recordCharacterWritten(String lang, String ch, int today);
  Future<Map<String, int>> charactersWritten(String lang);
  Future<void> resetLanguage(String lang);
  Future<void> resetEverything();
}

/// [ProgressRepository] stored in the on-device SQLite database.
class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository(this._appDb);

  final AppDatabase _appDb;
  Database get _db => _appDb.db;

  // ---- words ----

  @override
  Future<Map<int, WordProgress>> wordProgress(String lang) async {
    final rows = await _db.query(
      'word_progress',
      where: 'lang = ?',
      whereArgs: [lang],
    );
    return {
      for (final r in rows)
        r['word_id']! as int: WordProgress(
          wordId: r['word_id']! as int,
          box: r['box']! as int,
          dueDay: r['due_day']! as int,
          reps: r['reps']! as int,
          lapses: r['lapses']! as int,
          lastDay: r['last_day']! as int,
        ),
    };
  }

  Future<void> _put(Batch b, String lang, WordProgress w) {
    b.insert('word_progress', {
      'lang': lang,
      'word_id': w.wordId,
      'box': w.box,
      'due_day': w.dueDay,
      'reps': w.reps,
      'lapses': w.lapses,
      'last_day': w.lastDay,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return Future.value();
  }

  /// Records words met for the first time in a lesson.
  @override
  Future<void> recordLearning(
    String lang,
    int today,
    Map<int, WordOutcome> outcomes,
  ) async {
    final existing = await wordProgress(lang);
    final batch = _db.batch();
    for (final e in outcomes.entries) {
      await _put(
        batch,
        lang,
        applyFirstLearning(
          existing[e.key],
          wordId: e.key,
          outcome: e.value,
          today: today,
        ),
      );
    }
    await batch.commit(noResult: true);
  }

  /// Records the result of reviewing words that were already learned.
  @override
  Future<void> recordReviews(
    String lang,
    int today,
    Map<int, bool> correctByWord,
  ) async {
    final existing = await wordProgress(lang);
    final batch = _db.batch();
    for (final e in correctByWord.entries) {
      await _put(
        batch,
        lang,
        applyReview(
          existing[e.key],
          wordId: e.key,
          correct: e.value,
          today: today,
        ),
      );
    }
    await batch.commit(noResult: true);
  }

  // ---- lessons ----

  @override
  Future<Map<String, LessonResult>> lessonResults(String lang) async {
    final rows = await _db.query(
      'lesson_progress',
      where: 'lang = ?',
      whereArgs: [lang],
    );
    return {
      for (final r in rows)
        r['lesson_id']! as String: LessonResult(
          lessonId: r['lesson_id']! as String,
          stars: r['stars']! as int,
          completedDay: r['completed_day']! as int,
          attempts: r['attempts']! as int,
        ),
    };
  }

  /// Saves a finished lesson, keeping the best star count.
  @override
  Future<void> completeLesson(
    String lang,
    String lessonId,
    int stars,
    int today,
  ) async {
    final prev = await _db.query(
      'lesson_progress',
      where: 'lang = ? AND lesson_id = ?',
      whereArgs: [lang, lessonId],
    );
    final bestStars = prev.isEmpty
        ? stars
        : (prev.first['stars']! as int) > stars
        ? prev.first['stars']! as int
        : stars;
    final attempts = prev.isEmpty ? 1 : (prev.first['attempts']! as int) + 1;
    await _db.insert('lesson_progress', {
      'lang': lang,
      'lesson_id': lessonId,
      'stars': bestStars,
      'completed_day': today,
      'attempts': attempts,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- time and streak ----

  /// Adds study time to [day]'s log.
  @override
  Future<void> addStudy(
    int day, {
    required int seconds,
    int lessons = 0,
    int reviews = 0,
  }) async {
    await _db.rawInsert(
      '''
      INSERT INTO day_log (day, seconds, lessons, reviews) VALUES (?, ?, ?, ?)
      ON CONFLICT(day) DO UPDATE SET
        seconds = seconds + excluded.seconds,
        lessons = lessons + excluded.lessons,
        reviews = reviews + excluded.reviews
      ''',
      [day, seconds, lessons, reviews],
    );
  }

  @override
  Future<DayLog> dayLog(int day) async {
    final rows = await _db.query('day_log', where: 'day = ?', whereArgs: [day]);
    if (rows.isEmpty) {
      return DayLog(day: day, seconds: 0, lessons: 0, reviews: 0);
    }
    return _toLog(rows.first);
  }

  @override
  Future<List<DayLog>> logsBetween(int from, int to) async {
    final rows = await _db.query(
      'day_log',
      where: 'day BETWEEN ? AND ?',
      whereArgs: [from, to],
      orderBy: 'day',
    );
    return rows.map(_toLog).toList();
  }

  DayLog _toLog(Map<String, Object?> r) => DayLog(
    day: r['day']! as int,
    seconds: r['seconds']! as int,
    lessons: r['lessons']! as int,
    reviews: r['reviews']! as int,
  );

  @override
  Future<int> totalSeconds() async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(seconds), 0) AS s FROM day_log',
    );
    return r.first['s']! as int;
  }

  @override
  Future<Set<int>> practiceDays() async {
    final rows = await _db.query(
      'day_log',
      columns: ['day'],
      where: 'seconds > 0',
    );
    return {for (final r in rows) r['day']! as int};
  }

  @override
  Future<Set<int>> freezeDays() async {
    final rows = await _db.query('streak_freeze');
    return {for (final r in rows) r['day']! as int};
  }

  @override
  Future<void> addFreeze(int day) => _db.insert('streak_freeze', {
    'day': day,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  // ---- writing ----

  @override
  Future<void> recordCharacterWritten(String lang, String ch, int today) async {
    await _db.rawInsert(
      '''
      INSERT INTO char_progress (lang, ch, writes, last_day) VALUES (?, ?, 1, ?)
      ON CONFLICT(lang, ch) DO UPDATE SET writes = writes + 1, last_day = excluded.last_day
      ''',
      [lang, ch, today],
    );
  }

  @override
  Future<Map<String, int>> charactersWritten(String lang) async {
    final rows = await _db.query(
      'char_progress',
      where: 'lang = ?',
      whereArgs: [lang],
    );
    return {for (final r in rows) r['ch']! as String: r['writes']! as int};
  }

  // ---- reset ----

  @override
  Future<void> resetLanguage(String lang) async {
    await _db.delete('word_progress', where: 'lang = ?', whereArgs: [lang]);
    await _db.delete('lesson_progress', where: 'lang = ?', whereArgs: [lang]);
    await _db.delete('char_progress', where: 'lang = ?', whereArgs: [lang]);
  }

  @override
  Future<void> resetEverything() async {
    for (final t in [
      'word_progress',
      'lesson_progress',
      'day_log',
      'streak_freeze',
      'char_progress',
    ]) {
      await _db.delete(t);
    }
  }
}

/// Current streak: consecutive days up to [today] with study time or a
/// streak freeze. Today does not break a streak that ended yesterday.
int computeStreak({
  required int today,
  required Set<int> practiceDays,
  required Set<int> freezeDays,
}) {
  bool filled(int d) => practiceDays.contains(d) || freezeDays.contains(d);
  var day = filled(today) ? today : today - 1;
  var n = 0;
  while (filled(day)) {
    if (practiceDays.contains(day)) n++;
    day--;
  }
  return n;
}

/// The day a streak freeze could repair, or -1 when none applies.
///
/// A repair is offered only when yesterday was missed, today has no study
/// yet, and the day before yesterday was a study day (so a real streak is
/// being saved).
int missedDayToRepair({
  required int today,
  required Set<int> practiceDays,
  required Set<int> freezeDays,
}) {
  bool filled(int d) => practiceDays.contains(d) || freezeDays.contains(d);
  if (filled(today)) return -1;
  final missed = today - 1;
  if (filled(missed)) return -1;
  // Only offer a repair if the day before the gap was a study day, so the
  // streak being saved is real.
  return filled(missed - 1) ? missed : -1;
}

/// [ProgressRepository] held in memory; used by tests and previews.
class InMemoryProgressRepository implements ProgressRepository {
  final Map<String, Map<int, WordProgress>> _words = {};
  final Map<String, Map<String, LessonResult>> _lessons = {};
  final Map<int, DayLog> _days = {};
  final Set<int> _freezes = {};
  final Map<String, Map<String, int>> _chars = {};

  @override
  Future<Map<int, WordProgress>> wordProgress(String lang) async => {
    ...?_words[lang],
  };

  @override
  Future<void> recordLearning(
    String lang,
    int today,
    Map<int, WordOutcome> outcomes,
  ) async {
    final table = _words.putIfAbsent(lang, () => {});
    for (final e in outcomes.entries) {
      table[e.key] = applyFirstLearning(
        table[e.key],
        wordId: e.key,
        outcome: e.value,
        today: today,
      );
    }
  }

  @override
  Future<void> recordReviews(
    String lang,
    int today,
    Map<int, bool> correctByWord,
  ) async {
    final table = _words.putIfAbsent(lang, () => {});
    for (final e in correctByWord.entries) {
      table[e.key] = applyReview(
        table[e.key],
        wordId: e.key,
        correct: e.value,
        today: today,
      );
    }
  }

  @override
  Future<Map<String, LessonResult>> lessonResults(String lang) async => {
    ...?_lessons[lang],
  };

  @override
  Future<void> completeLesson(
    String lang,
    String lessonId,
    int stars,
    int today,
  ) async {
    final table = _lessons.putIfAbsent(lang, () => {});
    final prev = table[lessonId];
    table[lessonId] = LessonResult(
      lessonId: lessonId,
      stars: prev != null && prev.stars > stars ? prev.stars : stars,
      completedDay: today,
      attempts: (prev?.attempts ?? 0) + 1,
    );
  }

  @override
  Future<void> addStudy(
    int day, {
    required int seconds,
    int lessons = 0,
    int reviews = 0,
  }) async {
    final p = _days[day];
    _days[day] = DayLog(
      day: day,
      seconds: (p?.seconds ?? 0) + seconds,
      lessons: (p?.lessons ?? 0) + lessons,
      reviews: (p?.reviews ?? 0) + reviews,
    );
  }

  @override
  Future<DayLog> dayLog(int day) async =>
      _days[day] ?? DayLog(day: day, seconds: 0, lessons: 0, reviews: 0);

  @override
  Future<List<DayLog>> logsBetween(int from, int to) async => [
    for (final d in _days.values)
      if (d.day >= from && d.day <= to) d,
  ]..sort((a, b) => a.day.compareTo(b.day));

  @override
  Future<int> totalSeconds() async =>
      _days.values.fold<int>(0, (a, d) => a + d.seconds);

  @override
  Future<Set<int>> practiceDays() async => {
    for (final d in _days.values)
      if (d.seconds > 0) d.day,
  };

  @override
  Future<Set<int>> freezeDays() async => {..._freezes};

  @override
  Future<void> addFreeze(int day) async => _freezes.add(day);

  @override
  Future<void> recordCharacterWritten(String lang, String ch, int today) async {
    final t = _chars.putIfAbsent(lang, () => {});
    t[ch] = (t[ch] ?? 0) + 1;
  }

  @override
  Future<Map<String, int>> charactersWritten(String lang) async => {
    ...?_chars[lang],
  };

  @override
  Future<void> resetLanguage(String lang) async {
    _words.remove(lang);
    _lessons.remove(lang);
    _chars.remove(lang);
  }

  @override
  Future<void> resetEverything() async {
    _words.clear();
    _lessons.clear();
    _days.clear();
    _freezes.clear();
    _chars.clear();
  }
}
