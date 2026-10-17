import 'dart:convert';

import 'progress_models.dart';

/// One language's progress inside a [ProgressBackup].
class LanguageBackup {
  const LanguageBackup({
    this.words = const {},
    this.lessons = const {},
    this.characters = const {},
  });

  final Map<int, WordProgress> words;
  final Map<String, LessonResult> lessons;
  final Map<String, int> characters;

  bool get isEmpty => words.isEmpty && lessons.isEmpty && characters.isEmpty;

  /// Combines two copies of the same language. The rules never lose work and
  /// give the same answer whichever side is "local":
  /// - a word keeps the copy studied most recently (more repetitions on a tie);
  /// - a lesson keeps the best stars, the latest day and the most attempts;
  /// - written characters keep the larger count.
  static LanguageBackup merge(LanguageBackup a, LanguageBackup b) {
    final words = {...a.words};
    for (final e in b.words.entries) {
      final mine = words[e.key];
      words[e.key] = mine == null ? e.value : _newerWord(mine, e.value);
    }
    final lessons = {...a.lessons};
    for (final e in b.lessons.entries) {
      final mine = lessons[e.key];
      lessons[e.key] = mine == null
          ? e.value
          : LessonResult(
              lessonId: e.key,
              stars: _max(mine.stars, e.value.stars),
              completedDay: _max(mine.completedDay, e.value.completedDay),
              attempts: _max(mine.attempts, e.value.attempts),
            );
    }
    final chars = {...a.characters};
    for (final e in b.characters.entries) {
      chars[e.key] = _max(chars[e.key] ?? 0, e.value);
    }
    return LanguageBackup(words: words, lessons: lessons, characters: chars);
  }

  static WordProgress _newerWord(WordProgress a, WordProgress b) {
    if (a.lastDay != b.lastDay) return a.lastDay > b.lastDay ? a : b;
    if (a.reps != b.reps) return a.reps > b.reps ? a : b;
    return a.box >= b.box ? a : b;
  }

  Map<String, Object?> toJson() {
    final ids = words.keys.toList()..sort();
    final lessonIds = lessons.keys.toList()..sort();
    final chars = characters.keys.toList()..sort();
    return {
      'w': [
        for (final id in ids)
          [
            id,
            words[id]!.box,
            words[id]!.dueDay,
            words[id]!.reps,
            words[id]!.lapses,
            words[id]!.lastDay,
          ],
      ],
      'l': [
        for (final id in lessonIds)
          [
            id,
            lessons[id]!.stars,
            lessons[id]!.completedDay,
            lessons[id]!.attempts,
          ],
      ],
      'c': {for (final c in chars) c: characters[c]},
    };
  }

  static LanguageBackup fromJson(Map<String, Object?> json) {
    final words = <int, WordProgress>{};
    for (final r in (json['w'] as List?) ?? const []) {
      final v = (r as List).cast<int>();
      words[v[0]] = WordProgress(
        wordId: v[0],
        box: v[1],
        dueDay: v[2],
        reps: v[3],
        lapses: v[4],
        lastDay: v[5],
      );
    }
    final lessons = <String, LessonResult>{};
    for (final r in (json['l'] as List?) ?? const []) {
      final v = r as List;
      lessons[v[0] as String] = LessonResult(
        lessonId: v[0] as String,
        stars: v[1] as int,
        completedDay: v[2] as int,
        attempts: v[3] as int,
      );
    }
    final chars = <String, int>{
      for (final e in ((json['c'] as Map?) ?? const {}).entries)
        e.key as String: e.value as int,
    };
    return LanguageBackup(words: words, lessons: lessons, characters: chars);
  }
}

/// Everything worth keeping safe: progress for each language plus the study
/// calendar. Pure data, so merging and encoding can be tested without a
/// database or a network.
class ProgressBackup {
  const ProgressBackup({
    this.languages = const {},
    this.days = const {},
    this.freezes = const {},
    this.levels = const {},
  });

  final Map<String, LanguageBackup> languages;
  final Map<int, DayLog> days;
  final Set<int> freezes;

  /// Level the learner chose for each language.
  final Map<String, int> levels;

  bool get isEmpty =>
      languages.values.every((l) => l.isEmpty) &&
      days.isEmpty &&
      freezes.isEmpty;

  /// See [LanguageBackup.merge]. Study days keep the larger value of each
  /// counter, freezes are united, and levels from `a` win over `b`.
  static ProgressBackup merge(ProgressBackup a, ProgressBackup b) {
    final langs = {...a.languages};
    for (final e in b.languages.entries) {
      final mine = langs[e.key];
      langs[e.key] = mine == null
          ? e.value
          : LanguageBackup.merge(mine, e.value);
    }
    final days = {...a.days};
    for (final e in b.days.entries) {
      final mine = days[e.key];
      days[e.key] = mine == null
          ? e.value
          : DayLog(
              day: e.key,
              seconds: _max(mine.seconds, e.value.seconds),
              lessons: _max(mine.lessons, e.value.lessons),
              reviews: _max(mine.reviews, e.value.reviews),
            );
    }
    // The first argument (this device) wins; the other fills gaps only.
    final levels = {...b.levels, ...a.levels};
    return ProgressBackup(
      languages: langs,
      days: days,
      freezes: {...a.freezes, ...b.freezes},
      levels: levels,
    );
  }

  /// The documents stored in the cloud: `shared` and one `lang_<id>` each,
  /// as JSON text so equal data always compares equal.
  Map<String, String> toDocuments() {
    final dayKeys = days.keys.toList()..sort();
    final freezeList = freezes.toList()..sort();
    final levelKeys = levels.keys.toList()..sort();
    final docs = <String, String>{
      'shared': jsonEncode({
        'd': [
          for (final k in dayKeys)
            [k, days[k]!.seconds, days[k]!.lessons, days[k]!.reviews],
        ],
        'f': freezeList,
        'v': {for (final k in levelKeys) k: levels[k]},
      }),
    };
    final langKeys = languages.keys.toList()..sort();
    for (final id in langKeys) {
      if (languages[id]!.isEmpty) continue;
      docs['lang_$id'] = jsonEncode(languages[id]!.toJson());
    }
    return docs;
  }

  static ProgressBackup fromDocuments(Map<String, String> docs) {
    final days = <int, DayLog>{};
    final freezes = <int>{};
    final levels = <String, int>{};
    final shared = docs['shared'];
    if (shared != null) {
      final j = jsonDecode(shared) as Map<String, Object?>;
      for (final r in (j['d'] as List?) ?? const []) {
        final v = (r as List).cast<int>();
        days[v[0]] = DayLog(
          day: v[0],
          seconds: v[1],
          lessons: v[2],
          reviews: v[3],
        );
      }
      freezes.addAll(((j['f'] as List?) ?? const []).cast<int>());
      for (final e in ((j['v'] as Map?) ?? const {}).entries) {
        levels[e.key as String] = e.value as int;
      }
    }
    final langs = <String, LanguageBackup>{};
    for (final e in docs.entries) {
      if (!e.key.startsWith('lang_')) continue;
      langs[e.key.substring(5)] = LanguageBackup.fromJson(
        jsonDecode(e.value) as Map<String, Object?>,
      );
    }
    return ProgressBackup(
      languages: langs,
      days: days,
      freezes: freezes,
      levels: levels,
    );
  }
}

int _max(int a, int b) => a > b ? a : b;
