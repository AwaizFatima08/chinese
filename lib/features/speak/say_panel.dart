import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/listener.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'pronunciation.dart';

/// Result of a spoken attempt, reported once when the step is finished.
typedef SayDone = void Function(bool passed, double accuracy);

/// Microphone button, live transcript and word-by-word feedback for one
/// spoken target. The learner may try again; skipping ends the step as not
/// passed.
class SayPanel extends ConsumerStatefulWidget {
  const SayPanel({
    super.key,
    required this.target,
    required this.onDone,
    this.passAt = 0.8,
    this.contrast,
    this.tip,
    this.listenLimit = const Duration(seconds: 8),
  });

  final String target;
  final SayDone onDone;

  /// Accuracy needed for a sentence to pass (single words need an exact hit).
  final double passAt;

  /// The look-alike word this step trains against, to name a mix-up.
  final String? contrast;
  final String? tip;
  final Duration listenLimit;

  @override
  ConsumerState<SayPanel> createState() => _SayPanelState();
}

enum _Phase { idle, listening, result }

class _SayPanelState extends ConsumerState<SayPanel> {
  _Phase _phase = _Phase.idle;
  String _partial = '';
  SpeechScore? _score;
  ListenResult? _heard;
  double _best = 0;
  int _attempts = 0;
  bool _micReady = true;
  bool _finished = false;
  late final VoiceListener _listener;
  late final String _sttLocale;

  @override
  void initState() {
    super.initState();
    _listener = ref.read(voiceListenerProvider);
    _sttLocale = ref.read(settingsProvider).englishSttLocale;
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final ok = await _listener.init(_sttLocale);
    if (mounted) setState(() => _micReady = ok);
  }

  @override
  void dispose() {
    unawaited(_listener.cancel());
    super.dispose();
  }

  void _finish(bool passed, double accuracy) {
    if (_finished) return;
    _finished = true;
    widget.onDone(passed, accuracy);
  }

  Future<void> _listen() async {
    if (_phase == _Phase.listening || _finished) return;
    if (ref.read(settingsProvider).haptics) {
      unawaited(HapticFeedback.selectionClick());
    }
    setState(() {
      _phase = _Phase.listening;
      _partial = '';
    });
    final r = await _listener.listenOnce(
      limit: widget.listenLimit,
      onPartial: (p) {
        if (mounted) setState(() => _partial = p);
      },
    );
    if (!mounted) return;
    _attempts++;
    if (!r.ok) {
      setState(() {
        _phase = _Phase.result;
        _heard = r;
        _score = null;
      });
      return;
    }
    final score = scoreSpeech(
      widget.target,
      r.text,
      alternatives: r.alternatives,
    );
    if (score.accuracy > _best) _best = score.accuracy;
    setState(() {
      _phase = _Phase.result;
      _heard = r;
      _score = score;
    });
    final passed = score.words.length <= 1
        ? score.passed
        : score.accuracy >= widget.passAt;
    if (passed) {
      if (ref.read(settingsProvider).haptics) {
        unawaited(HapticFeedback.lightImpact());
      }
      _finish(true, score.accuracy);
    }
  }

  bool get _passed {
    final s = _score;
    if (s == null) return false;
    return s.words.length <= 1 ? s.passed : s.accuracy >= widget.passAt;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final listening = _phase == _Phase.listening;
    final done = _finished;

    if (!_micReady) {
      return Column(
        children: [
          Text(
            l.speakNoMic,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: done ? null : () => _finish(true, 0.7),
            child: Text(l.speakSelfCheck),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: listening ? l.speakListening : l.speakTapMic,
          child: GestureDetector(
            onTap: done ? null : _listen,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening
                    ? scheme.error
                    : done
                    ? scheme.surfaceContainerHighest
                    : scheme.primary,
                boxShadow: listening
                    ? [
                        BoxShadow(
                          color: scheme.error.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                size: 44,
                color: done ? scheme.onSurfaceVariant : scheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          listening
              ? (_partial.isEmpty ? l.speakListening : _partial)
              : l.speakTapMic,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_phase == _Phase.result) _feedback(context),
        if (_phase == _Phase.result && !_passed && !done) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _listen,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.speakTryAgain),
              ),
              TextButton(
                onPressed: () => _finish(false, _best),
                child: Text(l.commonSkip),
              ),
            ],
          ),
        ] else if (_phase == _Phase.idle && !done && _attempts == 0) ...[
          TextButton(
            onPressed: () => _finish(false, 0),
            child: Text(l.commonSkip),
          ),
        ],
      ],
    );
  }

  Widget _feedback(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final colors = context.appColors;
    final score = _score;
    if (score == null) {
      return Text(
        l.speakNothingHeard,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: scheme.error),
      );
    }

    Color colorFor(WordMark m) => switch (m) {
      WordMark.match => colors.success,
      WordMark.close => colors.gold,
      WordMark.wrong => scheme.error,
      WordMark.missing => scheme.outline,
    };

    final single = score.words.length == 1;
    final first = score.words.first;
    String? mixUp;
    if (single && !score.passed && widget.contrast != null) {
      final heard = tokenize(score.heardText);
      if (heard.contains(widget.contrast!.toLowerCase())) {
        mixUp = l.speakSoundedLike(widget.contrast!);
      }
    }
    final clarity = _heard?.confidence ?? 0;

    return Column(
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final w in score.words)
              Semantics(
                label: '${w.target}: ${w.mark.name}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorFor(w.mark).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorFor(w.mark)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        w.target,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: w.mark == WordMark.missing
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (w.mark == WordMark.wrong || w.mark == WordMark.close)
                        if (w.heard != null && w.heard != w.target)
                          Text(
                            w.heard!,
                            style: context.text.labelSmall?.copyWith(
                              color: colorFor(w.mark),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_passed)
          Text(
            score.perfect ? l.speakClear : l.speakAlmost,
            style: context.text.titleMedium?.copyWith(
              color: colors.success,
              fontWeight: FontWeight.w800,
            ),
          )
        else ...[
          if (mixUp != null)
            Text(
              mixUp,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(color: scheme.error),
            )
          else
            Text(
              l.speakHeard(score.heardText),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          if (single && first.mark != WordMark.match && widget.tip != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.tip!,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        if (clarity > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.speakClarity((clarity * 100).round()),
              style: context.text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
