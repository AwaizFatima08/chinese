import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lingodaily/core/util/pcm.dart';

/// A synthetic voice: harmonics at a pitch that follows [semitones] (offset
/// from [base] Hz over u = 0..1) and a loudness made of [syllables] pulses.
Pcm voice({
  required double seconds,
  double base = 120,
  double Function(double u)? semitones,
  int syllables = 6,
  int rate = 16000,
  double noise = 0,
  int seed = 1,
}) {
  final random = math.Random(seed);
  final n = (seconds * rate).round();
  final out = Float64List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final u = i / n;
    final f = base * math.pow(2, (semitones?.call(u) ?? 0) / 12);
    phase += 2 * math.pi * f / rate;
    var s = 0.0;
    for (var h = 1; h <= 8; h++) {
      s += math.sin(h * phase) / h;
    }
    final slot = u * syllables;
    final inSlot = slot - slot.floor();
    final env = inSlot < 0.8 ? math.sin(math.pi * inSlot / 0.8) : 0.0;
    out[i] =
        0.3 * s * env + (noise > 0 ? (random.nextDouble() - 0.5) * noise : 0);
  }
  return Pcm(out, rate);
}

double riseFall(double u) => 5 * math.sin(math.pi * u);
double fallRise(double u) => -5 * math.sin(math.pi * u);
double flat(double u) => 0;
double question(double u) => u < 0.7 ? 0 : 8 * (u - 0.7) / 0.3;

/// [pcm] as a 16-bit mono WAV file.
Uint8List wavBytes(Pcm pcm) {
  final n = pcm.samples.length;
  final data = ByteData(44 + n * 2);
  void tag(int at, String t) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(at + i, t.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, pcm.rate, Endian.little);
  data.setUint32(28, pcm.rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(
      44 + i * 2,
      (pcm.samples[i].clamp(-1, 1) * 32767).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}
