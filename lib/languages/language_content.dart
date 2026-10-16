import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'models.dart';

/// Loaded, in-memory content of one language pack.
class LanguageContent {
  LanguageContent._({
    required this.pack,
    required this.words,
    required this.sentences,
    required this.grammar,
    required this.levels,
    required AssetBundle bundle,
    required Map<String, int> strokeIndex,
  }) : _bundle = bundle,
       _strokeIndex = strokeIndex;

  final LanguagePack pack;
  final Map<int, Word> words;
  final Map<int, Sentence> sentences;
  final Map<String, GrammarPoint> grammar;
  final Map<String, Level> levels;

  final AssetBundle _bundle;
  final Map<String, int> _strokeIndex;
  final Map<int, Map<String, StrokeData>> _strokeCache = {};
  late final Map<String, Lesson> _lessonById = {
    for (final level in levels.values)
      for (final lesson in level.lessons) lesson.id: lesson,
  };
  late final Map<String, Level> _levelOfLesson = {
    for (final level in levels.values)
      for (final lesson in level.lessons) lesson.id: level,
  };
  late final Map<String, Word> _wordByText = {
    for (final w in words.values) w.text: w,
  };

  /// Words sorted by level then id, used for distractors and the word list.
  late final List<Word> allWords = words.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  Lesson? lessonById(String id) => _lessonById[id];
  Level? levelOfLesson(String lessonId) => _levelOfLesson[lessonId];
  Word? wordByText(String text) => _wordByText[text];
  Iterable<Word> wordsOfLevel(int level) =>
      allWords.where((w) => w.level == level);

  /// Whether stroke data exists for [char].
  bool hasStrokes(String char) => _strokeIndex.containsKey(char);

  /// Loads (and caches) the stroke data of [char], or null if unknown.
  Future<StrokeData?> strokesFor(String char) async {
    final level = _strokeIndex[char];
    if (level == null) return null;
    final table = _strokeCache[level] ??= await _loadStrokeTable(level);
    return table[char];
  }

  Future<Map<String, StrokeData>> _loadStrokeTable(int level) async {
    final raw = await _bundle.loadString(
      'assets/content/${pack.id}/strokes/hsk$level.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in json.entries)
        entry.key: _parseStrokes(entry.value as Map<String, dynamic>),
    };
  }

  static StrokeData _parseStrokes(Map<String, dynamic> j) {
    // Source data is y-up with the baseline at 900; flip to y-down.
    Offset flip(List<dynamic> p) =>
        Offset((p[0] as num).toDouble(), 900 - (p[1] as num).toDouble());
    return StrokeData(
      strokes: List<String>.from(j['s'] as List<dynamic>),
      medians: [
        for (final m in j['m'] as List<dynamic>)
          [for (final p in m as List<dynamic>) flip(p as List<dynamic>)],
      ],
    );
  }

  /// Loads the pack [languageId] from [bundle].
  static Future<LanguageContent> load(
    String languageId, {
    AssetBundle? bundle,
  }) async {
    final b = bundle ?? rootBundle;
    final base = 'assets/content/$languageId';
    Future<dynamic> json(String name) async =>
        jsonDecode(await b.loadString('$base/$name'));

    final pack = LanguagePack.fromJson(
      await json('pack.json') as Map<String, dynamic>,
    );
    final words = <int, Word>{
      for (final w in await json('vocab.json') as List<dynamic>)
        (w as Map<String, dynamic>)['id'] as int: Word.fromJson(w),
    };
    final sentences = <int, Sentence>{
      for (final s in await json('sentences.json') as List<dynamic>)
        (s as Map<String, dynamic>)['id'] as int: Sentence.fromJson(s),
    };
    final grammar = <String, GrammarPoint>{
      for (final g in await json('grammar.json') as List<dynamic>)
        (g as Map<String, dynamic>)['id'] as String: GrammarPoint.fromJson(g),
    };
    final levels = <String, Level>{};
    for (final info in pack.levels) {
      levels[info.id] = Level.fromJson(
        await json('levels/${info.id}.json') as Map<String, dynamic>,
      );
    }
    final index = Map<String, int>.from(
      (await json('strokes/index.json') as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      ),
    );
    return LanguageContent._(
      pack: pack,
      words: words,
      sentences: sentences,
      grammar: grammar,
      levels: levels,
      bundle: b,
      strokeIndex: index,
    );
  }
}

/// Registry of the languages that ship in the app.
class LanguageRegistry {
  const LanguageRegistry({required this.available, required this.comingSoon});

  final List<String> available;
  final List<ComingSoonLanguage> comingSoon;

  static Future<LanguageRegistry> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/content/languages.json',
    );
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return LanguageRegistry(
      available: List<String>.from(j['available'] as List<dynamic>),
      comingSoon: [
        for (final c in j['comingSoon'] as List<dynamic>)
          ComingSoonLanguage.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}
