import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/languages/language_content.dart';
import 'package:lingodaily/languages/pinyin_lookup.dart';

import 'helpers/file_bundle.dart';

void main() {
  late LanguageContent content;
  late PinyinLookup lookup;

  setUpAll(() async {
    content = await LanguageContent.load('zh', bundle: FileAssetBundle());
    lookup = PinyinLookup(content.words.values);
  });

  String numeric(String hanzi) =>
      content.wordByText(hanzi)!.romanizationNumeric;

  group('word match', () {
    test('the exact word is recognised', () {
      expect(
        lookup.match(target: '学生', targetNumeric: numeric('学生'), heard: '学生'),
        SpeechMatch.exact,
      );
    });

    test('extra words the recogniser adds do not matter', () {
      expect(
        lookup.match(target: '学生', targetNumeric: numeric('学生'), heard: '学生们'),
        SpeechMatch.exact,
      );
    });

    test('a homophone with the same tones counts as right', () {
      // 他 and 她 are both tā.
      expect(
        lookup.match(target: '他', targetNumeric: numeric('他'), heard: '她'),
        SpeechMatch.exact,
      );
    });

    test('same syllable in another tone is called out as a tone error', () {
      // 吗 (má) heard as 马 (mǎ).
      final ma = content.wordByText('吗')!;
      final r = lookup.match(
        target: ma.text,
        targetNumeric: ma.romanizationNumeric,
        heard: '马',
      );
      expect(r, SpeechMatch.toneOff);
    });

    test('a different word is a miss; silence and Latin text are misses', () {
      expect(
        lookup.match(target: '学生', targetNumeric: numeric('学生'), heard: '谢谢'),
        SpeechMatch.miss,
      );
      expect(
        lookup.match(target: '学生', targetNumeric: numeric('学生'), heard: ''),
        SpeechMatch.miss,
      );
      expect(
        lookup.match(
          target: '学生',
          targetNumeric: numeric('学生'),
          heard: 'hello',
        ),
        SpeechMatch.miss,
      );
    });
  });

  group('sentence similarity', () {
    test('identical and homophone sentences score 1', () {
      expect(lookup.similarity('我爱你', '我爱你'), 1);
      expect(lookup.similarity('他是学生', '她是学生'), 1);
    });

    test('partial attempts score in between', () {
      final s = lookup.similarity('我是学生', '我是老师');
      expect(s, greaterThan(0.3));
      expect(s, lessThan(1));
    });

    test('unrelated or empty speech scores near zero', () {
      expect(lookup.similarity('我是学生', '今天天气很好'), lessThan(0.4));
      expect(lookup.similarity('我是学生', ''), 0);
    });
  });

  group('segmentation and pinyin', () {
    test('splits into dictionary words and drops punctuation', () {
      expect(lookup.segment('我是学生。'), ['我', '是', '学生']);
      expect(lookup.segment('你好！'), ['你', '好']);
    });

    test('numericOf joins word readings', () {
      expect(lookup.numericOf('你好'), 'ni3 hao3');
      expect(lookup.numericOf('学生'), 'xue2 sheng5');
      expect(lookup.numericOf('abc'), isNull);
    });
  });
}
