import 'dart:math' as math;
import 'dart:typed_data';

/// Mono audio as floating-point samples in -1..1.
class Pcm {
  Pcm(this.samples, this.rate);

  final Float64List samples;
  final int rate;

  double get seconds => rate == 0 ? 0 : samples.length / rate;

  /// 16-bit little-endian mono samples.
  factory Pcm.fromPcm16(Uint8List bytes, int rate) {
    final data = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768;
    }
    return Pcm(out, rate);
  }

  /// Reads a RIFF/WAVE file (PCM 16-bit, any channel count, mixed down to
  /// mono). Returns null for anything else.
  static Pcm? fromWav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final data = ByteData.sublistView(bytes);
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
    var pos = 12;
    int? rate;
    int channels = 1;
    int bits = 16;
    int format = 1;
    while (pos + 8 <= bytes.length) {
      final id = tag(pos);
      var size = data.getUint32(pos + 4, Endian.little);
      final body = pos + 8;
      if (id == 'fmt ' && body + 16 <= bytes.length) {
        format = data.getUint16(body, Endian.little);
        channels = data.getUint16(body + 2, Endian.little);
        rate = data.getUint32(body + 4, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        if (rate == null || bits != 16 || channels < 1) return null;
        if (format != 1 && format != 0xFFFE) return null;
        // Streaming writers leave the size as 0 or 0xFFFFFFFF.
        if (size == 0 || body + size > bytes.length) size = bytes.length - body;
        final frames = size ~/ (2 * channels);
        final out = Float64List(frames);
        for (var i = 0; i < frames; i++) {
          var sum = 0;
          for (var c = 0; c < channels; c++) {
            sum += data.getInt16(body + (i * channels + c) * 2, Endian.little);
          }
          out[i] = sum / channels / 32768;
        }
        return Pcm(out, rate);
      }
      pos = body + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  /// This audio at [target] samples per second (box filter when shrinking).
  Pcm resampled(int target) {
    if (target == rate || samples.isEmpty) return this;
    final ratio = rate / target;
    final n = (samples.length / ratio).floor();
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      final from = i * ratio;
      final to = math.min((i + 1) * ratio, samples.length.toDouble());
      if (ratio <= 1) {
        final j = from.floor();
        final f = from - j;
        final a = samples[j];
        final b = j + 1 < samples.length ? samples[j + 1] : a;
        out[i] = a + (b - a) * f;
      } else {
        var sum = 0.0;
        var count = 0;
        for (var j = from.floor(); j < to.ceil() && j < samples.length; j++) {
          sum += samples[j];
          count++;
        }
        out[i] = count == 0 ? 0 : sum / count;
      }
    }
    return Pcm(out, target);
  }
}
