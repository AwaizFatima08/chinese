import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_button.dart';
import '../../core/widgets/tone_text.dart';
import '../../l10n/l10n.dart';
import '../../languages/models.dart';
import '../writing/stroke_board.dart';

/// Opens the detail sheet for [word].
void showWordDetail(BuildContext context, Word word) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (context) => WordDetailSheet(word: word),
  );
}

class WordDetailSheet extends ConsumerWidget {
  const WordDetailSheet({super.key, required this.word});

  final Word word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentProvider).requireValue;
    final examples = [
      for (final id in word.exampleIds)
        if (content.sentences[id] != null) content.sentences[id]!,
    ].take(3).toList();
    final chars = word.text.runes
        .map(String.fromCharCode)
        .where(content.hasStrokes)
        .toList();
    final label = content.pack.romanizationLabel;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        shrinkWrap: true,
        children: [
          Center(
            child: ScriptText(
              word.text,
              romanization: word.romanization,
              style: const TextStyle(fontSize: 72, height: 1.15),
            ),
          ),
          Center(
            child: RomanText(
              word.romanization,
              forceShow: true,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          if (word.altText != word.text)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(word.altText, style: context.text.titleMedium),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpeakButton(text: word.text, label: l.exListenNormal),
              const SizedBox(width: 24),
              SpeakButton(text: word.text, slow: true, label: l.exListenSlow),
            ],
          ),
          const SizedBox(height: 20),
          Text(l.exMeaning, style: context.text.titleSmall),
          const SizedBox(height: 6),
          for (final m in word.meanings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $m', style: context.text.bodyLarge),
            ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l.wordsExamples, style: context.text.titleSmall),
            const SizedBox(height: 6),
            for (final s in examples)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: ScriptText(
                  s.text,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 22),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RomanText(
                      s.romanization,
                      textAlign: TextAlign.start,
                      revealLabel: l.exShowRoman(label),
                    ),
                    Text(s.translation),
                  ],
                ),
                trailing: SpeakButton(text: s.text, size: 44),
              ),
          ],
          if (chars.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l.wordsStrokes, style: context.text.titleSmall),
            const SizedBox(height: 8),
            _StrokePreview(chars: chars.toSet().toList()),
          ],
        ],
      ),
    );
  }
}

class _StrokePreview extends ConsumerStatefulWidget {
  const _StrokePreview({required this.chars});

  final List<String> chars;

  @override
  ConsumerState<_StrokePreview> createState() => _StrokePreviewState();
}

class _StrokePreviewState extends ConsumerState<_StrokePreview> {
  final StrokeBoardController _controller = StrokeBoardController();
  int _selected = 0;
  StrokeGlyph? _glyph;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final content = ref.read(contentProvider).requireValue;
    final data = await content.strokesFor(widget.chars[_selected]);
    if (!mounted || data == null) return;
    setState(() => _glyph = StrokeGlyph.from(data));
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.watch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        if (widget.chars.length > 1)
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < widget.chars.length; i++)
                ChoiceChip(
                  label: Text(
                    widget.chars[i],
                    style: const TextStyle(fontSize: 20),
                  ),
                  selected: i == _selected,
                  onSelected: (_) {
                    setState(() {
                      _selected = i;
                      _glyph = null;
                    });
                    unawaited(_load());
                  },
                ),
            ],
          ),
        const SizedBox(height: 8),
        if (_glyph != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: StrokeBoard(glyph: _glyph!, controller: _controller),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _controller.watch,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l.exWatch),
          style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
        ),
      ],
    );
  }
}
