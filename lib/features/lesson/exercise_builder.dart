import 'dart:math';

import '../../core/util/pinyin.dart';
import '../../data/progress_models.dart';
import '../../languages/language_content.dart';
import '../../languages/models.dart';
import '../../languages/pinyin_lookup.dart';
import 'exercise.dart';

/// Turns a lesson (or a set of due words) into the ordered exercises the
/// learner works through. Deterministic for a given seed, so tests are stable.
class ExerciseBuilder {
  ExerciseBuilder(this.content, this.lookup) {
    for (final w in content.allWords) {
      _byLevel.putIfAbsent(w.level, () => []).add(w);
    }
    for (final s in content.sentences.values) {
      _sentencesByLevel.putIfAbsent(s.level, () => []).add(s);
    }
  }

  final LanguageContent content;
  final PinyinLookup lookup;
  final Map<int, List<Word>> _byLevel = {};
  final Map<int, List<Sentence>> _sentencesByLevel = {};
  late final List<Sentence> _allSentences = content.sentences.values.toList();

  static const _chunk = 4;

  /// Builds the exercises for [lesson]. [progress] (word id -> state) lets
  /// checkpoints focus on the weakest words.
  List<Exercise> forLesson(
    Lesson lesson, {
    required int seed,
    Map<int, WordProgress> progress = const {},
  }) {
    final rnd = Random(seed);
    switch (lesson.type) {
      case LessonType.vocab:
        return _vocab(lesson, rnd);
      case LessonType.grammar:
        return _grammar(lesson, rnd);
      case LessonType.checkpoint:
        return _checkpoint(lesson, rnd, progress);
    }
  }

  /// Builds a spaced-repetition review for the given word ids.
  List<Exercise> forReview(List<int> wordIds, {required int seed}) {
    final rnd = Random(seed);
    final words = [
      for (final id in wordIds)
        if (content.words[id] != null) content.words[id]!,
    ];
    final out = <Exercise>[];
    const kinds = [
      ChoiceKind.listenMeaning,
      ChoiceKind.meaningWord,
      ChoiceKind.readMeaning,
      ChoiceKind.listenWord,
    ];
    for (var i = 0; i < words.length; i++) {
      out.add(
        _choice(
          kinds[(i + rnd.nextInt(2)) % kinds.length],
          words[i],
          rnd,
          Phase.review,
        ),
      );
    }
    final speakers = words.where((w) => w.length >= 1).take(3);
    for (final w in speakers) {
      out.add(SpeakExercise(word: w, phase: Phase.review));
    }
    return out;
  }

  // ---- vocabulary lesson ------------------------------------------------

  List<Exercise> _vocab(Lesson lesson, Random rnd) {
    final words = [
      for (final id in lesson.wordIds)
        if (content.words[id] != null) content.words[id]!,
    ];
    final out = <Exercise>[];
    final level = _levelOf(lesson, words);

    // Meet: introduce a few words, then check them straight away.
    for (var i = 0; i < words.length; i += _chunk) {
      final chunk = words.sublist(i, min(i + _chunk, words.length));
      for (final w in chunk) {
        out.add(IntroExercise(word: w, example: _bestExample(w)));
      }
      final quiz = [...chunk]..shuffle(rnd);
      for (final w in quiz) {
        out.add(_choice(ChoiceKind.listenMeaning, w, rnd, Phase.meet));
      }
    }

    // Recall: mix reading, meaning and listening.
    final recall = [...words]..shuffle(rnd);
    const recallKinds = [
      ChoiceKind.meaningWord,
      ChoiceKind.readMeaning,
      ChoiceKind.listenWord,
    ];
    for (var i = 0; i < recall.length; i++) {
      out.add(
        _choice(
          recallKinds[i % recallKinds.length],
          recall[i],
          rnd,
          Phase.recall,
        ),
      );
    }
    if (content.pack.hasTones) {
      final tonal =
          words
              .where((w) => toneVariants(w.romanizationNumeric).length >= 3)
              .toList()
            ..sort((a, b) => b.length.compareTo(a.length));
      for (final w in tonal.take(3)) {
        out.add(_choice(ChoiceKind.listenRomanization, w, rnd, Phase.recall));
      }
    }

    // Speak: say a handful of the new words aloud.
    final speakWords = ([...words]..shuffle(rnd)).take(min(5, words.length));
    for (final w in speakWords) {
      out.add(SpeakExercise(word: w));
    }

    // Write: trace the new characters.
    if (content.pack.hasStrokeWriting) {
      final limit = level <= 3 ? 3 : 2;
      for (final pick in _writingPicks(words, limit)) {
        out.add(WriteExercise(char: pick.$1, word: pick.$2));
      }
    }

    // Sentences: use the words in context, then say one aloud.
    out.addAll(_sentenceExercises(lesson, words, rnd, count: 3));
    final shadow = _shadowFor(lesson);
    if (shadow != null) out.add(shadow);
    return out;
  }

  int _levelOf(Lesson lesson, List<Word> words) =>
      words.isEmpty ? 1 : words.first.level;

  Sentence? _bestExample(Word w) {
    final ss = [
      for (final id in w.exampleIds)
        if (content.sentences[id] != null) content.sentences[id]!,
    ]..sort((a, b) => a.text.length.compareTo(b.text.length));
    return ss.isEmpty ? null : ss.first;
  }

  /// Up to [limit] (character, word) pairs worth writing, easiest first.
  List<(String, Word)> _writingPicks(List<Word> words, int limit) {
    final seen = <String>{};
    final picks = <(String, Word)>[];
    final ordered = [...words]..sort((a, b) => a.length.compareTo(b.length));
    for (final w in ordered) {
      for (final rune in w.text.runes) {
        final ch = String.fromCharCode(rune);
        if (content.hasStrokes(ch) && seen.add(ch)) {
          picks.add((ch, w));
          if (picks.length >= limit) return picks;
          break;
        }
      }
    }
    return picks;
  }

  // ---- sentence practice ------------------------------------------------

  List<Exercise> _sentenceExercises(
    Lesson lesson,
    List<Word> words,
    Random rnd, {
    required int count,
  }) {
    final pool = <Sentence>[];
    final seenIds = <int>{};
    for (final id in lesson.sentenceIds) {
      final s = content.sentences[id];
      if (s != null && seenIds.add(id)) pool.add(s);
    }
    if (pool.isEmpty) return const [];
    pool.sort((a, b) => a.text.length.compareTo(b.text.length));
    // Prefer a spread: shortest first, then random picks.
    final chosen = <Sentence>[pool.first];
    final rest = pool.skip(1).toList()..shuffle(rnd);
    chosen.addAll(rest.take(count - 1));

    final out = <Exercise>[];
    for (var i = 0; i < chosen.length; i++) {
      final s = chosen[i];
      if (i == 1) {
        final order = _orderFromSentence(s, rnd);
        if (order != null) {
          out.add(order);
          continue;
        }
      }
      out.add(
        _sentenceChoice(s, rnd, listenFirst: i == 0, phase: Phase.sentences),
      );
    }
    return out;
  }

  /// The shortest example sentence of the lesson, to repeat aloud.
  ShadowExercise? _shadowFor(Lesson lesson) {
    final sentences = [
      for (final id in lesson.sentenceIds)
        if (content.sentences[id] != null) content.sentences[id]!,
    ]..sort((a, b) => a.text.length.compareTo(b.text.length));
    // Skip the very shortest (often one or two syllables) when there is a choice.
    final pick = sentences.length > 2
        ? sentences[sentences.length ~/ 3]
        : sentences.firstOrNull;
    if (pick == null) return null;
    return ShadowExercise(
      text: pick.text,
      romanization: pick.romanization,
      translation: pick.translation,
      phase: Phase.sentences,
      wordIdSet: pick.wordIds.toSet(),
    );
  }

  SentenceChoiceExercise _sentenceChoice(
    Sentence s,
    Random rnd, {
    required bool listenFirst,
    required Phase phase,
  }) {
    final options = <String>{s.translation};
    // Same-level sentences of similar length make the best distractors;
    // widen the net if the level has too few.
    for (final (pool, low, high) in [
      (_sentencesByLevel[s.level] ?? const <Sentence>[], 0.5, 2.0),
      (_allSentences, 0.4, 2.5),
      (_allSentences, 0.0, 100.0),
    ]) {
      var guard = 0;
      while (options.length < 4 && guard++ < 200 && pool.isNotEmpty) {
        final c = pool[rnd.nextInt(pool.length)];
        final ratio = c.translation.length / s.translation.length;
        if (c.id != s.id && ratio > low && ratio < high) {
          options.add(c.translation);
        }
      }
      if (options.length >= 4) break;
    }
    final list = options.toList()..shuffle(rnd);
    return SentenceChoiceExercise(
      sentence: s,
      options: list,
      answerIndex: list.indexOf(s.translation),
      listenFirst: listenFirst,
      phase: phase,
    );
  }

  OrderExercise? _orderFromSentence(Sentence s, Random rnd) {
    if (RegExp(r'[0-9A-Za-z]').hasMatch(s.text)) return null;
    final tiles = lookup.segment(s.text);
    if (tiles.length < 3 || tiles.length > 8) return null;
    final bank = [...tiles]..shuffle(rnd);
    if (_same(bank, tiles)) bank.shuffle(rnd);
    return OrderExercise(
      translation: s.translation,
      answerTiles: tiles,
      bank: bank,
      fullText: s.text,
      romanization: s.romanization,
      phase: Phase.sentences,
      wordIdSet: s.wordIds.toSet(),
    );
  }

  bool _same(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---- grammar lesson ---------------------------------------------------

  List<Exercise> _grammar(Lesson lesson, Random rnd) {
    final out = <Exercise>[];
    for (final id in lesson.grammarIds) {
      final point = content.grammar[id];
      if (point == null) continue;
      out.add(GrammarExplainExercise(point: point));
      for (final ex in point.examples.take(2)) {
        out.add(
          ShadowExercise(
            text: ex.text,
            romanization: ex.romanization,
            translation: ex.translation,
            phase: Phase.grammar,
          ),
        );
      }
      for (final q in point.quiz) {
        switch (q) {
          case ChoiceQuiz():
            final correct = q.options[q.answerIndex];
            final shuffled = [...q.options]..shuffle(rnd);
            out.add(
              GrammarChoiceExercise(
                point: point,
                prompt: q.prompt,
                options: shuffled,
                answerIndex: shuffled.indexOf(correct),
              ),
            );
          case OrderQuiz():
            final bank = [...q.tokens]..shuffle(rnd);
            if (_same(bank, q.tokens) && q.tokens.length > 1) bank.shuffle(rnd);
            out.add(
              OrderExercise(
                translation: q.translation,
                answerTiles: q.tokens,
                bank: bank,
                fullText: q.answer,
                romanization: q.romanization,
                phase: Phase.grammar,
              ),
            );
        }
      }
    }
    return out;
  }

  // ---- checkpoint -------------------------------------------------------

  List<Exercise> _checkpoint(
    Lesson lesson,
    Random rnd,
    Map<int, WordProgress> progress,
  ) {
    final words = [
      for (final id in lesson.wordIds)
        if (content.words[id] != null) content.words[id]!,
    ];
    // Weakest first: never learned, then lowest box, then random.
    words.shuffle(rnd);
    words.sort((a, b) {
      final pa = progress[a.id]?.box ?? -1;
      final pb = progress[b.id]?.box ?? -1;
      return pa.compareTo(pb);
    });
    final focus = words.take(12).toList()..shuffle(rnd);
    const kinds = [
      ChoiceKind.listenMeaning,
      ChoiceKind.meaningWord,
      ChoiceKind.readMeaning,
      ChoiceKind.listenWord,
    ];
    final out = <Exercise>[
      for (var i = 0; i < focus.length; i++)
        _choice(kinds[i % kinds.length], focus[i], rnd, Phase.review),
    ];
    for (final w in focus.take(3)) {
      out.add(SpeakExercise(word: w, phase: Phase.review));
    }
    // Sentences built from the focus words.
    final sentenceIds = <int>[];
    for (final w in focus) {
      sentenceIds.addAll(w.exampleIds.take(1));
    }
    final sentences = [
      for (final id in sentenceIds.toSet())
        if (content.sentences[id] != null) content.sentences[id]!,
    ]..shuffle(rnd);
    for (final s in sentences.take(3)) {
      out.add(
        _sentenceChoice(
          s,
          rnd,
          listenFirst: out.length.isEven,
          phase: Phase.review,
        ),
      );
    }
    return out;
  }

  // ---- multiple choice --------------------------------------------------

  ChoiceExercise _choice(ChoiceKind kind, Word word, Random rnd, Phase phase) {
    if (kind == ChoiceKind.listenRomanization) {
      final variants = toneVariants(
        word.romanizationNumeric,
        seed: rnd.nextInt(1 << 30),
      );
      if (variants.length >= 3) {
        final correct = markPinyin(word.romanizationNumeric);
        final options = [correct, ...variants.take(3).map(markPinyin)]
          ..shuffle(rnd);
        return ChoiceExercise(
          kind: kind,
          word: word,
          options: options,
          answerIndex: options.indexOf(correct),
          phase: phase,
        );
      }
      return _choice(ChoiceKind.listenMeaning, word, rnd, phase);
    }
    final distractors = _distractors(word, 3, rnd);
    final scriptOptions =
        kind == ChoiceKind.meaningWord || kind == ChoiceKind.listenWord;
    String label(Word w) => scriptOptions ? w.text : _short(w.primaryMeaning);
    final options = [label(word), ...distractors.map(label)];
    final unique = options.toSet().toList()..shuffle(rnd);
    return ChoiceExercise(
      kind: kind,
      word: word,
      options: unique,
      answerIndex: unique.indexOf(label(word)),
      phase: phase,
    );
  }

  String _short(String meaning) {
    if (meaning.length <= 48) return meaning;
    final cut = meaning.substring(0, 48);
    final space = cut.lastIndexOf(' ');
    return '${space > 20 ? cut.substring(0, space) : cut}…';
  }

  List<Word> _distractors(Word target, int n, Random rnd) {
    final pool = <Word>[
      ...?_byLevel[target.level],
      if (target.level > 1) ...?_byLevel[target.level - 1],
    ];
    final targetMeaning = _short(target.primaryMeaning);
    final scored = <(double, Word)>[];
    for (final w in pool) {
      if (w.id == target.id || w.text == target.text) continue;
      if (_short(w.primaryMeaning) == targetMeaning) continue;
      var score = rnd.nextDouble();
      if (w.length == target.length) score += 1.5;
      if (w.partsOfSpeech.isNotEmpty &&
          target.partsOfSpeech.isNotEmpty &&
          w.partsOfSpeech.first == target.partsOfSpeech.first) {
        score += 1;
      }
      scored.add((score, w));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    final picked = <Word>[];
    final seenLabels = <String>{targetMeaning, target.text};
    for (final (_, w) in scored) {
      final m = _short(w.primaryMeaning);
      if (seenLabels.contains(m) || seenLabels.contains(w.text)) continue;
      seenLabels
        ..add(m)
        ..add(w.text);
      picked.add(w);
      if (picked.length == n) break;
    }
    return picked;
  }
}
