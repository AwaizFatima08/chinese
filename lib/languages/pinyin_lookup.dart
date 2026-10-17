import '../core/util/pinyin.dart';
import 'models.dart';

/// How a spoken attempt compares with the target word.
enum SpeechMatch {
  /// Same word, or a word that sounds identical (tones included).
  exact,

  /// Right syllables but at least one wrong tone (tonal languages).
  toneOff,

  /// Nearly right: a letter off, or the wrong article (German).
  close,

  /// Something else.
  miss,
}

/// Maps Chinese text to numeric pinyin using the HSK vocabulary, so a spoken
/// answer can be judged by sound instead of by exact characters.
class PinyinLookup {
  PinyinLookup(Iterable<Word> words) {
    for (final w in words) {
      _byText.putIfAbsent(w.text, () => w.romanizationNumeric);
      if (w.text.runes.length > _maxLength) _maxLength = w.text.runes.length;
    }
  }

  final Map<String, String> _byText = {};
  int _maxLength = 1;

  static final RegExp _han = RegExp(r'[一-鿿]');

  /// Numeric pinyin of [text], or null when any character is unknown.
  String? numericOf(String text) {
    final chars = text.runes
        .map(String.fromCharCode)
        .where(_han.hasMatch)
        .toList();
    if (chars.isEmpty) return null;
    final out = <String>[];
    var i = 0;
    while (i < chars.length) {
      String? found;
      var len = 0;
      for (
        var n = (_maxLength < chars.length - i ? _maxLength : chars.length - i);
        n >= 1;
        n--
      ) {
        final candidate = chars.sublist(i, i + n).join();
        final hit = _byText[candidate];
        if (hit != null) {
          found = hit;
          len = n;
          break;
        }
      }
      if (found == null) return null;
      out.add(found);
      i += len;
    }
    return out.join(' ');
  }

  /// Splits Chinese [text] into dictionary words (longest match first),
  /// dropping punctuation. Unknown characters become single-character tokens.
  List<String> segment(String text) {
    final chars = text.runes.map(String.fromCharCode).toList();
    final out = <String>[];
    var i = 0;
    while (i < chars.length) {
      if (!_han.hasMatch(chars[i])) {
        i++;
        continue;
      }
      var len = 1;
      for (
        var n = (_maxLength < chars.length - i ? _maxLength : chars.length - i);
        n > 1;
        n--
      ) {
        final slice = chars.sublist(i, i + n);
        if (slice.every(_han.hasMatch) && _byText.containsKey(slice.join())) {
          len = n;
          break;
        }
      }
      out.add(chars.sublist(i, i + len).join());
      i += len;
    }
    return out;
  }

  /// How much of [target] was said, from 0 to 1, judged by sound (tones
  /// ignored) so homophones and recogniser spelling quirks still count.
  double similarity(String target, String heard) {
    final t = _toneless(target);
    final h = _toneless(heard);
    if (t.isEmpty || h.isEmpty) return 0;
    // Longest common subsequence of syllables.
    final prev = List<int>.filled(h.length + 1, 0);
    final cur = List<int>.filled(h.length + 1, 0);
    for (var i = 1; i <= t.length; i++) {
      for (var j = 1; j <= h.length; j++) {
        cur[j] = t[i - 1] == h[j - 1]
            ? prev[j - 1] + 1
            : (prev[j] > cur[j - 1] ? prev[j] : cur[j - 1]);
      }
      for (var j = 0; j <= h.length; j++) {
        prev[j] = cur[j];
      }
    }
    return prev[h.length] / t.length;
  }

  List<String> _toneless(String text) {
    final out = <String>[];
    for (final tok in segment(text)) {
      final n = _byText[tok];
      if (n != null) {
        out.addAll(syllables(n).map(stripTones));
      } else {
        out.add(tok);
      }
    }
    return out;
  }

  /// Judges what the recogniser heard against the target word.
  SpeechMatch match({
    required String target,
    required String targetNumeric,
    required String heard,
  }) {
    final cleaned = heard.replaceAll(RegExp(r'[^一-鿿]'), '');
    if (cleaned.isEmpty) return SpeechMatch.miss;
    if (cleaned == target || cleaned.contains(target)) return SpeechMatch.exact;
    final heardNumeric = numericOf(cleaned);
    if (heardNumeric == null) return SpeechMatch.miss;
    final t = syllables(targetNumeric);
    final h = syllables(heardNumeric);
    // Allow extra syllables the recogniser appended ("你好吗" for "你好").
    for (var start = 0; start + t.length <= h.length; start++) {
      final window = h.sublist(start, start + t.length);
      var same = true;
      var toneless = true;
      for (var k = 0; k < t.length; k++) {
        if (window[k] != t[k]) same = false;
        if (stripTones(window[k]) != stripTones(t[k])) toneless = false;
      }
      if (same) return SpeechMatch.exact;
      if (toneless) return SpeechMatch.toneOff;
    }
    return SpeechMatch.miss;
  }
}
