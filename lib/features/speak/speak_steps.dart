import 'dart:math';

import 'speak_content.dart';

/// The stage of a practice session; shown as the step label.
enum SpeakPhase { learn, listen, say, stress, recall, shadow, melody, talk }

/// One short step of a practice set. Plain data; the session screen decides
/// how to present each kind.
sealed class SpeakStep {
  const SpeakStep();

  SpeakPhase get phase;

  /// Whether the learner must respond before the session moves on.
  bool get needsAnswer => true;
}

typedef IpaWord = ({String word, String ipa});

/// A card with a tip, shown before the exercises.
class TipStep extends SpeakStep {
  const TipStep({
    required this.title,
    required this.body,
    this.symbols = const [],
    this.examples = const [],
    this.phrases = const [],
  });

  final String title;
  final String body;
  final List<String> symbols;

  /// Useful phrases to read out before a role-play.
  final List<String> phrases;
  final List<IpaWord> examples;

  @override
  SpeakPhase get phase => SpeakPhase.learn;

  @override
  bool get needsAnswer => false;
}

/// Hear one word of a pair and pick which one it was.
class ListenPickStep extends SpeakStep {
  const ListenPickStep({
    required this.word,
    required this.options,
    required this.ipaByWord,
  });

  /// The word that is played.
  final String word;

  /// The two words to choose from, in display order.
  final List<String> options;
  final Map<String, String> ipaByWord;

  int get answerIndex => options.indexOf(word);

  @override
  SpeakPhase get phase => SpeakPhase.listen;
}

/// Say one word; checked by speech recognition.
class SayWordStep extends SpeakStep {
  const SayWordStep({
    required this.word,
    required this.ipa,
    this.contrast,
    this.tip,
    this.vocabId,
  });

  final String word;
  final String ipa;

  /// The look-alike word this exercise trains against (ship / sheep).
  final String? contrast;
  final String? tip;
  final int? vocabId;

  @override
  SpeakPhase get phase => SpeakPhase.say;
}

/// Say a phrase or sentence back (shadowing); scored word by word.
class SayTextStep extends SpeakStep {
  const SayTextStep({
    required this.text,
    this.shadow = true,
    this.slowFirst = false,
    this.passAt = 0.8,
    this.hint,
  });

  final String text;

  /// True for sentence shadowing, false for a tongue twister or phrase.
  final bool shadow;

  /// Offer the slow version first (tongue twisters).
  final bool slowFirst;
  final double passAt;
  final String? hint;

  @override
  SpeakPhase get phase => shadow ? SpeakPhase.shadow : SpeakPhase.say;
}

/// Which syllable carries the main stress?
class StressPickStep extends SpeakStep {
  const StressPickStep({required this.word});

  final StressWord word;

  /// Words with a part of speech (record, noun or verb) sound different in
  /// each use, and a speech engine cannot be told which to say.
  bool get canPlay => word.pos == null;

  @override
  SpeakPhase get phase => SpeakPhase.stress;
}

class VocabIntroStep extends SpeakStep {
  const VocabIntroStep({required this.word});

  final VocabWord word;

  @override
  SpeakPhase get phase => SpeakPhase.learn;

  @override
  bool get needsAnswer => false;
}

/// See a definition, pick the word.
class VocabRecallStep extends SpeakStep {
  const VocabRecallStep({required this.word, required this.options});

  final VocabWord word;
  final List<VocabWord> options;

  int get answerIndex => options.indexWhere((o) => o.id == word.id);

  @override
  SpeakPhase get phase => SpeakPhase.recall;
}

/// Copy the melody, rhythm and pace of a sentence; the voice is analysed and
/// compared with the model's.
class MelodyStep extends SpeakStep {
  const MelodyStep({required this.text});

  final String text;

  @override
  SpeakPhase get phase => SpeakPhase.melody;
}

/// One turn of a role-play: the partner speaks, the learner answers.
class TalkTurnStep extends SpeakStep {
  const TalkTurnStep({
    required this.partner,
    required this.turn,
    required this.number,
    required this.total,
  });

  final String partner;
  final TalkTurn turn;

  /// 1-based position in the conversation.
  final int number;
  final int total;

  @override
  SpeakPhase get phase => SpeakPhase.talk;
}

/// Turns a practice set into its steps. Deterministic for a given [seed].
class SpeakStepBuilder {
  SpeakStepBuilder(this.content, {required int seed}) : _random = Random(seed);

  final SpeakContent content;
  final Random _random;

  static const soundPicks = 4;
  static const soundSays = 4;
  static const stressPicks = 8;
  static const stressSays = 3;
  static const reviewWords = 8;
  static const melodyLines = 5;

  List<T> _shuffled<T>(Iterable<T> items) => [...items]..shuffle(_random);

  /// Steps for the set with [id], or an empty list if it does not exist.
  List<SpeakStep> forSet(String id) {
    final parts = id.split(':');
    switch (parts.first) {
      case 'snd':
        final s = content.soundSet(parts[1]);
        return s == null ? const [] : _sounds(s);
      case 'str':
        final s = content.stressSet(parts[1]);
        return s == null ? const [] : _stress(s);
      case 'voc':
        final u = content.vocabUnit(parts[1]);
        return u == null ? const [] : _vocab(u, int.parse(parts[2]));
      case 'sh':
        final s = content.shadowSet(parts[1]);
        return s == null ? const [] : _shadow(s);
      case 'mel':
        final s = content.shadowSet(parts[1]);
        return s == null ? const [] : _melody(s);
      case 'tw':
        return _twisters(int.parse(parts[1]));
      case 'talk':
        final t = content.talk(parts[1]);
        return t == null ? const [] : _talk(t);
    }
    return const [];
  }

  List<SpeakStep> _sounds(SoundSet s) {
    final steps = <SpeakStep>[
      TipStep(
        title: s.title,
        body: s.tip,
        symbols: s.symbols,
        examples: [
          for (final p in s.pairs.take(2)) ...[
            (word: p.a, ipa: p.ipaA),
            (word: p.b, ipa: p.ipaB),
          ],
        ],
      ),
    ];
    final picks = _shuffled(s.pairs).take(soundPicks);
    for (final p in picks) {
      final target = _random.nextBool() ? p.a : p.b;
      final options = _random.nextBool() ? [p.a, p.b] : [p.b, p.a];
      steps.add(
        ListenPickStep(
          word: target,
          options: options,
          ipaByWord: {p.a: p.ipaA, p.b: p.ipaB},
        ),
      );
    }
    for (final p in _shuffled(s.pairs).take(soundSays)) {
      final word = _random.nextBool() ? p.a : p.b;
      steps.add(
        SayWordStep(
          word: word,
          ipa: p.ipaOf(word),
          contrast: p.otherOf(word),
          tip: s.tip,
        ),
      );
    }
    for (final phrase in _shuffled(s.phrases).take(2)) {
      steps.add(SayTextStep(text: phrase, shadow: false, passAt: 0.75));
    }
    return steps;
  }

  List<SpeakStep> _stress(StressSet s) {
    final steps = <SpeakStep>[
      TipStep(
        title: s.title,
        body: s.tip,
        examples: [
          for (final w in s.words.where((w) => w.pos == null).take(3))
            (word: w.word, ipa: w.ipa),
        ],
      ),
    ];
    final chosen = _shuffled(s.words).take(stressPicks).toList();
    for (final w in chosen) {
      steps.add(StressPickStep(word: w));
    }
    for (final w in chosen.where((w) => w.pos == null).take(stressSays)) {
      steps.add(SayWordStep(word: w.word, ipa: w.ipa, tip: s.tip));
    }
    return steps;
  }

  List<SpeakStep> _vocab(VocabUnit u, int part) {
    final from = (part - 1) * SpeakContent.wordsPerPart;
    if (from >= u.words.length) return const [];
    final to = min(from + SpeakContent.wordsPerPart, u.words.length);
    final words = u.words.sublist(from, to);
    final steps = <SpeakStep>[for (final w in words) VocabIntroStep(word: w)];
    for (final w in _shuffled(words)) {
      steps.add(_recall(w, u.words));
    }
    for (final w in _shuffled(words)) {
      steps.add(SayWordStep(word: w.word, ipa: w.ipa, vocabId: w.id));
    }
    for (final w in _shuffled(words).take(2)) {
      steps.add(SayTextStep(text: w.example, passAt: 0.75));
    }
    return steps;
  }

  VocabRecallStep _recall(VocabWord w, List<VocabWord> pool) {
    final others = _shuffled(pool.where((o) => o.id != w.id)).take(3);
    return VocabRecallStep(word: w, options: _shuffled([w, ...others]));
  }

  List<SpeakStep> _shadow(ShadowSet s) => [
    TipStep(title: s.title, body: s.tip),
    for (final line in s.items) SayTextStep(text: line),
  ];

  List<SpeakStep> _talk(Talk t) => [
    TipStep(
      title: t.title,
      body: t.setting,
      examples: const [],
      phrases: t.phrases,
    ),
    for (var i = 0; i < t.turns.length; i++)
      TalkTurnStep(
        partner: t.partner,
        turn: t.turns[i],
        number: i + 1,
        total: t.turns.length,
      ),
  ];

  List<SpeakStep> _melody(ShadowSet s) => [
    TipStep(title: s.title, body: s.tip),
    for (final line in _shuffled(s.items).take(melodyLines))
      MelodyStep(text: line),
  ];

  List<SpeakStep> _twisters(int n) {
    final from = (n - 1) * SpeakContent.twistersPerSet;
    if (from < 0 || from >= content.twisters.length) return const [];
    final to = min(from + SpeakContent.twistersPerSet, content.twisters.length);
    return [
      const TipStep(
        title: 'Tongue twisters',
        body:
            'Start slowly and clearly, then speed up. Accuracy first: a clean slow twister beats a fast messy one.',
      ),
      for (final t in content.twisters.sublist(from, to))
        SayTextStep(
          text: t.text,
          shadow: false,
          slowFirst: true,
          passAt: 0.7,
          hint: t.focus,
        ),
    ];
  }

  /// A review of vocabulary the learner already met: recall, then say.
  List<SpeakStep> forReview(List<int> wordIds) {
    final words = [
      for (final id in wordIds.take(reviewWords))
        if (content.wordById(id) != null) content.wordById(id)!,
    ];
    final all = content.vocab.expand((u) => u.words).toList();
    return [
      for (final w in words) _recall(w, all),
      for (final w in words)
        SayWordStep(word: w.word, ipa: w.ipa, vocabId: w.id),
    ];
  }
}
