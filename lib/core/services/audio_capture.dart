import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../util/pcm.dart';

/// Decides when someone has finished a sentence: speech was heard and then
/// there was silence for [endSilence]; or nothing was said for [startWait].
class Endpointer {
  Endpointer({
    this.endSilence = const Duration(milliseconds: 1100),
    this.startWait = const Duration(seconds: 6),
  });

  final Duration endSilence;
  final Duration startWait;

  double _time = 0;
  double _floor = double.infinity;
  double _speechFor = 0;
  double _silentFor = 0;
  bool _started = false;

  bool get started => _started;

  /// Quietest loudness in the first moments: the room's background noise.
  double get floor => _floor;

  /// Feeds [seconds] of audio with loudness [rms]. True when recording
  /// should stop.
  bool add(double seconds, double rms) {
    _time += seconds;
    if (_time < 0.4) {
      _floor = math.min(_floor, rms);
      return false;
    }
    final threshold = math.max(0.015, _floor * 3);
    if (rms >= threshold) {
      _speechFor += seconds;
      _silentFor = 0;
      if (_speechFor >= 0.15) _started = true;
    } else {
      _silentFor += seconds;
      if (!_started) _speechFor = 0;
    }
    if (_started && _silentFor >= endSilence.inMilliseconds / 1000) return true;
    return !_started && _time >= startWait.inMilliseconds / 1000;
  }
}

/// Records the learner's voice for analysis (not for recognition).
abstract class AudioCapture {
  /// Asks for the microphone if needed. Returns whether recording can work.
  Future<bool> init();

  /// Records one sentence, stopping when the learner finishes or after
  /// [maxLength]. [onLevel] reports loudness 0..1 for a meter. Returns null if
  /// recording could not start.
  Future<Pcm?> capture({
    Duration maxLength = const Duration(seconds: 10),
    void Function(double level)? onLevel,
  });

  /// Stops recording right away.
  Future<void> cancel();
}

/// [AudioCapture] backed by the microphone.
class DeviceAudioCapture implements AudioCapture {
  AudioRecorder? _recorder;
  Completer<void>? _stop;

  static const sampleRate = 16000;

  @override
  Future<bool> init() async {
    try {
      _recorder ??= AudioRecorder();
      return await _recorder!.hasPermission();
    } on Object catch (e) {
      debugPrint('Audio capture init failed: $e');
      return false;
    }
  }

  @override
  Future<Pcm?> capture({
    Duration maxLength = const Duration(seconds: 10),
    void Function(double level)? onLevel,
  }) async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final bytes = BytesBuilder(copy: false);
    final endpoint = Endpointer();
    final trace = <double>[];
    var traceSum = 0.0;
    var traceN = 0;
    final done = Completer<void>();
    _stop = done;
    StreamSubscription<Uint8List>? sub;
    try {
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      sub = stream.listen(
        (chunk) {
          bytes.add(chunk);
          final level = _rms(chunk);
          if (kDebugMode) {
            traceSum += level;
            if (++traceN == 10) {
              trace.add(traceSum / 10);
              traceSum = 0;
              traceN = 0;
            }
          }
          onLevel?.call((level * 6).clamp(0, 1));
          final seconds = chunk.length / 2 / sampleRate;
          if (endpoint.add(seconds, level) && !done.isCompleted) {
            done.complete();
          }
        },
        onError: (Object e) {
          debugPrint('Audio capture error: $e');
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(maxLength, onTimeout: () {});
    } on Object catch (e) {
      debugPrint('Audio capture failed: $e');
      return null;
    } finally {
      await sub?.cancel();
      try {
        await recorder.stop();
      } on Object catch (_) {
        // Already stopped.
      }
      _stop = null;
    }
    final all = bytes.takeBytes();
    if (kDebugMode) {
      debugPrint(
        'CAPTURE ${(all.length / 2 / sampleRate).toStringAsFixed(1)} s, '
        'floor=${endpoint.floor.toStringAsFixed(4)} started=${endpoint.started} '
        'levels=${trace.map((v) => v.toStringAsFixed(3)).join(' ')}',
      );
    }
    return all.length < sampleRate ~/ 2 ? null : Pcm.fromPcm16(all, sampleRate);
  }

  static double _rms(Uint8List chunk) {
    final data = ByteData.sublistView(chunk);
    final n = chunk.length ~/ 2;
    if (n == 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768;
      sum += v * v;
    }
    return math.sqrt(sum / n);
  }

  @override
  Future<void> cancel() async {
    final stop = _stop;
    if (stop != null && !stop.isCompleted) stop.complete();
  }
}

/// Capture for tests: hands back scripted recordings.
class ScriptedCapture implements AudioCapture {
  ScriptedCapture({this.allowed = true, List<Pcm?>? script})
    : _script = [...?script];

  final bool allowed;
  final List<Pcm?> _script;

  @override
  Future<bool> init() async => allowed;

  @override
  Future<Pcm?> capture({
    Duration maxLength = const Duration(seconds: 10),
    void Function(double level)? onLevel,
  }) async => _script.isEmpty ? null : _script.removeAt(0);

  @override
  Future<void> cancel() async {}
}
