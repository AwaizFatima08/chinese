import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../lesson/views/view_support.dart';
import 'say_panel.dart';
import 'speak_steps.dart';

/// Reports a finished step: whether it was right, a 0..1 score, and the
/// answer to show when it was not.
typedef StepAnswer =
    void Function(bool correct, double score, {String? reveal, int? vocabId});

/// Speaks [text] with the learner's chosen English voice.
Future<void> playEnglish(WidgetRef ref, String text, {bool slow = false}) {
  final locale = ref.read(settingsProvider).englishTtsLocale;
  return ref.read(speakerProvider).speakIn(text, locale, slow: slow);
}

/// A round button that plays [text].
class PlayButton extends ConsumerWidget {
  const PlayButton({
    super.key,
    required this.text,
    this.slow = false,
    this.label,
    this.size = 56,
  });

  final String text;
  final bool slow;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speaker = ref.watch(speakerProvider);
    final scheme = context.scheme;
    final button = ValueListenableBuilder<bool>(
      valueListenable: speaker.speaking,
      builder: (context, playing, _) => IconButton.filled(
        onPressed: () => unawaited(playEnglish(ref, text, slow: slow)),
        tooltip: label,
        iconSize: size * 0.5,
        style: IconButton.styleFrom(
          minimumSize: Size.square(size),
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
        ),
        icon: Icon(
          playing
              ? Icons.graphic_eq_rounded
              : slow
              ? Icons.slow_motion_video
              : Icons.volume_up_rounded,
        ),
      ),
    );
    if (label == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 4),
        Text(label!, style: context.text.labelMedium),
      ],
    );
  }
}

class _IpaText extends StatelessWidget {
  const _IpaText(this.ipa, {this.size});

  final String ipa;
  final double? size;

  @override
  Widget build(BuildContext context) => Text(
    '/$ipa/',
    style: context.text.titleLarge?.copyWith(
      fontSize: size,
      color: context.scheme.primary,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Starts playing once, right after the step appears.
mixin _AutoPlay<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  void autoPlay(String text, {bool slow = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(playEnglish(ref, text, slow: slow));
    });
  }
}

class TipView extends ConsumerWidget {
  const TipView({super.key, required this.step});

  final TipStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          step.title,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (step.symbols.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              for (final s in step.symbols)
                Text(
                  '/$s/',
                  style: context.text.displaySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(step.body, style: context.text.bodyLarge)),
            ],
          ),
        ),
        if (step.examples.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final e in step.examples)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PlayButton(text: e.word, size: 44),
              title: Text(
                e.word,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: _IpaText(e.ipa, size: 18),
            ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class ListenPickView extends ConsumerStatefulWidget {
  const ListenPickView({
    super.key,
    required this.step,
    required this.onAnswered,
  });

  final ListenPickStep step;
  final StepAnswer onAnswered;

  @override
  ConsumerState<ListenPickView> createState() => _ListenPickViewState();
}

class _ListenPickViewState extends ConsumerState<ListenPickView>
    with _AutoPlay {
  int? _picked;

  @override
  void initState() {
    super.initState();
    autoPlay(widget.step.word);
  }

  void _pick(int i) {
    if (_picked != null) return;
    setState(() => _picked = i);
    final ok = i == widget.step.answerIndex;
    answerHaptic(ref, correct: ok);
    widget.onAnswered(ok, ok ? 1 : 0, reveal: widget.step.word);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final step = widget.step;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l.speakWhichHeard,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayButton(text: step.word, size: 72, label: l.speakListenNormal),
            const SizedBox(width: 24),
            PlayButton(
              text: step.word,
              slow: true,
              size: 56,
              label: l.speakListenSlow,
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < step.options.length; i++) ...[
          OptionButton(
            label: step.options[i],
            sublabel: _picked == null
                ? null
                : '/${step.ipaByWord[step.options[i]]}/',
            fontSize: 28,
            state: _picked == null
                ? OptionState.idle
                : i == step.answerIndex
                ? OptionState.correct
                : i == _picked
                ? OptionState.wrong
                : OptionState.dim,
            onTap: () => _pick(i),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class SayWordView extends ConsumerStatefulWidget {
  const SayWordView({super.key, required this.step, required this.onAnswered});

  final SayWordStep step;
  final StepAnswer onAnswered;

  @override
  ConsumerState<SayWordView> createState() => _SayWordViewState();
}

class _SayWordViewState extends ConsumerState<SayWordView> with _AutoPlay {
  @override
  void initState() {
    super.initState();
    autoPlay(widget.step.word);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final step = widget.step;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l.speakSayWord,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            step.word,
            style: context.text.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Center(child: _IpaText(step.ipa)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayButton(text: step.word, size: 56, label: l.speakListenNormal),
            const SizedBox(width: 24),
            PlayButton(
              text: step.word,
              slow: true,
              size: 48,
              label: l.speakListenSlow,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SayPanel(
          target: step.word,
          contrast: step.contrast,
          tip: step.tip,
          onDone: (passed, acc) => widget.onAnswered(
            passed,
            acc,
            reveal: step.word,
            vocabId: step.vocabId,
          ),
        ),
      ],
    );
  }
}

class SayTextView extends ConsumerStatefulWidget {
  const SayTextView({super.key, required this.step, required this.onAnswered});

  final SayTextStep step;
  final StepAnswer onAnswered;

  @override
  ConsumerState<SayTextView> createState() => _SayTextViewState();
}

class _SayTextViewState extends ConsumerState<SayTextView> with _AutoPlay {
  @override
  void initState() {
    super.initState();
    autoPlay(widget.step.text, slow: widget.step.slowFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final step = widget.step;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          step.slowFirst ? l.speakSayTwister : l.speakSayText,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          step.text,
          textAlign: TextAlign.center,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        if (step.hint != null) ...[
          const SizedBox(height: 6),
          Center(
            child: Chip(
              label: Text(step.hint!),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayButton(
              text: step.text,
              slow: step.slowFirst,
              size: step.slowFirst ? 48 : 56,
              label: step.slowFirst ? l.speakListenSlow : l.speakListenNormal,
            ),
            const SizedBox(width: 24),
            PlayButton(
              text: step.text,
              slow: !step.slowFirst,
              size: step.slowFirst ? 56 : 48,
              label: step.slowFirst ? l.speakListenNormal : l.speakListenSlow,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SayPanel(
          target: step.text,
          passAt: step.passAt,
          listenLimit: Duration(seconds: 6 + step.text.length ~/ 8),
          onDone: (passed, acc) =>
              widget.onAnswered(passed, acc, reveal: step.text),
        ),
      ],
    );
  }
}

class StressPickView extends ConsumerStatefulWidget {
  const StressPickView({
    super.key,
    required this.step,
    required this.onAnswered,
  });

  final StressPickStep step;
  final StepAnswer onAnswered;

  @override
  ConsumerState<StressPickView> createState() => _StressPickViewState();
}

class _StressPickViewState extends ConsumerState<StressPickView>
    with _AutoPlay {
  int? _picked;

  @override
  void initState() {
    super.initState();
    if (widget.step.canPlay) autoPlay(widget.step.word.word);
  }

  static String _bare(String syllable) =>
      syllable.replaceAll('ˈ', '').replaceAll('ˌ', '');

  void _pick(int i) {
    if (_picked != null) return;
    setState(() => _picked = i);
    final ok = i + 1 == widget.step.word.stress;
    answerHaptic(ref, correct: ok);
    widget.onAnswered(
      ok,
      ok ? 1 : 0,
      reveal:
          '${widget.step.word.word} · ${widget.step.word.syllables.join(".")}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final w = widget.step.word;
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l.speakWhichStressed,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            w.word,
            style: context.text.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (w.pos != null)
          Center(
            child: Chip(
              label: Text(w.pos == 'verb' ? l.speakAsVerb : l.speakAsNoun),
              visualDensity: VisualDensity.compact,
            ),
          ),
        const SizedBox(height: 8),
        if (widget.step.canPlay)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayButton(text: w.word, size: 56, label: l.speakListenNormal),
              const SizedBox(width: 24),
              PlayButton(
                text: w.word,
                slow: true,
                size: 48,
                label: l.speakListenSlow,
              ),
            ],
          )
        else
          Text(
            l.speakNoPlay,
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < w.syllables.length; i++)
              Semantics(
                key: ValueKey('syllable-$i'),
                button: true,
                label: 'Syllable ${i + 1}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _picked == null ? () => _pick(i) : null,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _picked == null
                          ? scheme.surfaceContainerHigh
                          : i + 1 == w.stress
                          ? colors.successContainer
                          : i == _picked
                          ? scheme.errorContainer
                          : scheme.surfaceContainerLow,
                      border: Border.all(
                        color: _picked == null
                            ? scheme.outlineVariant
                            : i + 1 == w.stress
                            ? colors.success
                            : i == _picked
                            ? scheme.error
                            : scheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _picked == null
                              ? _bare(w.syllables[i])
                              : w.syllables[i],
                          style: context.text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('${i + 1}', style: context.text.labelMedium),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_picked != null) ...[
          const SizedBox(height: 14),
          Center(
            child: Text(
              l.speakStressOn(w.stress),
              style: context.text.titleMedium,
            ),
          ),
          Center(child: _IpaText(w.ipa)),
        ],
      ],
    );
  }
}

class VocabIntroView extends ConsumerStatefulWidget {
  const VocabIntroView({super.key, required this.step});

  final VocabIntroStep step;

  @override
  ConsumerState<VocabIntroView> createState() => _VocabIntroViewState();
}

class _VocabIntroViewState extends ConsumerState<VocabIntroView>
    with _AutoPlay {
  @override
  void initState() {
    super.initState();
    autoPlay(widget.step.word.word);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = widget.step.word;
    final scheme = context.scheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(
          child: Text(
            w.word,
            style: context.text.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Center(child: _IpaText(w.ipa)),
        Center(
          child: Text(
            w.pos,
            style: context.text.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayButton(text: w.word, size: 56, label: l.speakListenNormal),
            const SizedBox(width: 24),
            PlayButton(
              text: w.word,
              slow: true,
              size: 48,
              label: l.speakListenSlow,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(w.definition, style: context.text.titleMedium),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.speakExample,
                      style: context.text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(w.example, style: context.text.bodyLarge),
                  ],
                ),
              ),
              PlayButton(text: w.example, size: 44),
            ],
          ),
        ),
      ],
    );
  }
}

class VocabRecallView extends ConsumerStatefulWidget {
  const VocabRecallView({
    super.key,
    required this.step,
    required this.onAnswered,
  });

  final VocabRecallStep step;
  final StepAnswer onAnswered;

  @override
  ConsumerState<VocabRecallView> createState() => _VocabRecallViewState();
}

class _VocabRecallViewState extends ConsumerState<VocabRecallView> {
  int? _picked;

  void _pick(int i) {
    if (_picked != null) return;
    setState(() => _picked = i);
    final ok = i == widget.step.answerIndex;
    answerHaptic(ref, correct: ok);
    widget.onAnswered(
      ok,
      ok ? 1 : 0,
      reveal: widget.step.word.word,
      vocabId: widget.step.word.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final step = widget.step;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l.speakDefinitionPrompt,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            step.word.definition,
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < step.options.length; i++) ...[
          OptionButton(
            label: step.options[i].word,
            sublabel: _picked == null ? null : '/${step.options[i].ipa}/',
            fontSize: 24,
            state: _picked == null
                ? OptionState.idle
                : i == step.answerIndex
                ? OptionState.correct
                : i == _picked
                ? OptionState.wrong
                : OptionState.dim,
            onTap: () => _pick(i),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
