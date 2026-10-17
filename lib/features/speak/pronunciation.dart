import 'package:flutter/foundation.dart';

/// How one target word fared when compared with what the recogniser heard.
enum WordMark {
  /// Heard exactly (or as a true homophone).
  match,

  /// Heard something very similar: a small slip.
  close,

  /// Heard a different word.
  wrong,

  /// Not heard at all.
  missing,
}

@immutable
class WordResult {
  const WordResult({required this.target, required this.mark, this.heard});

  final String target;
  final WordMark mark;

  /// What was heard in this word's place, if anything.
  final String? heard;

  bool get ok => mark == WordMark.match || mark == WordMark.close;
}

/// The outcome of comparing a spoken attempt with its target text.
@immutable
class SpeechScore {
  const SpeechScore({
    required this.words,
    required this.extra,
    required this.accuracy,
    required this.heardText,
  });

  final List<WordResult> words;

  /// Words heard that were not in the target.
  final List<String> extra;

  /// 0..1: matches count fully, close ones partly, extras cost a little.
  final double accuracy;
  final String heardText;

  /// Whether this counts as a good attempt for a target of [targetWords]
  /// words: single words must be heard exactly, longer text needs 80%.
  bool get passed =>
      words.length <= 1 ? words.every((w) => w.ok) : accuracy >= 0.8;

  bool get perfect =>
      words.every((w) => w.mark == WordMark.match) && extra.isEmpty;

  List<WordResult> get problems => [
    for (final w in words)
      if (!w.ok) w,
  ];
}

/// Spoken numbers, so "3" and "three" compare equal.
const _ones = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
];
const _tens = [
  '',
  '',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
];

String _numberWords(int n) {
  if (n < 20) return _ones[n];
  if (n < 100) {
    final t = _tens[n ~/ 10];
    return n % 10 == 0 ? t : '$t ${_ones[n % 10]}';
  }
  if (n < 1000) {
    final rest = n % 100;
    final h = '${_ones[n ~/ 100]} hundred';
    return rest == 0 ? h : '$h ${_numberWords(rest)}';
  }
  return '$n';
}

const _contractions = {
  "i'm": 'i am',
  "you're": 'you are',
  "we're": 'we are',
  "they're": 'they are',
  "i'll": 'i will',
  "you'll": 'you will',
  "we'll": 'we will',
  "they'll": 'they will',
  "i've": 'i have',
  "you've": 'you have',
  "we've": 'we have',
  "they've": 'they have',
  "i'd": 'i would',
  "don't": 'do not',
  "doesn't": 'does not',
  "didn't": 'did not',
  "can't": 'can not',
  'cannot': 'can not',
  "won't": 'will not',
  "isn't": 'is not',
  "aren't": 'are not',
  "wasn't": 'was not',
  "weren't": 'were not',
  "couldn't": 'could not',
  "wouldn't": 'would not',
  "shouldn't": 'should not',
  "haven't": 'have not',
  "hasn't": 'has not',
  "let's": 'let us',
  "that's": 'that is',
  "it's": 'it is',
  "there's": 'there is',
  "what's": 'what is',
  "he's": 'he is',
  "she's": 'she is',
};

/// Words that sound the same, so the recogniser cannot tell them apart.
const _homophones = <List<String>>[
  ['to', 'too', 'two'],
  ['there', 'their'],
  ['write', 'right', 'rite'],
  ['hear', 'here'],
  ['wood', 'would'],
  ['one', 'won'],
  ['for', 'four', 'fore'],
  ['no', 'know'],
  ['know', 'no'],
  ['by', 'buy', 'bye'],
  ['see', 'sea'],
  ['sun', 'son'],
  ['be', 'bee'],
  ['wait', 'weight'],
  ['week', 'weak'],
  ['which', 'witch'],
  ['whether', 'weather'],
  ['you', 'ewe'],
  ['seat', 'seet'],
  ['whale', 'wail'],
  ['allowed', 'aloud'],
  ['made', 'maid'],
  ['piece', 'peace'],
  ['plain', 'plane'],
  ['principal', 'principle'],
  ['sale', 'sail'],
  ['tail', 'tale'],
  ['threw', 'through'],
  ['whole', 'hole'],
  ['your', "you're"],
];

final Map<String, Set<String>> _homophoneIndex = () {
  final m = <String, Set<String>>{};
  for (final g in _homophones) {
    for (final w in g) {
      m.putIfAbsent(w, () => {}).addAll(g);
    }
  }
  return m;
}();

/// Lower-cases, strips punctuation, spells out digits and expands common
/// contractions, so that "I'm" and "I am" or "3" and "three" agree.
List<String> tokenize(String text) {
  var t = text
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[-–—]'), ' ')
      .replaceAll(RegExp(r"[^a-z0-9' ]"), ' ');
  t = t.replaceAll(RegExp(r"(^|\s)'|'(\s|$)"), ' ');
  final out = <String>[];
  for (final raw in t.split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    final n = int.tryParse(raw);
    final word = n != null && n >= 0 && n < 1000 ? _numberWords(n) : raw;
    final expanded = _contractions[word] ?? word;
    out.addAll(expanded.split(' '));
  }
  return out;
}

const _endings = {'s', 'es', 'ed', 'd', 'ing', 'er', 'ly', 'ies', 'y'};

/// 0 for the same word, 0.4 when only an ending differs (shop / shops), and
/// 1 for a different word. A single changed sound inside a word, such as
/// shells / sells, is a real pronunciation slip and counts as different.
double _wordCost(String target, String heard) {
  if (target == heard) return 0;
  if (_homophoneIndex[target]?.contains(heard) ?? false) return 0;
  final shorter = target.length <= heard.length ? target : heard;
  final longer = identical(shorter, target) ? heard : target;
  if (shorter.length >= 3 &&
      longer.startsWith(shorter) &&
      _endings.contains(longer.substring(shorter.length))) {
    return 0.4;
  }
  return 1;
}

/// Compares [target] with what was [heard]. [alternatives] are other
/// transcriptions of the same speech; for a single target word one of them
/// matching earns a "close".
SpeechScore scoreSpeech(
  String target,
  String heard, {
  List<String> alternatives = const [],
}) {
  final t = tokenize(target);
  final h = tokenize(heard);

  // Align with edit distance over words.
  final n = t.length;
  final m = h.length;
  final cost = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    cost[i][0] = i.toDouble();
  }
  for (var j = 1; j <= m; j++) {
    cost[0][j] = j.toDouble();
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final sub = cost[i - 1][j - 1] + _wordCost(t[i - 1], h[j - 1]);
      final del = cost[i - 1][j] + 1;
      final ins = cost[i][j - 1] + 1;
      cost[i][j] = [sub, del, ins].reduce((x, y) => x < y ? x : y);
    }
  }
  final results = List<WordResult?>.filled(n, null);
  final extra = <String>[];
  var i = n;
  var j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0) {
      final c = _wordCost(t[i - 1], h[j - 1]);
      if ((cost[i][j] - (cost[i - 1][j - 1] + c)).abs() < 1e-9) {
        results[i - 1] = WordResult(
          target: t[i - 1],
          heard: h[j - 1],
          mark: c == 0
              ? WordMark.match
              : c < 1
              ? WordMark.close
              : WordMark.wrong,
        );
        i--;
        j--;
        continue;
      }
    }
    if (i > 0 && (cost[i][j] - (cost[i - 1][j] + 1)).abs() < 1e-9) {
      results[i - 1] = WordResult(target: t[i - 1], mark: WordMark.missing);
      i--;
    } else {
      extra.insert(0, h[j - 1]);
      j--;
    }
  }

  var words = [for (final r in results) r!];

  // One target word that was misheard, but the recogniser also considered it.
  if (n == 1 && words.first.mark != WordMark.match) {
    for (final alt in alternatives) {
      final a = tokenize(alt);
      if (a.contains(t.first)) {
        words = [
          WordResult(
            target: t.first,
            mark: WordMark.close,
            heard: words.first.heard,
          ),
        ];
        break;
      }
    }
  }

  var points = 0.0;
  for (final w in words) {
    points += switch (w.mark) {
      WordMark.match => 1,
      WordMark.close => 0.6,
      _ => 0,
    };
  }
  final accuracy = n == 0
      ? 0.0
      : ((points - 0.25 * extra.length) / n).clamp(0.0, 1.0);
  return SpeechScore(
    words: words,
    extra: extra,
    accuracy: accuracy,
    heardText: heard,
  );
}
