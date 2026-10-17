import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/languages/language_content.dart';
import 'package:lingodaily/languages/language_tools.dart';
import 'package:lingodaily/languages/models.dart';
import 'package:lingodaily/languages/pinyin_lookup.dart';

import 'helpers/file_bundle.dart';

void main() {
  late LanguageContent content;
  late LanguageTools tools;

  Word word(String text) => content.allWords.firstWhere((w) => w.text == text);

  setUpAll(() async {
    content = await LanguageContent.load('de', bundle: FileAssetBundle());
    tools = LanguageTools.forPack(content.pack, content.words.values);
  });

  group('matching a spoken word', () {
    test('the right noun is accepted with or without its article', () {
      final haus = word('das Haus');
      expect(tools.matchWord(word: haus, heard: 'das Haus'), SpeechMatch.exact);
      expect(tools.matchWord(word: haus, heard: 'Haus'), SpeechMatch.exact);
      expect(
        tools.matchWord(word: haus, heard: 'Das Haus ist groß'),
        SpeechMatch.exact,
      );
    });

    test('the wrong article is called out as close', () {
      final haus = word('das Haus');
      expect(tools.matchWord(word: haus, heard: 'der Haus'), SpeechMatch.close);
      expect(tools.matchWord(word: haus, heard: 'die Haus'), SpeechMatch.close);
    });

    test('a different word is a miss; one letter off is close', () {
      final haus = word('das Haus');
      expect(tools.matchWord(word: haus, heard: 'der Tisch'), SpeechMatch.miss);
      expect(tools.matchWord(word: haus, heard: ''), SpeechMatch.miss);
      final bahnhof = word('der Bahnhof');
      expect(
        tools.matchWord(word: bahnhof, heard: 'Bahnhoff'),
        SpeechMatch.close,
      );
    });

    test('ß, umlauts and digits are normalised', () {
      final strasse = content.allWords.firstWhere((w) => w.lemma == 'Straße');
      expect(
        tools.matchWord(word: strasse, heard: 'die Strasse'),
        SpeechMatch.exact,
      );
      final zwei = content.allWords.firstWhere((w) => w.text == 'zwei');
      expect(tools.matchWord(word: zwei, heard: '2'), SpeechMatch.exact);
    });
  });

  group('sentences', () {
    test('similarity is by words and forgives a letter on long words', () {
      expect(tools.similarity('Ich lerne Deutsch.', 'ich lerne deutsch'), 1);
      expect(
        tools.similarity('Wir wohnen in Berlin', 'wir wohnen in Hamburg'),
        closeTo(0.75, 0.01),
      );
      expect(tools.similarity('Ich lerne Deutsch', ''), 0);
      expect(
        tools.similarity('Das Wetter ist schön', 'das Wetter ist schon'),
        greaterThanOrEqualTo(0.75),
      );
    });

    test('tiles drop punctuation and lower an opening function word', () {
      expect(tools.segment('Ich lerne heute Deutsch.'), [
        'ich',
        'lerne',
        'heute',
        'Deutsch',
      ]);
      expect(tools.segment('Der Mann, der dort steht, ist mein Lehrer.'), [
        'der',
        'Mann',
        'der',
        'dort',
        'steht',
        'ist',
        'mein',
        'Lehrer',
      ]);
      expect(tools.segment('„Hallo!“, sagte sie.'), ['Hallo', 'sagte', 'sie']);
    });

    test('German tiles carry no romanization', () {
      expect(tools.romanizeTile('Haus'), isNull);
    });
  });
}
