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

/// Introduces one new word: the teacher says it, then its meaning and an
/// example, while the learner sees the script, pinyin and meaning.
class IntroView extends ConsumerStatefulWidget {
  const IntroView({super.key, required this.exercise});

  final IntroExercise exercise;

  @override
  ConsumerState<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends ConsumerState<IntroView> {
  int _run = 0;

  @override
  void initState() {
    super.initState();
    if (ref.read(settingsProvider).autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_teach()));
    }
  }

  /// The teacher script: word, meaning, then the example sentence.
  Future<void> _teach() async {
    final run = ++_run;
    final speaker = ref.read(speakerProvider);
    final w = widget.exercise.word;
    await teach(ref, w.text);
    if (!mounted || run != _run) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || run != _run) return;
    await speaker.speakEnglish(w.primaryMeaning);
    final example = widget.exercise.example;
    if (!mounted || run != _run || example == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || run != _run) return;
    await teach(ref, example.text);
  }

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = widget.exercise.word;
    final example = widget.exercise.example;
    final label =
        ref.watch(contentProvider).asData?.value.pack.romanizationLabel ?? '';
    final text = context.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  ScriptText(
                    w.text,
                    romanization: w.romanization,
                    article: w.article,
                    style: const TextStyle(
                      fontSize: 76,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RomanText(
                    w.romanization,
                    revealLabel: l.exShowRoman(label),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    w.primaryMeaning,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (w.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      w.note,
                      textAlign: TextAlign.center,
                      style: text.titleSmall?.copyWith(
                        color: context.scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (w.meanings.length > 1) ...[
                    const SizedBox(height: 6),
                    Text(
                      w.meanings.skip(1).take(2).join('  ·  '),
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpeakButton(text: w.text, label: l.exListenNormal),
                      const SizedBox(width: 24),
                      SpeakButton(
                        text: w.text,
                        slow: true,
                        label: l.exListenSlow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (example != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.exExample,
                            style: text.labelMedium?.copyWith(
                              color: context.scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ScriptText(
                            example.text,
                            romanization: null,
                            textAlign: TextAlign.start,
                            style: const TextStyle(fontSize: 24, height: 1.3),
                          ),
                          RomanText(
                            example.romanization,
                            textAlign: TextAlign.start,
                            revealLabel: l.exShowRoman(label),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(example.translation, style: text.bodyLarge),
                        ],
                      ),
                    ),
                    SpeakButton(text: example.text, size: 48),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
