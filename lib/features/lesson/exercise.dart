import '../../languages/models.dart';

/// The stage of a lesson an exercise belongs to; shown as the step label.
enum Phase { meet, recall, speak, write, sentences, grammar, review }

/// One short step of a lesson. Exercises are plain data; the lesson screen
/// decides how to present each kind.
sealed class Exercise {
  const Exercise();

  Phase get phase;

  /// Words this exercise teaches or tests (drives spaced repetition).
  Set<int> get wordIds => const {};

  /// Whether the learner must respond before the lesson moves on.
  bool get needsAnswer => true;
}

class IntroExercise extends Exercise {
  const IntroExercise({required this.word, this.example});

  final Word word;
  final Sentence? example;

  @override
  Phase get phase => Phase.meet;

  @override
  Set<int> get wordIds => {word.id};

  @override
  bool get needsAnswer => false;
}

/// How a multiple-choice question is asked.
enum ChoiceKind {
  /// Hear the word, pick the meaning.
  listenMeaning,

  /// See the word, pick the meaning.
  readMeaning,

  /// See the meaning, pick the word.
  meaningWord,

  /// Hear the word, pick the word.
  listenWord,

  /// Hear the word, pick the romanization with the right tones.
  listenRomanization,
}

class ChoiceExercise extends Exercise {
  const ChoiceExercise({
    required this.kind,
    required this.word,
    required this.options,
    required this.answerIndex,
    required this.phase,
  });

  final ChoiceKind kind;
  final Word word;
  final List<String> options;
  final int answerIndex;

  @override
  final Phase phase;

  @override
  Set<int> get wordIds => {word.id};

  bool get promptIsAudio =>
      kind == ChoiceKind.listenMeaning ||
      kind == ChoiceKind.listenWord ||
      kind == ChoiceKind.listenRomanization;

  /// Options that are script (large type) rather than English.
  bool get optionsAreScript =>
      kind == ChoiceKind.meaningWord || kind == ChoiceKind.listenWord;
}

class SpeakExercise extends Exercise {
  const SpeakExercise({required this.word, this.phase = Phase.speak});

  final Word word;

  @override
  final Phase phase;

  @override
  Set<int> get wordIds => {word.id};
}

class WriteExercise extends Exercise {
  const WriteExercise({required this.char, required this.word});

  final String char;
  final Word word;

  @override
  Phase get phase => Phase.write;

  @override
  Set<int> get wordIds => {word.id};
}

class SentenceChoiceExercise extends Exercise {
  const SentenceChoiceExercise({
    required this.sentence,
    required this.options,
    required this.answerIndex,
    required this.listenFirst,
    this.phase = Phase.sentences,
  });

  final Sentence sentence;
  final List<String> options;
  final int answerIndex;

  /// Hide the text at first and play the sentence (listening practice).
  final bool listenFirst;

  @override
  final Phase phase;

  @override
  Set<int> get wordIds => sentence.wordIds.toSet();
}

class OrderExercise extends Exercise {
  const OrderExercise({
    required this.translation,
    required this.answerTiles,
    required this.bank,
    required this.fullText,
    required this.romanization,
    required this.phase,
    this.wordIdSet = const {},
  });

  final String translation;

  /// The tiles in the correct order.
  final List<String> answerTiles;

  /// The tiles in shuffled order for the learner to pick from.
  final List<String> bank;
  final String fullText;
  final String romanization;
  final Set<int> wordIdSet;

  @override
  final Phase phase;

  @override
  Set<int> get wordIds => wordIdSet;
}

/// Listen to a sentence, then say it back (shadowing).
class ShadowExercise extends Exercise {
  const ShadowExercise({
    required this.text,
    required this.romanization,
    required this.translation,
    required this.phase,
    this.wordIdSet = const {},
  });

  final String text;
  final String romanization;
  final String translation;
  final Set<int> wordIdSet;

  @override
  final Phase phase;

  @override
  Set<int> get wordIds => wordIdSet;
}

class GrammarExplainExercise extends Exercise {
  const GrammarExplainExercise({required this.point});

  final GrammarPoint point;

  @override
  Phase get phase => Phase.grammar;

  @override
  bool get needsAnswer => false;
}

class GrammarChoiceExercise extends Exercise {
  const GrammarChoiceExercise({
    required this.point,
    required this.prompt,
    required this.options,
    required this.answerIndex,
  });

  final GrammarPoint point;
  final String prompt;
  final List<String> options;
  final int answerIndex;

  @override
  Phase get phase => Phase.grammar;
}
