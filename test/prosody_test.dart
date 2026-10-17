import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/core/util/pcm.dart';
import 'package:lingodaily/features/speak/prosody.dart';

import 'helpers/synthetic_voice.dart';

MelodyScore score(Pcm ref, Pcm learner) =>
    compareProsody(extractProsody(ref), extractProsody(learner));

void main() {
  final ref = voice(seconds: 2, semitones: riseFall);

  test('the same melody at a much higher voice passes', () {
    final s = score(ref, voice(seconds: 2, base: 220, semitones: riseFall));
    expect(s.issue, MelodyIssue.none, reason: '${s.melody} ${s.rhythm}');
    expect(s.melody, greaterThan(0.8));
    expect(s.accuracy, greaterThan(0.8));
  });

  test('the same melody a little slower and with noise passes', () {
    final s = score(
      ref,
      voice(seconds: 2.5, base: 140, semitones: riseFall, noise: 0.02, seed: 3),
    );
    expect(
      s.issue,
      MelodyIssue.none,
      reason: '${s.melody} ${s.rhythm} ${s.pace}',
    );
  });

  test('a mirrored melody is caught', () {
    final s = score(ref, voice(seconds: 2, semitones: fallRise));
    expect(s.passed, isFalse);
    expect(s.issue, MelodyIssue.melody, reason: '${s.melody}');
  });

  test('a monotone voice is called flat', () {
    final s = score(ref, voice(seconds: 2, semitones: flat));
    expect(s.issue, MelodyIssue.flat, reason: '${s.rangeRatio}');
  });

  test('a rising question tone differs from a statement', () {
    final statement = voice(seconds: 2, semitones: (u) => -4 * u);
    final s = score(statement, voice(seconds: 2, semitones: question));
    expect(s.passed, isFalse);
  });

  test('pace far from the model is reported', () {
    expect(
      score(ref, voice(seconds: 4, semitones: riseFall)).issue,
      MelodyIssue.tooSlow,
    );
    expect(
      score(ref, voice(seconds: 1, semitones: riseFall)).issue,
      MelodyIssue.tooFast,
    );
  });

  test('a different beat of syllables fails on rhythm', () {
    final s = score(ref, voice(seconds: 2, semitones: riseFall, syllables: 3));
    expect(s.issue, MelodyIssue.rhythm, reason: '${s.rhythm}');
  });

  test('small differences in timing are forgiven', () {
    final warped = voice(
      seconds: 2.2,
      semitones: (u) => riseFall(u + 0.05 * math.sin(2 * math.pi * u)),
    );
    expect(score(ref, warped).issue, MelodyIssue.none);
    final late = voice(
      seconds: 2,
      semitones: (u) => riseFall((u * 1.15).clamp(0, 1)),
    );
    expect(score(ref, late).issue, MelodyIssue.none);
  });

  test('room noise and a click around the sentence are ignored', () {
    final speech = voice(seconds: 2, base: 150, semitones: riseFall);
    final r = math.Random(5);
    List<double> hiss(int n, double a) => [
      for (var i = 0; i < n; i++) (r.nextDouble() - 0.5) * a,
    ];
    final all = [
      ...hiss(16000 * 2, 0.01), // two seconds of room noise
      ...hiss(800, 0.6), // a click
      ...hiss(16000, 0.01),
      ...speech.samples.map((v) => v + (r.nextDouble() - 0.5) * 0.01),
      ...hiss(16000 * 3, 0.01),
    ];
    final s = score(ref, Pcm(Float64List.fromList(all), 16000));
    expect(s.pace, closeTo(1, 0.25), reason: '${s.pace}');
    expect(s.issue, MelodyIssue.none, reason: '${s.melody} ${s.rhythm}');
  });

  test('silence and noise are not a voice', () {
    final quiet = Pcm(Float64List(16000 * 2), 16000);
    expect(score(ref, quiet).issue, MelodyIssue.noVoice);
    final r = math.Random(2);
    final noise = Pcm(
      Float64List.fromList([
        for (var i = 0; i < 32000; i++) (r.nextDouble() - 0.5) * 0.2,
      ]),
      16000,
    );
    expect(score(ref, noise).passed, isFalse);
  });

  group('audio helpers', () {
    test('a 16-bit WAV file is read, stereo mixed down', () {
      final bytes = BytesBuilder();
      void u32(int v) => bytes.add(
        (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
      );
      void u16(int v) => bytes.add(
        (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
      );
      bytes.add('RIFF'.codeUnits);
      u32(36 + 8);
      bytes.add('WAVEfmt '.codeUnits);
      u32(16);
      u16(1);
      u16(2);
      u32(24000);
      u32(24000 * 4);
      u16(4);
      u16(16);
      bytes.add('data'.codeUnits);
      u32(8);
      for (final v in [1000, 3000, -2000, -2000]) {
        bytes.add(
          (ByteData(2)..setInt16(0, v, Endian.little)).buffer.asUint8List(),
        );
      }
      final pcm = Pcm.fromWav(bytes.toBytes())!;
      expect(pcm.rate, 24000);
      expect(pcm.samples.length, 2);
      expect(pcm.samples[0] * 32768, closeTo(2000, 1));
      expect(pcm.samples[1] * 32768, closeTo(-2000, 1));
      expect(Pcm.fromWav(Uint8List(10)), isNull);
    });

    test('resampling keeps the duration', () {
      final p = voice(seconds: 1, rate: 24000);
      expect(p.resampled(8000).seconds, closeTo(1, 0.01));
    });
  });
}
