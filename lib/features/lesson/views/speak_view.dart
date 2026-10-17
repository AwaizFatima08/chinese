import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../languages/language_tools.dart';
import '../../../core/services/listener.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../core/widgets/tone_text.dart';
import '../../../l10n/l10n.dart';
import '../../../languages/models.dart';
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
      word: w,
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
      word: null,
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
    required this.word,
    required this.translation,
    required this.onAnswered,
  });

  final String title;
  final String text;
  final String romanization;

  /// The word being practised; null when repeating a whole sentence.
  final Word? word;
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
    final tools = ref.read(languageToolsProvider);
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
    final verdict = _judge(tools, result.text);
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
        case SpeechMatch.close:
          _mode = _Mode.ready;
          _message = l.exSpokenClose;
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

  SpeechMatch _judge(LanguageTools? tools, String heard) {
    if (tools == null) return SpeechMatch.miss;
    final word = widget.word;
    if (word != null) return tools.matchWord(word: word, heard: heard);
    return tools.similarity(widget.text, heard) >= 0.6
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
    final isSentence = widget.word == null;
    final status = _statusLines(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    children: [
                      ScriptText(
                        widget.text,
                        romanization: isSentence ? null : widget.romanization,
                        article: widget.word?.article,
                        style: TextStyle(
                          fontSize: isSentence ? 28 : 56,
                          height: 1.2,
                        ),
                      ),
                      RomanText(
                        widget.romanization,
                        revealLabel: l.exShowRoman(label),
                        style: TextStyle(
                          fontSize: isSentence ? 16 : 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.translation,
                        textAlign: TextAlign.center,
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpeakButton(
                            text: widget.text,
                            size: 48,
                            label: l.exListenNormal,
                          ),
                          const SizedBox(width: 24),
                          SpeakButton(
                            text: widget.text,
                            slow: true,
                            size: 48,
                            label: l.exListenSlow,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: [
              if (_mode == _Mode.selfCheck) ...[
                Text(
                  l.exSelfCheckBody,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => widget.onAnswered(true),
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: Text(l.exSelfCheckDone),
                ),
              ] else if (_mode == _Mode.preparing)
                const Center(child: CircularProgressIndicator())
              else ...[
                // What was heard and how it went sit above the mic so they are
                // never pushed off-screen on short displays.
                if (status.isNotEmpty) ...[
                  ...status,
                  const SizedBox(height: 8),
                ],
                Center(
                  child: _MicButton(
                    listening: listening,
                    passed: _mode == _Mode.passed,
                    onPressed: listening || _mode == _Mode.passed
                        ? null
                        : _listen,
                    label: listening ? l.exListening : l.exTapSpeak,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _statusLines(BuildContext context) {
    final l = context.l10n;
    return [
      if (_heard.isNotEmpty)
        Text(
          l.exHeard(_heard),
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      if (_message != null)
        Text(
          _message!,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: _messageIsGood
                ? context.appColors.success
                : context.scheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
    ];
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
            dimension: 76,
            child: FilledButton(
              onPressed: widget.onPressed,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(76),
                backgroundColor: bg,
                disabledBackgroundColor: bg,
                disabledForegroundColor: Colors.white,
              ),
              child: Icon(
                widget.passed ? Icons.check_rounded : Icons.mic_rounded,
                size: 38,
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
