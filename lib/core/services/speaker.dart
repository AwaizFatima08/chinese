import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// Speaks text aloud: the "teacher voice".
abstract class Speaker {
  /// True while an utterance is playing.
  ValueListenable<bool> get speaking;

  /// Prepares the engine for the target language. Returns whether a voice for
  /// [locale] is installed on this device.
  Future<bool> init(String locale);

  /// Whether a voice for the target language was found.
  bool get hasTargetVoice;

  /// Speaks [text] in the target language. [slow] uses a slower rate.
  Future<void> speak(String text, {bool slow = false});

  /// Speaks [text] in English (for meanings and instructions).
  Future<void> speakEnglish(String text);

  /// Speaks [text] with a voice for [locale] (e.g. `en-GB`), whatever the
  /// language the lessons use. [slow] uses a slower rate.
  Future<void> speakIn(String text, String locale, {bool slow = false});

  /// Whether this device has a voice for [locale].
  Future<bool> hasVoiceFor(String locale);

  /// The voice reading [text] as a WAV recording, or null when the engine
  /// cannot write one. Uses the same rate as [speakIn], so it sounds like
  /// what the learner just heard.
  Future<Uint8List?> synthesizeWav(String text, String locale);

  Future<void> stop();
}

/// [Speaker] backed by the device's text-to-speech engine.
class DeviceSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  String _locale = 'zh-CN';
  String? _active;
  bool _ready = false;
  bool _hasVoice = false;
  int _token = 0;

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  bool get hasTargetVoice => _hasVoice;

  @override
  Future<bool> init(String locale) async {
    _locale = locale;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      _hasVoice = await _isAvailable(locale);
      if (!_hasVoice) _hasVoice = await _tryOtherEngines(locale);
      _ready = true;
    } on Object catch (e) {
      debugPrint('TTS init failed: $e');
      _ready = false;
      _hasVoice = false;
    }
    return _hasVoice;
  }

  Future<bool> _isAvailable(String locale) async {
    final available = await _tts.isLanguageAvailable(locale);
    return available == true || available == 1;
  }

  /// The default engine may lack the language (Samsung's often does) while
  /// another installed engine, usually Google's, has it. Try each in turn
  /// and keep the first that can speak [locale].
  Future<bool> _tryOtherEngines(String locale) async {
    final defaultEngine = await _tts.getDefaultEngine as String?;
    final installed =
        [for (final e in await _tts.getEngines as List<dynamic>) '$e']
          ..sort((a, b) {
            // Google's engine first: it has the widest language support.
            int rank(String x) => x == 'com.google.android.tts' ? 0 : 1;
            return rank(a).compareTo(rank(b));
          });
    for (final engine in installed) {
      if (engine == defaultEngine) continue;
      try {
        await _tts.setEngine(engine);
        _active = null;
        await _tts.awaitSpeakCompletion(true);
        final ok = await _isAvailable(locale);
        if (kDebugMode) debugPrint('TTS engine $engine has $locale: $ok');
        if (ok) return true;
      } on Object catch (e) {
        debugPrint('TTS engine $engine failed: $e');
      }
    }
    if (defaultEngine != null) {
      await _tts.setEngine(defaultEngine);
      _active = null;
      await _tts.awaitSpeakCompletion(true);
    }
    return false;
  }

  Future<void> _say(String text, String locale, double rate) async {
    if (!_ready || text.trim().isEmpty) return;
    final token = ++_token;
    try {
      if (_active != locale) {
        await _tts.setLanguage(locale);
        _active = locale;
      }
      await _tts.stop();
      await _tts.setSpeechRate(rate);
      _speaking.value = true;
      // A bounded wait keeps a stuck engine from freezing the lesson.
      final bound = Duration(milliseconds: 2500 + text.length * 350);
      await _tts.speak(text).timeout(bound, onTimeout: () => _tts.stop());
    } on Object catch (e) {
      debugPrint('TTS speak failed: $e');
    } finally {
      if (token == _token) _speaking.value = false;
    }
  }

  @override
  Future<void> speak(String text, {bool slow = false}) =>
      _say(text, _locale, slow ? 0.3 : 0.45);

  @override
  Future<void> speakEnglish(String text) => _say(text, 'en-US', 0.5);

  @override
  Future<void> speakIn(String text, String locale, {bool slow = false}) =>
      _say(text, locale, slow ? 0.3 : 0.45);

  @override
  Future<bool> hasVoiceFor(String locale) async {
    if (!_ready) return false;
    try {
      return await _isAvailable(locale);
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> synthesizeWav(String text, String locale) async {
    if (!_ready || text.trim().isEmpty) return null;
    try {
      final dir = Directory(
        '${(await getTemporaryDirectory()).path}/speak_ref',
      );
      await dir.create(recursive: true);
      final name =
          '${locale}_${text.hashCode.toUnsigned(32).toRadixString(16)}';
      final file = File('${dir.path}/$name.wav');
      if (await file.exists() && await file.length() > 1000) {
        return await file.readAsBytes();
      }
      if (_active != locale) {
        await _tts.setLanguage(locale);
        _active = locale;
      }
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSynthCompletion(true);
      final result = await _tts.synthesizeToFile(text, file.path, true);
      if ((result != 1 && result != true) || !await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.length > 1000 ? bytes : null;
    } on Object catch (e) {
      debugPrint('TTS synthesize failed: $e');
      return null;
    }
  }

  @override
  Future<void> stop() async {
    _token++;
    _speaking.value = false;
    if (!_ready) return;
    try {
      await _tts.stop();
    } on Object catch (_) {
      // Nothing to stop.
    }
  }
}

/// Silent speaker for tests and devices without text-to-speech.
class SilentSpeaker implements Speaker {
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  final List<String> spoken = [];

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  bool get hasTargetVoice => false;

  @override
  Future<bool> init(String locale) async => false;

  @override
  Future<void> speak(String text, {bool slow = false}) async =>
      spoken.add(text);

  @override
  Future<void> speakEnglish(String text) async {}

  @override
  Future<void> speakIn(String text, String locale, {bool slow = false}) async =>
      spoken.add(text);

  @override
  Future<bool> hasVoiceFor(String locale) async => false;

  /// Set by tests that need a model recording.
  Uint8List? wav;

  @override
  Future<Uint8List?> synthesizeWav(String text, String locale) async => wav;

  @override
  Future<void> stop() async {}
}
