import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';

/// Bottom panel after an answer: result, the right answer if needed, and
/// the continue button.
class FeedbackBar extends StatelessWidget {
  const FeedbackBar({
    super.key,
    required this.correct,
    required this.scored,
    required this.reveal,
    required this.onContinue,
  });

  final bool correct;

  /// Whether this was a scored question (wrong ones come back later).
  final bool scored;
  final String? reveal;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.appColors;
    final scheme = context.scheme;
    final bg = correct ? colors.successContainer : scheme.errorContainer;
    final fg = correct ? colors.success : scheme.error;
    final title = correct
        ? (scored ? l.lessonCorrect : l.exShadowDone)
        : l.lessonIncorrect;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: fg,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: context.text.titleLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (!correct && reveal != null) ...[
                const SizedBox(height: 6),
                Text(
                  l.lessonAnswerIs(reveal!),
                  style: context.text.titleMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
              if (!correct && scored) ...[
                const SizedBox(height: 2),
                Text(
                  l.lessonRetryLater,
                  style: context.text.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: fg,
                  foregroundColor: correct
                      ? context.appColors.onSuccess
                      : scheme.onError,
                ),
                child: Text(l.commonContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
