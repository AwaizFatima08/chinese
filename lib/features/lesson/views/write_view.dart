import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/misc_widgets.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../core/widgets/tone_text.dart';
import '../../../l10n/l10n.dart';
import '../../../languages/models.dart';
import '../../writing/stroke_board.dart';
import '../exercise.dart';
import 'view_support.dart';

/// Trace one character stroke by stroke, with a demonstration first.
class WriteView extends ConsumerStatefulWidget {
  const WriteView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  final WriteExercise exercise;
  final AnswerCallback onAnswered;

  @override
  ConsumerState<WriteView> createState() => _WriteViewState();
}

class _WriteViewState extends ConsumerState<WriteView> {
  final StrokeBoardController _controller = StrokeBoardController();
  late final Future<StrokeData?> _data;
  StrokeGlyph? _glyph;
  int _done = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final content = ref.read(contentProvider).requireValue;
    _data = content.strokesFor(widget.exercise.char);
    unawaited(
      _data.then((d) {
        if (!mounted) return;
        if (d == null) {
          // No guide for this character: do not trap the learner.
          widget.onAnswered(true);
          return;
        }
        setState(() => _glyph = StrokeGlyph.from(d));
        // Show the stroke order once before they try.
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _controller.watch();
        });
      }),
    );
    unawaited(teach(ref, widget.exercise.word.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ex = widget.exercise;
    final glyph = _glyph;
    if (glyph == null) {
      return FutureBuilder<StrokeData?>(
        future: _data,
        builder: (context, snap) => snap.connectionState == ConnectionState.done
            ? MessageView(
                message: l.exWriteNoData,
                icon: Icons.edit_off_rounded,
              )
            : MessageView(message: l.commonLoading, loading: true),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.exWriteTitle, style: context.text.titleMedium),
                    const SizedBox(height: 4),
                    RomanText(
                      ex.word.romanization,
                      textAlign: TextAlign.start,
                      forceShow: true,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(ex.word.primaryMeaning, style: context.text.bodyLarge),
                  ],
                ),
              ),
              SpeakButton(text: ex.word.text, size: 52),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: StrokeBoard(
                  glyph: glyph,
                  controller: _controller,
                  semanticLabel: l.exTraceBody,
                  onStrokeAccepted: (n) {
                    answerHaptic(ref, correct: true);
                    setState(() => _done = n);
                  },
                  onMistake: () => answerHaptic(ref, correct: false),
                  onComplete: (_) {
                    setState(() => _finished = true);
                    widget.onAnswered(true);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _finished
                ? l.exWriteDone
                : l.exStrokeCount(
                    (_done + 1).clamp(1, glyph.count),
                    glyph.count,
                  ),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.watch,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l.exWatch),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _finished ? null : _controller.hint,
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: Text(l.exHint),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _controller.reset();
                    setState(() {
                      _done = 0;
                      _finished = false;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.exClear),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
