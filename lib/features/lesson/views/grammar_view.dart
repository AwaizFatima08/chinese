import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../core/widgets/tone_text.dart';
import '../../../l10n/l10n.dart';
import '../exercise.dart';

/// Explains one grammar point with a pattern and spoken examples.
class GrammarExplainView extends ConsumerWidget {
  const GrammarExplainView({super.key, required this.exercise});

  final GrammarExplainExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = exercise.point;
    final scheme = context.scheme;
    final label =
        ref.watch(contentProvider).asData?.value.pack.romanizationLabel ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          p.title,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.exGrammarPattern,
                style: context.text.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.pattern,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          p.explanation,
          style: context.text.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 24),
        Text(l.exGrammarExamples, style: context.text.titleMedium),
        const SizedBox(height: 8),
        for (final ex in p.examples) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScriptText(
                          ex.text,
                          textAlign: TextAlign.start,
                          style: const TextStyle(fontSize: 24, height: 1.3),
                        ),
                        RomanText(
                          ex.romanization,
                          textAlign: TextAlign.start,
                          revealLabel: l.exShowRoman(label),
                          style: const TextStyle(fontSize: 15),
                        ),
                        Text(ex.translation, style: context.text.bodyMedium),
                      ],
                    ),
                  ),
                  SpeakButton(text: ex.text, size: 48),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
