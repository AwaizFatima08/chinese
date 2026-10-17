import '../core/util/pinyin.dart';
import 'models.dart';
import 'pinyin_lookup.dart';

/// Language-specific text handling behind one interface: splitting
/// sentences into tiles, romanizing tiles, and judging spoken answers.
abstract class LanguageTools {
  /// Splits [text] into the tiles of a word-order exercise, in order,
  /// without punctuation.
  List<String> segment(String text);

  /// Romanization to print above a tile, or null when the language has none.
  String? romanizeTile(String tile);

  /// Judges what the recogniser heard against the target [word].
  SpeechMatch matchWord({required Word word, required String heard});

  /// How much of [target] was said, from 0 to 1.
  double similarity(String target, String heard);

  /// Tools for the language of [pack], built from its [words].
  static LanguageTools forPack(LanguagePack pack, Iterable<Word> words) =>
      pack.id == 'zh' ? ChineseTools(PinyinLookup(words)) : TextTools(words);
}

/// Chinese: judged by sound through pinyin, tiles are dictionary words.
class ChineseTools implements LanguageTools {
  ChineseTools(this.lookup);

  final PinyinLookup lookup;

  @override
  List<String> segment(String text) => lookup.segment(text);

  @override
  String? romanizeTile(String tile) {
    final numeric = lookup.numericOf(tile);
    return numeric == null ? null : markPinyin(numeric);
  }

  @override
  SpeechMatch matchWord({required Word word, required String heard}) =>
      lookup.match(
        target: word.text,
        targetNumeric: word.romanizationNumeric,
        heard: heard,
      );

  @override
  double similarity(String target, String heard) =>
      lookup.similarity(target, heard);
}

/// Alphabetic languages (German): words are separated by spaces and the
/// recogniser returns text, so answers are judged on normalised spelling.
class TextTools implements LanguageTools {
  TextTools(Iterable<Word> words) {
    for (final w in words) {
      // Words that are never capitalised mid-sentence, so a capital at the
      // start of a sentence can be lowered to hide the hint.
      if (w.article == null) {
        final lower = w.lemma.toLowerCase();
        if (lower == w.lemma) _lowercaseWords.add(lower);
      }
    }
  }

  final Set<String> _lowercaseWords = {};

  static final RegExp _edge = RegExp(
    r'''^[\s"'„“”‚‘’«»()\[\]{}.,;:!?¿¡…–—-]+|[\s"'„“”‚‘’«»()\[\]{}.,;:!?¿¡…–—-]+$''',
  );

  @override
  List<String> segment(String text) {
    final tiles = <String>[];
    for (final raw in text.split(RegExp(r'\s+'))) {
      final t = raw.replaceAll(_edge, '');
      if (t.isNotEmpty) tiles.add(t);
    }
    if (tiles.isNotEmpty) {
      final lower = tiles.first.toLowerCase();
      if (lower != tiles.first && _lowercaseWords.contains(lower)) {
        tiles[0] = lower;
      }
    }
    return tiles;
  }

  @override
  String? romanizeTile(String tile) => null;

  static const _digits = {
    '0': 'null',
    '1': 'eins',
    '2': 'zwei',
    '3': 'drei',
    '4': 'vier',
    '5': 'fünf',
    '6': 'sechs',
    '7': 'sieben',
    '8': 'acht',
    '9': 'neun',
    '10': 'zehn',
    '11': 'elf',
    '12': 'zwölf',
    '20': 'zwanzig',
    '100': 'hundert',
  };

  /// Lower-case, `ß` as `ss`, no punctuation; digits as words.
  static List<String> tokens(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-zäöü0-9\s]'), ' ');
    return [
      for (final t in cleaned.split(RegExp(r'\s+')))
        if (t.isNotEmpty) _digits[t] ?? t,
    ];
  }

  /// Edit distance between two strings.
  static int distance(String a, String b) {
    if (a == b) return 0;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [
          prev[j] + 1,
          cur[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Tokens match when equal, or one letter apart for longer words.
  static bool _sameToken(String a, String b) {
    if (a == b) return true;
    if (a == 'ein' && b == 'eins' || a == 'eins' && b == 'ein') return true;
    return a.length >= 5 && b.length >= 5 && distance(a, b) <= 1;
  }

  @override
  SpeechMatch matchWord({required Word word, required String heard}) {
    final target = tokens(word.lemma);
    final said = tokens(heard);
    if (target.isEmpty || said.isEmpty) return SpeechMatch.miss;
    for (var start = 0; start + target.length <= said.length; start++) {
      var all = true;
      for (var k = 0; k < target.length; k++) {
        if (said[start + k] != target[k]) {
          all = false;
          break;
        }
      }
      if (!all) continue;
      final article = word.article;
      if (article != null && start > 0) {
        final before = said[start - 1];
        if (const {'der', 'die', 'das'}.contains(before) && before != article) {
          return SpeechMatch.close;
        }
      }
      return SpeechMatch.exact;
    }
    // A near miss on a single word: one letter off is still "close".
    if (target.length == 1) {
      for (final h in said) {
        if (_sameToken(h, target.first)) return SpeechMatch.close;
        if (target.first.length >= 4 && distance(h, target.first) <= 1) {
          return SpeechMatch.close;
        }
      }
    }
    return SpeechMatch.miss;
  }

  @override
  double similarity(String target, String heard) {
    final t = tokens(target);
    final h = tokens(heard);
    if (t.isEmpty || h.isEmpty) return 0;
    var prev = List<int>.filled(h.length + 1, 0);
    for (var i = 1; i <= t.length; i++) {
      final cur = List<int>.filled(h.length + 1, 0);
      for (var j = 1; j <= h.length; j++) {
        cur[j] = _sameToken(t[i - 1], h[j - 1])
            ? prev[j - 1] + 1
            : (prev[j] > cur[j - 1] ? prev[j] : cur[j - 1]);
      }
      prev = cur;
    }
    return prev[h.length] / t.length;
  }
}
