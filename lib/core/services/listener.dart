import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why a listening attempt produced no text.
enum ListenFailure { unavailable, noSpeech, error }

/// Result of one listening attempt.
@immutable
class ListenResult {
  const ListenResult.heard(
    this.text, {
    this.confidence = 0,
    this.alternatives = const [],
  }) : failure = null;
  const ListenResult.failed(this.failure)
    : text = '',
      confidence = 0,
      alternatives = const [];

  final String text;

  /// The recogniser's own confidence, 0..1, or 0 when it did not give one.
  final double confidence;

  /// Other transcriptions the recogniser considered, best first (excluding
  /// [text]).
  final List<String> alternatives;
  final ListenFailure? failure;
  bool get ok => failure == null;
}

/// Turns the learner's voice into text (speech recognition).
abstract class VoiceListener {
  /// Prepares recognition for [locale] (e.g. `zh_CN`). Returns availability.
  Future<bool> init(String locale);

  bool get available;

  /// Listens until the learner stops talking or [limit] elapses.
  Future<ListenResult> listenOnce({
    Duration limit = const Duration(seconds: 6),
    void Function(String partial)? onPartial,
  });

  /// Stops listening right away.
  Future<void> cancel();
}

/// [VoiceListener] backed by the platform recogniser.
class DeviceVoiceListener implements VoiceListener {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  String _localeId = 'zh_CN';
  Completer<ListenResult>? _pending;
  String _last = '';
  double _confidence = 0;
  List<String> _alternatives = const [];

  ListenResult _heard() => ListenResult.heard(
    _last,
    confidence: _confidence,
    alternatives: _alternatives,
  );

  @override
  bool get available => _available;

  @override
  Future<bool> init(String locale) async {
    try {
      _available = await _stt.initialize(
        onError: (e) {
          debugPrint('STT error: ${e.errorMsg}');
          _finish(
            _last.isNotEmpty
                ? _heard()
                : const ListenResult.failed(ListenFailure.noSpeech),
          );
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _finish(
              _last.isNotEmpty
                  ? _heard()
                  : const ListenResult.failed(ListenFailure.noSpeech),
            );
          }
        },
      );
      if (_available) {
        final locales = await _stt.locales();
        final wanted = locale.replaceAll('-', '_').toLowerCase();
        for (final l in locales) {
          if (l.localeId.replaceAll('-', '_').toLowerCase() == wanted) {
            _localeId = l.localeId;
            break;
          }
        }
      }
    } on Object catch (e) {
      debugPrint('STT init failed: $e');
      _available = false;
    }
    return _available;
  }

  void _finish(ListenResult r) {
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete(r);
  }

  @override
  Future<ListenResult> listenOnce({
    Duration limit = const Duration(seconds: 6),
    void Function(String partial)? onPartial,
  }) async {
    if (!_available) {
      return const ListenResult.failed(ListenFailure.unavailable);
    }
    await cancel();
    _last = '';
    _confidence = 0;
    _alternatives = const [];
    final completer = _pending = Completer<ListenResult>();
    try {
      await _stt.listen(
        onResult: (r) {
          _last = r.recognizedWords;
          if (r.hasConfidenceRating) _confidence = r.confidence;
          _alternatives = [
            for (final a in r.alternates.skip(1))
              if (a.recognizedWords.isNotEmpty) a.recognizedWords,
          ];
          onPartial?.call(_last);
          if (r.finalResult) {
            _finish(
              _last.isEmpty
                  ? const ListenResult.failed(ListenFailure.noSpeech)
                  : _heard(),
            );
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: limit,
          pauseFor: const Duration(seconds: 2),
          localeId: _localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } on Object catch (e) {
      debugPrint('STT listen failed: $e');
      _finish(const ListenResult.failed(ListenFailure.error));
    }
    return completer.future.timeout(
      limit + const Duration(seconds: 4),
      onTimeout: () => _last.isEmpty
          ? const ListenResult.failed(ListenFailure.noSpeech)
          : _heard(),
    );
  }

  @override
  Future<void> cancel() async {
    try {
      if (_stt.isListening) await _stt.cancel();
    } on Object catch (_) {
      // Already stopped.
    }
    _finish(const ListenResult.failed(ListenFailure.noSpeech));
  }
}

/// Listener for tests: replays scripted results.
class ScriptedListener implements VoiceListener {
  ScriptedListener({this.isAvailable = true, List<ListenResult>? script})
    : _script = [...?script];

  final bool isAvailable;
  final List<ListenResult> _script;

  @override
  bool get available => isAvailable;

  @override
  Future<bool> init(String locale) async => isAvailable;

  @override
  Future<ListenResult> listenOnce({
    Duration limit = const Duration(seconds: 6),
    void Function(String partial)? onPartial,
  }) async => _script.isEmpty
      ? const ListenResult.failed(ListenFailure.noSpeech)
      : _script.removeAt(0);

  @override
  Future<void> cancel() async {}
}
