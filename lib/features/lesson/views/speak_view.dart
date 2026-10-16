import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/listener.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../core/widgets/tone_text.dart';
import '../../../l10n/l10n.dart';
import '../../../languages/pinyin_lookup.dart';
import '../exercise.dart';
import 'view_support.dart';

/// Say a word aloud.
class SpeakView extends StatelessWidget {
  const SpeakView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  final SpeakExercise exercise;
  final AnswerCallback onAnswered;

  @override
  Widget build(BuildContext context) {
    final w = exercise.word;
    return _SpeakPractice(
      title: context.l10n.exSayIt,
      text: w.text,
      romanization: w.romanization,
      numeric: w.romanizationNumeric,
      translation: w.primaryMeaning,
      onAnswered: onAnswered,
    );
  }
}

/// Listen to a sentence, then say it back.
class ShadowView extends StatelessWidget {
  const ShadowView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  final ShadowExercise exercise;
  final AnswerCallback onAnswered;

  @override
  Widget build(BuildContext context) {
    return _SpeakPractice(
      title: context.l10n.exShadowTitle,
      text: exercise.text,
      romanization: exercise.romanization,
      numeric: null,
      translation: exercise.translation,
      onAnswered: onAnswered,
    );
  }
}

enum _Mode { preparing, ready, listening, selfCheck, passed }

class _SpeakPractice extends ConsumerStatefulWidget {
  const _SpeakPractice({
    required this.title,
    required this.text,
    required this.romanization,
    required this.numeric,
    required this.translation,
    required this.onAnswered,
  });

  final String title;
  final String text;
  final String romanization;

  /// Numeric pinyin when judging a single word; null for sentences.
  final String? numeric;
  final String translation;
  final AnswerCallback onAnswered;

  @override
  ConsumerState<_SpeakPractice> createState() => _SpeakPracticeState();
}

class _SpeakPracticeState extends ConsumerState<_SpeakPractice> {
  _Mode _mode = _Mode.preparing;
  String _heard = '';
  String? _message;
  bool _messageIsGood = false;
  int _attempts = 0;

  // Kept in a field because `ref` cannot be used inside dispose().
  late final VoiceListener _voice;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceListenerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_prepare()));
  }

  Future<void> _prepare() async {
    final content = ref.read(contentProvider).asData?.value;
    final listener = ref.read(voiceListenerProvider);
    var ok = listener.available;
    if (!ok && content != null) {
      ok = await listener.init(content.pack.sttLocale);
    }
    if (!mounted) return;
    setState(() => _mode = ok ? _Mode.ready : _Mode.selfCheck);
    await teach(ref, widget.text);
  }

  @override
  void dispose() {
    unawaited(_voice.cancel());
    super.dispose();
  }

  Future<void> _listen() async {
    final l = context.l10n;
    final listener = ref.read(voiceListenerProvider);
    final lookup = ref.read(pinyinLookupProvider);
    await ref.read(speakerProvider).stop();
    setState(() {
      _mode = _Mode.listening;
      _heard = '';
      _message = null;
    });
    final result = await listener.listenOnce(
      onPartial: (p) {
        if (mounted) setState(() => _heard = p);
      },
    );
    if (!mounted) return;
    _attempts++;
    if (result.failure == ListenFailure.unavailable ||
        result.failure == ListenFailure.error) {
      setState(() => _mode = _Mode.selfCheck);
      return;
    }
    if (!result.ok) {
      setState(() {
        _mode = _Mode.ready;
        _message = l.exSpokenNothing;
        _messageIsGood = false;
      });
      _maybeGiveUp();
      return;
    }
    final verdict = _judge(lookup, result.text);
    setState(() {
      _heard = result.text;
      switch (verdict) {
        case SpeechMatch.exact:
          _mode = _Mode.passed;
          _message = l.exSpokenGreat;
          _messageIsGood = true;
        case SpeechMatch.toneOff:
          _mode = _Mode.ready;
          _message = l.exSpokenTone;
          _messageIsGood = false;
        case SpeechMatch.miss:
          _mode = _Mode.ready;
          _message = l.exSpokenMiss;
          _messageIsGood = false;
      }
    });
    if (verdict == SpeechMatch.exact) {
      answerHaptic(ref, correct: true);
      widget.onAnswered(true);
    } else {
      answerHaptic(ref, correct: false);
      _maybeGiveUp();
    }
  }

  SpeechMatch _judge(PinyinLookup? lookup, String heard) {
    if (lookup == null) return SpeechMatch.miss;
    final numeric = widget.numeric;
    if (numeric != null) {
      return lookup.match(
        target: widget.text,
        targetNumeric: numeric,
        heard: heard,
      );
    }
    return lookup.similarity(widget.text, heard) >= 0.6
        ? SpeechMatch.exact
        : SpeechMatch.miss;
  }

  /// After three tries, stop pressing: reveal the answer and let them move on.
  void _maybeGiveUp() {
    if (_attempts >= 3 && _mode != _Mode.passed) {
      widget.onAnswered(false, reveal: widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final label =
        ref.watch(contentProvider).asData?.value.pack.romanizationLabel ?? '';
    final listening = _mode == _Mode.listening;
    final isSentence = widget.numeric == null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ToneScript(
                  widget.text,
                  romanization: isSentence ? null : widget.romanization,
                  style: TextStyle(
                    fontSize: isSentence ? 30 : 64,
                    height: 1.25,
                  ),
                ),
                RomanText(
                  widget.romanization,
                  revealLabel: l.exShowRoman(label),
                  style: TextStyle(
                    fontSize: isSentence ? 17 : 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.translation,
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpeakButton(text: widget.text, label: l.exListenNormal),
                    const SizedBox(width: 24),
                    SpeakButton(
                      text: widget.text,
                      slow: true,
                      label: l.exListenSlow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (_mode == _Mode.selfCheck) ...[
          Text(
            l.exSelfCheckBody,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => widget.onAnswered(true),
            icon: const Icon(Icons.record_voice_over_rounded),
            label: Text(l.exSelfCheckDone),
          ),
        ] else if (_mode == _Mode.preparing)
          const Center(child: CircularProgressIndicator())
        else ...[
          Center(
            child: _MicButton(
              listening: listening,
              passed: _mode == _Mode.passed,
              onPressed: listening || _mode == _Mode.passed ? null : _listen,
              label: listening ? l.exListening : l.exTapSpeak,
            ),
          ),
          const SizedBox(height: 16),
          if (_heard.isNotEmpty)
            Text(
              l.exHeard(_heard),
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                color: _messageIsGood
                    ? context.appColors.success
                    : scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.listening,
    required this.passed,
    required this.onPressed,
    required this.label,
  });

  final bool listening;
  final bool passed;
  final VoidCallback? onPressed;
  final String label;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) {
      unawaited(_pulse.repeat(reverse: true));
    } else if (!widget.listening) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final colors = context.appColors;
    final bg = widget.passed ? colors.success : scheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            padding: EdgeInsets.all(8 + 10 * _pulse.value),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg.withValues(alpha: 0.12 + 0.12 * _pulse.value),
            ),
            child: child,
          ),
          child: SizedBox.square(
            dimension: 88,
            child: FilledButton(
              onPressed: widget.onPressed,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(88),
                backgroundColor: bg,
                disabledBackgroundColor: bg,
                disabledForegroundColor: Colors.white,
              ),
              child: Icon(
                widget.passed ? Icons.check_rounded : Icons.mic_rounded,
                size: 44,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label, style: context.text.labelLarge),
      ],
    );
  }
}
