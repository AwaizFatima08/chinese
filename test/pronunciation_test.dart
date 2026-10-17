import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/features/speak/pronunciation.dart';

void main() {
  test('exact and punctuation-insensitive match', () {
    final s = scoreSpeech(
      'Could you tell me where the station is?',
      'could you tell me where the station is',
    );
    expect(s.perfect, isTrue);
    expect(s.accuracy, 1);
    expect(s.passed, isTrue);
  });

  test('numbers and contractions agree', () {
    expect(
      scoreSpeech('I am 3 minutes late', "I'm three minutes late").perfect,
      isTrue,
    );
    expect(scoreSpeech("I don't know", 'I do not know').perfect, isTrue);
    expect(
      scoreSpeech('It costs 13 pounds', 'it costs thirteen pounds').perfect,
      isTrue,
    );
  });

  test('homophones count as a match', () {
    expect(scoreSpeech('write', 'right').passed, isTrue);
    expect(
      scoreSpeech('Meet me over there', 'meet me over their').perfect,
      isTrue,
    );
  });

  test('a substituted word is marked wrong and named', () {
    final s = scoreSpeech('She sells sea shells', 'she sells see sells');
    final bad = s.problems;
    expect(bad.single.target, 'shells');
    expect(bad.single.heard, 'sells');
    expect(bad.single.mark, WordMark.wrong);
    expect(s.accuracy, closeTo(0.75, 0.01));
  });

  test('a missing word is reported', () {
    final s = scoreSpeech('Thank you for calling', 'thank you calling');
    expect(s.problems.single.target, 'for');
    expect(s.problems.single.mark, WordMark.missing);
  });

  test('extra words cost a little', () {
    final s = scoreSpeech('Good morning', 'well good morning everyone');
    expect(s.extra, ['well', 'everyone']);
    expect(s.accuracy, lessThan(1));
    expect(s.problems, isEmpty);
  });

  test('a near miss in a long sentence is only close', () {
    final s = scoreSpeech(
      'They went to the shops yesterday',
      'they went to the shop yesterday',
    );
    expect(s.words[4].mark, WordMark.close);
    expect(s.passed, isTrue);
  });

  test('single words must be heard exactly: ship is not chip', () {
    expect(scoreSpeech('ship', 'ship').passed, isTrue);
    expect(scoreSpeech('ship', 'chip').passed, isFalse);
    expect(scoreSpeech('sheep', 'ship').passed, isFalse);
    expect(scoreSpeech('think', 'sink').passed, isFalse);
  });

  test('the second choice of the recogniser earns a close', () {
    final s = scoreSpeech('ship', 'chip', alternatives: ['ship', 'shape']);
    expect(s.words.single.mark, WordMark.close);
    expect(s.passed, isTrue);
  });

  test('nothing heard scores zero', () {
    final s = scoreSpeech('Hello there', '');
    expect(s.accuracy, 0);
    expect(s.passed, isFalse);
    expect(s.words.every((w) => w.mark == WordMark.missing), isTrue);
  });

  test('long sentences need 80 percent', () {
    final ok = scoreSpeech('one two three four five', 'one two three four');
    expect(ok.accuracy, closeTo(0.8, 0.01));
    expect(ok.passed, isTrue);
    final bad = scoreSpeech('one two three four five', 'one two three');
    expect(bad.passed, isFalse);
  });
}
