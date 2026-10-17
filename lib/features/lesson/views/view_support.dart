import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Reports the learner's answer to the lesson runner.
typedef AnswerCallback = void Function(bool correct, {String? reveal});

/// Vibrates lightly for right and firmly for wrong, if the learner allows.
void answerHaptic(WidgetRef ref, {required bool correct}) {
  if (!ref.read(settingsProvider).haptics) return;
  if (correct) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.mediumImpact();
  }
}

/// Speaks the target-language [text] using the learner's speed preference.
Future<void> teach(WidgetRef ref, String text, {bool? slow}) {
  final settings = ref.read(settingsProvider);
  return ref
      .read(speakerProvider)
      .speak(text, slow: slow ?? settings.slowSpeech);
}

final RegExp _han = RegExp(r'[\u4e00-\u9fff]');

enum OptionState { idle, correct, wrong, dim }

/// A large tappable answer.
class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.script = false,
    this.sublabel,
    this.fontSize,
    this.compact = false,
  });

  final String label;
  final String? sublabel;
  final OptionState state;
  final VoidCallback? onTap;

  /// Render in large script type (for hanzi options).
  final bool script;

  /// Overrides the automatic type size.
  final double? fontSize;

  /// A narrow layout for several buttons in one row: centred label with the
  /// result icon beneath it.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (Color bg, Color border, Color fg, IconData? icon) = switch (state) {
      OptionState.correct => (
        colors.successContainer,
        colors.success,
        scheme.onSurface,
        Icons.check_circle_rounded,
      ),
      OptionState.wrong => (
        scheme.errorContainer,
        scheme.error,
        scheme.onErrorContainer,
        Icons.cancel_rounded,
      ),
      OptionState.dim => (
        scheme.surfaceContainerLow,
        scheme.outlineVariant,
        scheme.onSurface.withValues(alpha: 0.45),
        null,
      ),
      OptionState.idle => (
        scheme.surfaceContainerLowest,
        scheme.outlineVariant,
        scheme.onSurface,
        null,
      ),
    };
    final iconColor = state == OptionState.correct
        ? colors.success
        : scheme.error;
    return Semantics(
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      label: sublabel == null ? label : '$label, $sublabel',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: border,
            width: state == OptionState.idle ? 1.5 : 2.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: script ? 84 : 60),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 16,
                vertical: 12,
              ),
              child: compact
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: fontSize ?? 30,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 24,
                          child: icon == null
                              ? null
                              : Icon(icon, color: iconColor, size: 20),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: script
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                textAlign: script
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: TextStyle(
                                  fontSize:
                                      fontSize ??
                                      (script
                                          ? 34
                                          : (_han.hasMatch(label) ? 22 : 17)),
                                  fontWeight: script
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  color: fg,
                                  height: 1.25,
                                ),
                              ),
                              if (sublabel != null)
                                Text(
                                  sublabel!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: fg.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (icon != null) Icon(icon, color: iconColor),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
