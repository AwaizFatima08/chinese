import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Plays [text] in the target language when pressed.
class SpeakButton extends ConsumerWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.slow = false,
    this.label,
    this.filled = true,
    this.size = 56,
  });

  final String text;
  final bool slow;
  final String? label;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speaker = ref.watch(speakerProvider);
    final icon = slow ? Icons.slow_motion_video : Icons.volume_up_rounded;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: speaker.speaking,
      builder: (context, playing, _) {
        final button = IconButton.filled(
          onPressed: () => speaker.speak(text, slow: slow),
          tooltip: label,
          iconSize: size * 0.5,
          style: IconButton.styleFrom(
            minimumSize: Size.square(size),
            backgroundColor: filled
                ? scheme.primaryContainer
                : Colors.transparent,
            foregroundColor: scheme.onPrimaryContainer,
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              playing ? Icons.graphic_eq_rounded : icon,
              key: ValueKey(playing),
            ),
          ),
        );
        if (label == null) return button;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button,
            const SizedBox(height: 4),
            Text(label!, style: Theme.of(context).textTheme.labelMedium),
          ],
        );
      },
    );
  }
}
