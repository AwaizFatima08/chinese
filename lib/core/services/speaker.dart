import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
      final available = await _tts.isLanguageAvailable(locale);
      _hasVoice = available == true || available == 1;
      if (kDebugMode) {
        final engine = await _tts.getDefaultEngine;
        final langs = await _tts.getLanguages;
        debugPrint(
          'TTS engine=$engine locale=$locale available=$available '
          'zh-voices=${(langs as List<dynamic>).where((l) => '$l'.toLowerCase().startsWith('zh')).toList()}',
        );
      }
      await _tts.setVolume(1);
      await _tts.setPitch(1);
      _ready = true;
    } on Object catch (e) {
      debugPrint('TTS init failed: $e');
      _ready = false;
      _hasVoice = false;
    }
    return _hasVoice;
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
  Future<void> stop() async {}
}
