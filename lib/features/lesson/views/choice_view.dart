import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../core/widgets/tone_text.dart';
import '../../../l10n/l10n.dart';
import '../exercise.dart';
import 'view_support.dart';

final RegExp _hasHan = RegExp(r'[一-鿿]');

/// Shared behaviour of "pick one answer" screens: lock after the first tap,
/// colour right and wrong, and report the result once.
mixin _PicksOne<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  int? selected;

  OptionState stateOf(int i, int answer) {
    if (selected == null) return OptionState.idle;
    if (i == answer) return OptionState.correct;
    if (i == selected) return OptionState.wrong;
    return OptionState.dim;
  }

  /// Returns false when an answer was already given.
  bool pick(int i, int answer, AnswerCallback onAnswered, {String? reveal}) {
    if (selected != null) return false;
    setState(() => selected = i);
    final ok = i == answer;
    answerHaptic(ref, correct: ok);
    onAnswered(ok, reveal: reveal);
    return true;
  }
}

class ChoiceView extends ConsumerStatefulWidget {
  const ChoiceView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  final ChoiceExercise exercise;
  final AnswerCallback onAnswered;

  @override
  ConsumerState<ChoiceView> createState() => _ChoiceViewState();
}

class _ChoiceViewState extends ConsumerState<ChoiceView> with _PicksOne {
  @override
  void initState() {
    super.initState();
    if (widget.exercise.promptIsAudio) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(teach(ref, widget.exercise.word.text)),
      );
    }
  }

  void _onTap(int i) {
    final ex = widget.exercise;
    final first = pick(
      i,
      ex.answerIndex,
      widget.onAnswered,
      reveal: ex.options[ex.answerIndex],
    );
    if (first && !ex.promptIsAudio) {
      unawaited(teach(ref, ex.word.text));
    }
  }

  String _title(BuildContext context, String label) {
    final l = context.l10n;
    return switch (widget.exercise.kind) {
      ChoiceKind.listenMeaning => l.exListenChoose,
      ChoiceKind.readMeaning => l.exReadChoose,
      ChoiceKind.meaningWord => l.exMeaningChoose,
      ChoiceKind.listenWord => l.exListenWord,
      ChoiceKind.listenRomanization => l.exListenRoman(label),
      ChoiceKind.article => l.exArticleChoose,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final l = context.l10n;
    final label =
        ref.watch(contentProvider).asData?.value.pack.romanizationLabel ?? '';
    final answered = selected != null;
    final scheme = context.scheme;

    Widget prompt;
    if (ex.promptIsAudio) {
      prompt = Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpeakButton(
                text: ex.word.text,
                size: 84,
                label: l.exListenNormal,
              ),
              const SizedBox(width: 28),
              SpeakButton(
                text: ex.word.text,
                slow: true,
                size: 64,
                label: l.exListenSlow,
              ),
            ],
          ),
          if (answered && ex.kind != ChoiceKind.listenRomanization) ...[
            const SizedBox(height: 12),
            ScriptText(
              ex.word.text,
              romanization: ex.word.romanization,
              article: ex.word.article,
              style: const TextStyle(fontSize: 40),
            ),
          ],
        ],
      );
    } else if (ex.kind == ChoiceKind.article) {
      prompt = Column(
        children: [
          ScriptText(
            answered ? ex.word.text : ex.word.lemma,
            article: answered ? ex.word.article : null,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            ex.word.primaryMeaning,
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          const SizedBox(height: 12),
          SpeakButton(text: ex.word.lemma, size: 52),
        ],
      );
    } else if (ex.kind == ChoiceKind.readMeaning) {
      prompt = Column(
        children: [
          ScriptText(
            ex.word.text,
            romanization: ex.word.romanization,
            article: ex.word.article,
            style: const TextStyle(
              fontSize: 64,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          RomanText(
            ex.word.romanization,
            revealLabel: l.exShowRoman(label),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ],
      );
    } else {
      prompt = Text(
        ex.word.primaryMeaning,
        textAlign: TextAlign.center,
        style: context.text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // Short script options (one or two hanzi, der/die/das) sit in a grid or a
    // row; longer words (German) get full-width buttons so they never wrap
    // inside a fixed-height cell at large text sizes.
    final shortOptions = ex.options.every((o) => o.runes.length <= 4);
    final asList =
        ex.optionsAreScript && ex.kind != ChoiceKind.article && !shortOptions;
    final options = <Widget>[
      for (var i = 0; i < ex.options.length; i++)
        OptionButton(
          label: ex.options[i],
          script: ex.optionsAreScript && !asList,
          fontSize: asList ? 24 : null,
          state: stateOf(i, ex.answerIndex),
          onTap: answered ? null : () => _onTap(i),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          _title(context, label),
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Center(child: prompt),
        const SizedBox(height: 28),
        if (ex.kind == ChoiceKind.article)
          Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: options[i]),
              ],
            ],
          )
        else if (ex.optionsAreScript && !asList)
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: options,
          )
        else
          for (final o in options) ...[o, const SizedBox(height: 12)],
      ],
    );
  }
}

/// "Hear or read a sentence, pick its meaning."
class SentenceChoiceView extends ConsumerStatefulWidget {
  const SentenceChoiceView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  final SentenceChoiceExercise exercise;
  final AnswerCallback onAnswered;

  @override
  ConsumerState<SentenceChoiceView> createState() => _SentenceChoiceViewState();
}

class _SentenceChoiceViewState extends ConsumerState<SentenceChoiceView>
    with _PicksOne {
  @override
  void initState() {
    super.initState();
    if (widget.exercise.listenFirst) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(teach(ref, widget.exercise.sentence.text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final s = ex.sentence;
    final l = context.l10n;
    final label =
        ref.watch(contentProvider).asData?.value.pack.romanizationLabel ?? '';
    final answered = selected != null;
    final showText = !ex.listenFirst || answered;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          ex.listenFirst ? l.exListenChoose : l.exReadChoose,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (ex.listenFirst && !showText)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpeakButton(
                        text: s.text,
                        size: 80,
                        label: l.exListenNormal,
                      ),
                      const SizedBox(width: 28),
                      SpeakButton(
                        text: s.text,
                        slow: true,
                        size: 60,
                        label: l.exListenSlow,
                      ),
                    ],
                  )
                else ...[
                  ScriptText(
                    s.text,
                    style: const TextStyle(fontSize: 30, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  RomanText(
                    s.romanization,
                    revealLabel: l.exShowRoman(label),
                    style: const TextStyle(fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  SpeakButton(text: s.text, size: 48),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < ex.options.length; i++) ...[
          OptionButton(
            label: ex.options[i],
            state: stateOf(i, ex.answerIndex),
            onTap: answered
                ? null
                : () {
                    final first = pick(
                      i,
                      ex.answerIndex,
                      widget.onAnswered,
                      reveal: ex.options[ex.answerIndex],
                    );
                    if (first && !ex.listenFirst) unawaited(teach(ref, s.text));
                  },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// A grammar check question. Options may be English or script.
class GrammarChoiceView extends ConsumerStatefulWidget {
  const GrammarChoiceView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  final GrammarChoiceExercise exercise;
  final AnswerCallback onAnswered;

  @override
  ConsumerState<GrammarChoiceView> createState() => _GrammarChoiceViewState();
}

class _GrammarChoiceViewState extends ConsumerState<GrammarChoiceView>
    with _PicksOne {
  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final l = context.l10n;
    final answered = selected != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l.exQuizQuestion,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          ex.prompt,
          textAlign: TextAlign.center,
          style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < ex.options.length; i++) ...[
          OptionButton(
            label: ex.options[i],
            script: false,
            state: stateOf(i, ex.answerIndex),
            onTap: answered
                ? null
                : () {
                    final first = pick(
                      i,
                      ex.answerIndex,
                      widget.onAnswered,
                      reveal: ex.options[ex.answerIndex],
                    );
                    final text = ex.options[ex.answerIndex];
                    if (first && _hasHan.hasMatch(text)) {
                      unawaited(teach(ref, text));
                    }
                  },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
