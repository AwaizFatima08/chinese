import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/core/services/audio_capture.dart';

void main() {
  /// Feeds [levels] as 100 ms chunks; returns the time at which the
  /// endpointer said stop, or null.
  double? stopAt(List<double> levels) {
    final e = Endpointer();
    var t = 0.0;
    for (final l in levels) {
      t += 0.1;
      if (e.add(0.1, l)) return t;
    }
    return null;
  }

  List<double> fill(int n, double v) => List<double>.filled(n, v);

  test('stops about a second after the sentence ends', () {
    final stop = stopAt([
      ...fill(5, 0.01), // room
      ...fill(15, 0.25), // sentence, 1.5 s
      ...fill(30, 0.01), // room again
    ]);
    expect(stop, closeTo(2.0 + 1.1, 0.15));
  });

  test('a noisy room still counts as a pause once speech was louder', () {
    final stop = stopAt([
      ...fill(5, 0.03),
      ...fill(15, 0.3),
      ...fill(40, 0.05), // hum, above 3x the start but far below speech
    ]);
    expect(stop, closeTo(2.0 + 1.1, 0.15));
  });

  test('gives up after six seconds of nothing', () {
    expect(stopAt(fill(80, 0.005)), closeTo(6, 0.15));
  });

  test('a short click does not count as speech', () {
    final stop = stopAt([...fill(5, 0.01), 0.4, ...fill(80, 0.01)]);
    expect(stop, closeTo(6, 0.15));
  });
}
