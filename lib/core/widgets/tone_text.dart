import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../util/pinyin.dart';

final RegExp _han = RegExp(r'[一-鿿]');

/// Script text coloured as a learning aid: Chinese by tone when
/// [romanization] lines up character-for-character with the text, and a
/// German noun's [article] by gender.
class ScriptText extends ConsumerWidget {
  const ScriptText(
    this.text, {
    super.key,
    this.romanization,
    this.article,
    this.style,
    this.textAlign = TextAlign.center,
  });

  final String text;

  /// The noun's article (`der`, `die`, `das`) when [text] starts with it.
  final String? article;

  /// Tone-marked pinyin, syllables separated by spaces.
  final String? romanization;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorize = ref.watch(settingsProvider.select((s) => s.toneColors));
    final base = (style ?? DefaultTextStyle.of(context).style);
    final colors = context.appColors;
    final r = romanization;
    final art = article;
    if (colorize && art != null && text.startsWith('$art ')) {
      final tint = colors.genderColor(art);
      if (tint != null) {
        return Text.rich(
          TextSpan(
            style: base,
            children: [
              TextSpan(
                text: art,
                style: TextStyle(color: tint, fontWeight: FontWeight.w700),
              ),
              TextSpan(text: text.substring(art.length)),
            ],
          ),
          textAlign: textAlign,
        );
      }
    }
    if (!colorize || r == null || r.isEmpty) {
      return Text(text, style: base, textAlign: textAlign);
    }
    final syl = syllables(r);
    final chars = text.runes.map(String.fromCharCode).toList();
    final hanCount = chars.where(_han.hasMatch).length;
    if (syl.length != hanCount) {
      return Text(text, style: base, textAlign: textAlign);
    }
    var k = 0;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final ch in chars)
            TextSpan(
              text: ch,
              style: _han.hasMatch(ch)
                  ? TextStyle(color: colors.toneColor(toneOfMarked(syl[k++])))
                  : null,
            ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}

/// Romanization (pinyin) with per-syllable tone colours, honouring the
/// learner's "always / tap to reveal / hidden" preference.
class RomanText extends ConsumerStatefulWidget {
  const RomanText(
    this.romanization, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.forceShow = false,
    this.revealLabel,
  });

  final String romanization;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Show regardless of the setting (e.g. on a result screen).
  final bool forceShow;

  /// Text shown on the reveal chip in tap-to-reveal mode.
  final String? revealLabel;

  @override
  ConsumerState<RomanText> createState() => _RomanTextState();
}

class _RomanTextState extends ConsumerState<RomanText> {
  bool _revealed = false;

  @override
  void didUpdateWidget(RomanText old) {
    super.didUpdateWidget(old);
    if (old.romanization != widget.romanization) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.romanization.isEmpty) return const SizedBox.shrink();
    final settings = ref.watch(settingsProvider);
    final mode = widget.forceShow
        ? RomanizationMode.always
        : settings.romanization;
    if (mode == RomanizationMode.hidden) return const SizedBox.shrink();
    if (mode == RomanizationMode.tapToReveal && !_revealed) {
      return TextButton.icon(
        onPressed: () => setState(() => _revealed = true),
        icon: const Icon(Icons.visibility_outlined, size: 18),
        label: Text(widget.revealLabel ?? ''),
      );
    }
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final colors = context.appColors;
    if (!settings.toneColors) {
      return Text(
        widget.romanization,
        style: base,
        textAlign: widget.textAlign,
      );
    }
    final parts = widget.romanization.split(' ');
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            TextSpan(
              text: parts[i],
              style: TextStyle(color: colors.toneColor(toneOfMarked(parts[i]))),
            ),
            if (i < parts.length - 1) const TextSpan(text: ' '),
          ],
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}
