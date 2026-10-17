import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// One vocabulary item of a language pack.
@immutable
class Word {
  const Word({
    required this.id,
    required this.text,
    required this.altText,
    required this.romanization,
    required this.romanizationNumeric,
    required this.meanings,
    required this.partsOfSpeech,
    required this.level,
    required this.exampleIds,
    String? lemma,
    this.article,
    this.note = '',
  }) : lemma = lemma ?? text;

  factory Word.fromJson(Map<String, dynamic> j) => Word(
    id: j['id'] as int,
    text: j['s'] as String,
    altText: j['t'] as String? ?? j['s'] as String,
    romanization: j['y'] as String,
    romanizationNumeric: j['n'] as String,
    meanings: List<String>.from(j['m'] as List<dynamic>),
    partsOfSpeech: List<String>.from(j['pos'] as List<dynamic>? ?? const []),
    level: j['lvl'] as int,
    exampleIds: List<int>.from(j['ex'] as List<dynamic>? ?? const []),
    lemma: j['l'] as String?,
    article: j['g'] as String?,
    note: j['x'] as String? ?? '',
  );

  final int id;

  /// The word as shown and spoken: simplified hanzi for Chinese, and for a
  /// German noun the article with the noun (`der Hund`).
  final String text;

  /// The word without any article (`Hund`); equals [text] otherwise.
  final String lemma;

  /// Grammatical article of a noun (`der`, `die`, `das`), if the language
  /// has gendered nouns.
  final String? article;

  /// A short grammar hint shown with the word, e.g. `Plural: die Hunde`.
  final String note;

  /// Alternative script form (traditional hanzi), equal to [text] when none.
  final String altText;

  /// Romanization with tone marks, e.g. `nǐ hǎo`.
  final String romanization;

  /// Romanization with tone digits, e.g. `ni3 hao3`.
  final String romanizationNumeric;
  final List<String> meanings;
  final List<String> partsOfSpeech;
  final int level;
  final List<int> exampleIds;

  /// The shortest everyday English gloss, for flashcards and answer options.
  String get primaryMeaning => meanings.first;

  /// Number of characters (syllables for Chinese).
  int get length => text.runes.length;

  @override
  bool operator ==(Object other) => other is Word && other.id == id;

  @override
  int get hashCode => id;
}

@immutable
class Sentence {
  const Sentence({
    required this.id,
    required this.text,
    required this.translation,
    required this.romanization,
    required this.level,
    required this.wordIds,
  });

  factory Sentence.fromJson(Map<String, dynamic> j) => Sentence(
    id: j['id'] as int,
    text: j['t'] as String,
    translation: j['en'] as String,
    romanization: j['r'] as String? ?? '',
    level: j['lvl'] as int,
    wordIds: List<int>.from(j['w'] as List<dynamic>? ?? const []),
  );

  final int id;
  final String text;
  final String translation;
  final String romanization;
  final int level;
  final List<int> wordIds;
}

@immutable
class GrammarExample {
  const GrammarExample({
    required this.text,
    required this.translation,
    required this.romanization,
  });

  factory GrammarExample.fromJson(Map<String, dynamic> j) => GrammarExample(
    text: j['t'] as String,
    translation: j['en'] as String,
    romanization: j['r'] as String? ?? '',
  );

  final String text;
  final String translation;
  final String romanization;
}

/// A question that checks a grammar point.
sealed class GrammarQuiz {
  const GrammarQuiz();

  factory GrammarQuiz.fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'order':
        return OrderQuiz(
          translation: j['en'] as String,
          answer: j['answer'] as String,
          romanization: j['r'] as String? ?? '',
          tokens: List<String>.from(j['tokens'] as List<dynamic>),
        );
      default:
        return ChoiceQuiz(
          prompt: j['prompt'] as String,
          options: List<String>.from(j['options'] as List<dynamic>),
          answerIndex: j['answer'] as int,
        );
    }
  }
}

class ChoiceQuiz extends GrammarQuiz {
  const ChoiceQuiz({
    required this.prompt,
    required this.options,
    required this.answerIndex,
  });

  final String prompt;
  final List<String> options;
  final int answerIndex;
}

class OrderQuiz extends GrammarQuiz {
  const OrderQuiz({
    required this.translation,
    required this.answer,
    required this.romanization,
    required this.tokens,
  });

  final String translation;
  final String answer;
  final String romanization;

  /// The answer split into the tiles the learner arranges.
  final List<String> tokens;
}

@immutable
class GrammarPoint {
  const GrammarPoint({
    required this.id,
    required this.level,
    required this.title,
    required this.pattern,
    required this.explanation,
    required this.examples,
    required this.quiz,
  });

  factory GrammarPoint.fromJson(Map<String, dynamic> j) => GrammarPoint(
    id: j['id'] as String,
    level: j['lvl'] as int,
    title: j['title'] as String,
    pattern: j['pattern'] as String,
    explanation: j['explanation'] as String,
    examples: [
      for (final e in j['examples'] as List<dynamic>)
        GrammarExample.fromJson(e as Map<String, dynamic>),
    ],
    quiz: [
      for (final q in j['quiz'] as List<dynamic>)
        GrammarQuiz.fromJson(q as Map<String, dynamic>),
    ],
  );

  final String id;
  final int level;
  final String title;
  final String pattern;
  final String explanation;
  final List<GrammarExample> examples;
  final List<GrammarQuiz> quiz;
}

enum LessonType { vocab, grammar, checkpoint }

@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.wordIds,
    required this.sentenceIds,
    required this.grammarIds,
    required this.minutes,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'] as String,
    type: LessonType.values.byName(j['type'] as String),
    title: j['title'] as String,
    subtitle: j['subtitle'] as String,
    wordIds: List<int>.from(j['words'] as List<dynamic>? ?? const []),
    sentenceIds: List<int>.from(j['sentences'] as List<dynamic>? ?? const []),
    grammarIds: List<String>.from(j['grammar'] as List<dynamic>? ?? const []),
    minutes: j['minutes'] as int,
  );

  final String id;
  final LessonType type;
  final String title;
  final String subtitle;
  final List<int> wordIds;
  final List<int> sentenceIds;
  final List<String> grammarIds;
  final int minutes;
}

@immutable
class Unit {
  const Unit({required this.id, required this.title, required this.lessons});

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
    id: j['id'] as String,
    title: j['title'] as String,
    lessons: [
      for (final l in j['lessons'] as List<dynamic>)
        Lesson.fromJson(l as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final List<Lesson> lessons;
}

/// Summary of one proficiency level (HSK 1 ... HSK 6 for Chinese).
@immutable
class LevelInfo {
  const LevelInfo({
    required this.id,
    required this.number,
    required this.name,
    required this.title,
    required this.description,
    required this.wordCount,
    required this.unitCount,
    required this.lessonCount,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> j) => LevelInfo(
    id: j['id'] as String,
    number: j['number'] as int,
    name: j['name'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    wordCount: j['wordCount'] as int,
    unitCount: j['unitCount'] as int,
    lessonCount: j['lessonCount'] as int,
  );

  final String id;
  final int number;
  final String name;
  final String title;
  final String description;
  final int wordCount;
  final int unitCount;
  final int lessonCount;
}

@immutable
class Level {
  const Level({required this.info, required this.units});

  factory Level.fromJson(Map<String, dynamic> j) => Level(
    info: LevelInfo.fromJson(j),
    units: [
      for (final u in j['units'] as List<dynamic>)
        Unit.fromJson(u as Map<String, dynamic>),
    ],
  );

  final LevelInfo info;
  final List<Unit> units;

  Iterable<Lesson> get lessons => units.expand((u) => u.lessons);
}

@immutable
class Attribution {
  const Attribution({
    required this.name,
    required this.license,
    required this.url,
    required this.use,
  });

  factory Attribution.fromJson(Map<String, dynamic> j) => Attribution(
    name: j['name'] as String,
    license: j['license'] as String,
    url: j['url'] as String,
    use: j['use'] as String,
  );

  final String name;
  final String license;
  final String url;
  final String use;
}

/// Everything the app needs to know about a language to teach it. A new
/// language is a new pack folder plus a registry entry; no app code changes.
@immutable
class LanguagePack {
  const LanguagePack({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.script,
    required this.romanizationLabel,
    required this.ttsLocale,
    required this.sttLocale,
    required this.hasTones,
    required this.hasStrokeWriting,
    required this.levelLabel,
    required this.levels,
    required this.attribution,
    this.hasGender = false,
    this.typingPractice = false,
    this.hasRomanization = true,
    this.colorCoding,
    this.voiceTestPhrase = '',
    this.licenseFiles = const [],
  });

  factory LanguagePack.fromJson(Map<String, dynamic> j) => LanguagePack(
    id: j['id'] as String,
    name: j['name'] as String,
    nativeName: j['nativeName'] as String,
    flag: j['flag'] as String,
    script: j['script'] as String,
    romanizationLabel: j['romanizationLabel'] as String,
    ttsLocale: j['ttsLocale'] as String,
    sttLocale: j['sttLocale'] as String,
    hasTones: j['hasTones'] as bool,
    hasStrokeWriting: j['hasStrokeWriting'] as bool,
    hasGender: j['hasGender'] as bool? ?? false,
    typingPractice: j['typingPractice'] as bool? ?? false,
    hasRomanization: j['hasRomanization'] as bool? ?? true,
    colorCoding: j['colorCoding'] as String?,
    voiceTestPhrase: j['voiceTestPhrase'] as String? ?? '',
    licenseFiles: List<String>.from(
      j['licenseFiles'] as List<dynamic>? ?? const [],
    ),
    levelLabel: j['levelLabel'] as String,
    levels: [
      for (final l in j['levels'] as List<dynamic>)
        LevelInfo.fromJson(l as Map<String, dynamic>),
    ],
    attribution: [
      for (final a in j['attribution'] as List<dynamic>)
        Attribution.fromJson(a as Map<String, dynamic>),
    ],
  );

  final String id;
  final String name;
  final String nativeName;
  final String flag;
  final String script;
  final String romanizationLabel;
  final String ttsLocale;
  final String sttLocale;
  final bool hasTones;
  final bool hasStrokeWriting;

  /// Nouns have a grammatical gender shown as an article (German).
  final bool hasGender;

  /// Writing practice is typing what you hear (languages without a stroke
  /// guide).
  final bool typingPractice;

  /// Whether a romanization (pinyin) accompanies the script.
  final bool hasRomanization;

  /// What the optional colour hints mark: `tones` or `genders`; null for none.
  final String? colorCoding;

  /// A short sentence to test the teacher voice.
  final String voiceTestPhrase;

  /// Asset paths of the licence texts shown on the About screen.
  final List<String> licenseFiles;
  final String levelLabel;
  final List<LevelInfo> levels;
  final List<Attribution> attribution;
}

/// Stroke-order data for one character.
///
/// Both parts live in a 1024x1024 box. The outlines are SVG path data in the
/// source's y-up space (flip with `y' = 900 - y` before drawing); the
/// medians are already flipped to y-down.
@immutable
class StrokeData {
  const StrokeData({required this.strokes, required this.medians});

  /// SVG path data of each stroke outline, in source (y-up) space.
  final List<String> strokes;

  /// Centre-line of each stroke, already flipped to y-down.
  final List<List<Offset>> medians;
}

@immutable
class ComingSoonLanguage {
  const ComingSoonLanguage({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  factory ComingSoonLanguage.fromJson(Map<String, dynamic> j) =>
      ComingSoonLanguage(
        id: j['id'] as String,
        name: j['name'] as String,
        nativeName: j['nativeName'] as String,
        flag: j['flag'] as String,
      );

  final String id;
  final String name;
  final String nativeName;
  final String flag;
}

/// A language that ships in the app, as listed in the language registry.
@immutable
class LanguageSummary {
  const LanguageSummary({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  factory LanguageSummary.fromJson(Map<String, dynamic> j) => LanguageSummary(
    id: j['id'] as String,
    name: j['name'] as String,
    nativeName: j['nativeName'] as String,
    flag: j['flag'] as String,
  );

  final String id;
  final String name;
  final String nativeName;
  final String flag;
}
