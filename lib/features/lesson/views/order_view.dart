import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/pinyin.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../core/widgets/tone_text.dart';
import '../../../data/settings.dart';
import '../../../l10n/l10n.dart';
import '../exercise.dart';
import 'view_support.dart';

/// Build a sentence from tiles.
class OrderView extends ConsumerStatefulWidget {
  const OrderView({
    super.key,
    required this.exercise,
    required this.onAnswered,
  });

  final OrderExercise exercise;
  final AnswerCallback onAnswered;

  @override
  ConsumerState<OrderView> createState() => _OrderViewState();
}

class _OrderViewState extends ConsumerState<OrderView> {
  /// Indexes into `exercise.bank` in the order the learner placed them.
  final List<int> _placed = [];
  bool _checked = false;
  bool? _correct;

  OrderExercise get _ex => widget.exercise;

  void _place(int bankIndex) {
    if (_checked || _placed.contains(bankIndex)) return;
    setState(() => _placed.add(bankIndex));
  }

  void _remove(int bankIndex) {
    if (_checked) return;
    setState(() => _placed.remove(bankIndex));
  }

  void _check() {
    final built = [for (final i in _placed) _ex.bank[i]];
    var ok = built.length == _ex.answerTiles.length;
    for (var i = 0; ok && i < built.length; i++) {
      ok = built[i] == _ex.answerTiles[i];
    }
    setState(() {
      _checked = true;
      _correct = ok;
    });
    answerHaptic(ref, correct: ok);
    widget.onAnswered(ok, reveal: _ex.fullText);
    unawaited(teach(ref, _ex.fullText));
  }

  String? _tilePinyin(String tile) {
    final settings = ref.read(settingsProvider);
    if (settings.romanization == RomanizationMode.hidden) return null;
    final numeric = ref.read(pinyinLookupProvider)?.numericOf(tile);
    return numeric == null ? null : markPinyin(numeric);
  }

  Widget _tile(int bankIndex, {required bool inAnswer}) {
    final scheme = context.scheme;
    final colors = context.appColors;
    final text = _ex.bank[bankIndex];
    Color bg = scheme.surfaceContainerLowest;
    Color border = scheme.outlineVariant;
    if (_checked && inAnswer) {
      final position = _placed.indexOf(bankIndex);
      final right =
          position < _ex.answerTiles.length &&
          _ex.answerTiles[position] == text;
      bg = right ? colors.successContainer : scheme.errorContainer;
      border = right ? colors.success : scheme.error;
    }
    final py = _tilePinyin(text);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: inAnswer ? () => _remove(bankIndex) : () => _place(bankIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (py != null)
                Text(
                  py,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Text(text, style: const TextStyle(fontSize: 26, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final allPlaced = _placed.length == _ex.bank.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l.exOrderTitle,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _ex.translation,
          textAlign: TextAlign.center,
          style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: _placed.isEmpty
              ? Center(
                  child: Text(
                    l.exOrderTap,
                    style: context.text.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final i in _placed) _tile(i, inAnswer: true)],
                ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _ex.bank.length; i++)
              Opacity(
                opacity: _placed.contains(i) ? 0.25 : 1,
                child: _tile(i, inAnswer: false),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (_checked) ...[
          Center(
            child: Column(
              children: [
                ToneScript(_ex.fullText, style: const TextStyle(fontSize: 26)),
                RomanText(
                  _ex.romanization,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                SpeakButton(text: _ex.fullText, size: 48),
              ],
            ),
          ),
        ] else
          FilledButton(
            onPressed: allPlaced ? _check : null,
            child: Text(l.lessonCheck),
          ),
        if (_checked && _correct == false) const SizedBox(height: 4),
      ],
    );
  }
}
