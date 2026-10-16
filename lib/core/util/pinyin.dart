/// Helpers for Mandarin pinyin: tone marks, tone detection and tone drills.
library;

const _marks = <String, List<String>>{
  'a': ['ā', 'á', 'ǎ', 'à'],
  'e': ['ē', 'é', 'ě', 'è'],
  'i': ['ī', 'í', 'ǐ', 'ì'],
  'o': ['ō', 'ó', 'ǒ', 'ò'],
  'u': ['ū', 'ú', 'ǔ', 'ù'],
  'ü': ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
};

final Map<String, ({String base, int tone})> _toneOfChar = {
  for (final e in _marks.entries)
    for (var i = 0; i < 4; i++) e.value[i]: (base: e.key, tone: i + 1),
};

final RegExp _numericSyllable = RegExp(r'^([a-zA-Zü:]+?)([1-5])?$');

/// Converts one numeric syllable (`hao3`, `lü4`, `nu:3`) to tone-marked form.
/// Unknown shapes are returned unchanged.
String markSyllable(String numeric) {
  final m = _numericSyllable.firstMatch(numeric);
  if (m == null) return numeric;
  final base = m.group(1)!.replaceAll('u:', 'ü').replaceAll('U:', 'Ü');
  final tone = int.tryParse(m.group(2) ?? '') ?? 5;
  if (tone == 5) return base;
  final lower = base.toLowerCase();
  var index = lower.indexOf('a');
  if (index < 0) index = lower.indexOf('e');
  if (index < 0 && lower.contains('ou')) index = lower.indexOf('o');
  if (index < 0) {
    // Otherwise the mark sits on the last vowel.
    index = lower.lastIndexOf(RegExp('[aeiouü]'));
  }
  if (index < 0) return base;
  final marked = _marks[lower[index]]![tone - 1];
  final isUpper = base[index] != lower[index];
  return base.substring(0, index) +
      (isUpper ? marked.toUpperCase() : marked) +
      base.substring(index + 1);
}

/// Converts a space separated numeric pinyin string to tone-marked pinyin.
String markPinyin(String numeric) =>
    numeric.split(' ').map(markSyllable).join(' ');

/// Tone of a tone-marked syllable: 1-4, or 5 for neutral/unmarked.
int toneOfMarked(String syllable) {
  for (final rune in syllable.runes) {
    final hit = _toneOfChar[String.fromCharCode(rune).toLowerCase()];
    if (hit != null) return hit.tone;
  }
  return 5;
}

/// Tone of a numeric syllable (`hao3` -> 3); 5 when none is given.
int toneOfNumeric(String syllable) {
  final m = _numericSyllable.firstMatch(syllable);
  return int.tryParse(m?.group(2) ?? '') ?? 5;
}

/// Removes tone marks and digits: `Nǐ hǎo` -> `ni hao`, `lǜ` -> `lv`.
String stripTones(String s) {
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final hit = _toneOfChar[ch.toLowerCase()];
    if (hit != null) {
      buf.write(hit.base == 'ü' ? 'v' : hit.base);
    } else if (ch == 'ü' || ch == 'Ü') {
      buf.write('v');
    } else if (!RegExp('[1-5]').hasMatch(ch)) {
      buf.write(ch.toLowerCase());
    }
  }
  return buf.toString().replaceAll('u:', 'v');
}

/// Splits a pinyin string into syllables on spaces.
List<String> syllables(String pinyin) =>
    pinyin.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

/// Replaces the tone of one numeric syllable.
String withTone(String numericSyllable, int tone) {
  final m = _numericSyllable.firstMatch(numericSyllable);
  if (m == null) return numericSyllable;
  return '${m.group(1)}$tone';
}

/// Wrong-but-plausible neighbours of [numeric] that differ only in tone,
/// for "which one did you hear?" drills. Deterministic for a given [seed].
List<String> toneVariants(String numeric, {int count = 3, int seed = 0}) {
  final sylls = syllables(numeric);
  if (sylls.isEmpty || sylls.any((s) => !_numericSyllable.hasMatch(s))) {
    return const [];
  }
  final out = <String>{};
  final tones = [1, 2, 3, 4];
  // Syllables with no vowel (the erhua "r") look the same in every tone.
  final changeable = [
    for (var i = 0; i < sylls.length; i++)
      if (RegExp('[aeiouü]').hasMatch(sylls[i].toLowerCase())) i,
  ];
  if (changeable.isEmpty) return const [];
  if (sylls.length == 1) {
    final original = toneOfNumeric(sylls.first);
    for (final t in tones) {
      if (t != original) out.add(withTone(sylls.first, t));
    }
  } else {
    var s = seed.abs();
    int next(int n) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s % n;
    }

    var guard = 0;
    while (out.length < count && guard++ < 60) {
      final copy = [...sylls];
      final i = changeable[next(changeable.length)];
      final original = toneOfNumeric(copy[i]);
      final candidates = tones.where((t) => t != original).toList();
      copy[i] = withTone(copy[i], candidates[next(candidates.length)]);
      if (changeable.length > 2 && next(2) == 0) {
        final j = changeable[(changeable.indexOf(i) + 1) % changeable.length];
        final o2 = toneOfNumeric(copy[j]);
        final c2 = tones.where((t) => t != o2).toList();
        copy[j] = withTone(copy[j], c2[next(c2.length)]);
      }
      final variant = copy.join(' ');
      if (variant != numeric) out.add(variant);
    }
  }
  // Distinct as displayed, not just as digits.
  final seen = <String>{markPinyin(numeric)};
  return [
    for (final v in out)
      if (seen.add(markPinyin(v))) v,
  ].take(count).toList();
}
