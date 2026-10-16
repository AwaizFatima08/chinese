import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/features/writing/stroke_matcher.dart';

void main() {
  // A horizontal stroke left to right across the middle of the box.
  const median = [Offset(200, 500), Offset(500, 500), Offset(800, 500)];

  test('accepts a close, correctly directed stroke', () {
    const drawn = [Offset(230, 520), Offset(500, 490), Offset(780, 505)];
    expect(StrokeMatcher.matches(drawn, median), isTrue);
  });

  test('rejects the stroke drawn backwards', () {
    const drawn = [Offset(780, 505), Offset(500, 490), Offset(230, 520)];
    expect(StrokeMatcher.matches(drawn, median), isFalse);
  });

  test('rejects a stroke in the wrong place', () {
    const drawn = [Offset(230, 100), Offset(500, 90), Offset(780, 105)];
    expect(StrokeMatcher.matches(drawn, median), isFalse);
  });

  test('rejects a stroke at the right ends but the wrong shape', () {
    const drawn = [Offset(200, 500), Offset(500, 900), Offset(800, 500)];
    expect(StrokeMatcher.matches(drawn, median), isFalse);
  });

  test('rejects a tiny accidental touch', () {
    const drawn = [Offset(300, 500), Offset(310, 502)];
    expect(StrokeMatcher.matches(drawn, median), isFalse);
  });

  test('a dot is accepted near its place', () {
    const dot = [Offset(500, 300), Offset(540, 360)];
    const drawn = [Offset(480, 290), Offset(525, 370)];
    expect(StrokeMatcher.matches(drawn, dot), isTrue);
  });

  test('length and pointAt agree', () {
    expect(StrokeMatcher.length(median), 600);
    expect(StrokeMatcher.pointAt(median, 0.5), const Offset(500, 500));
    expect(StrokeMatcher.resample(median, 5).length, 5);
  });
}
