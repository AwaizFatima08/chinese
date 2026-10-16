import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/core/util/pinyin.dart';

void main() {
  test('marks tones on the right vowel', () {
    expect(markSyllable('hao3'), 'hǎo');
    expect(markSyllable('liu2'), 'liú');
    expect(markSyllable('gui4'), 'guì');
    expect(markSyllable('lou2'), 'lóu');
    expect(markSyllable('lü4'), 'lǜ');
    expect(markSyllable('ma5'), 'ma');
    expect(markPinyin('ni3 hao3'), 'nǐ hǎo');
  });

  test('detects and strips tones', () {
    expect(toneOfMarked('nǐ'), 3);
    expect(toneOfMarked('ma'), 5);
    expect(toneOfNumeric('shi4'), 4);
    expect(stripTones('Nǐ hǎo'), 'ni hao');
    expect(stripTones('lǜ'), 'lv');
  });

  test('tone variants differ only in tone and never equal the original', () {
    final v = toneVariants('ni3 hao3', seed: 7);
    expect(v, isNotEmpty);
    for (final x in v) {
      expect(x, isNot('ni3 hao3'));
      expect(stripTones(x), 'ni hao');
    }
    expect(toneVariants('ma1').length, 3);
  });

  test('marked form of numeric pinyin matches the data for the vocabulary', () {
    final words =
        jsonDecode(File('assets/content/zh/vocab.json').readAsStringSync())
            as List<dynamic>;
    var checked = 0;
    final bad = <String>[];
    for (final w in words) {
      final n = (w as Map<String, dynamic>)['n'] as String;
      final y = w['y'] as String;
      if (n
          .split(' ')
          .any((s) => !RegExp(r'^[a-zA-Zü:]+[1-5]?$').hasMatch(s))) {
        continue;
      }
      checked++;
      final got = markPinyin(n).toLowerCase().replaceAll(' ', '');
      final want = y.toLowerCase().replaceAll(RegExp(r"[\s']"), '');
      if (got != want) bad.add('${w['s']} $n -> $got (want $want)');
    }
    // ignore: avoid_print
    print('checked $checked, mismatches ${bad.length}: ${bad.take(8)}');
    expect(bad.length / checked, lessThan(0.01));
  });
}
