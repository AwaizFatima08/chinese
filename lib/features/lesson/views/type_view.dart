import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/speak_button.dart';
import '../../../core/widgets/tone_text.dart';
import '../../../l10n/l10n.dart';
import '../exercise.dart';
import 'view_support.dart';

/// Spelling practice: hear a word and type it.
class TypeView extends ConsumerStatefulWidget {
  const TypeView({super.key, required this.exercise, required this.onAnswered});

  final TypeExercise exercise;
  final AnswerCallback onAnswered;

  @override
  ConsumerState<TypeView> createState() => _TypeViewState();
}

class _TypeViewState extends ConsumerState<TypeView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _checked = false;
  bool _correct = false;

  /// Letters a non-German keyboard makes awkward.
  static const _special = ['ä', 'ö', 'ü', 'ß'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(teach(ref, widget.exercise.word.text));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Comparison form: case-insensitive, extra spaces ignored, and the
  /// transliterations ae/oe/ue/ss accepted for ä/ö/ü/ß.
  static String fold(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');

  void _insert(String letter) {
    final value = _controller.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    final text = value.text.replaceRange(start, end, letter);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + letter.length),
    );
  }

  void _check() {
    final word = widget.exercise.word;
    final ok = fold(_controller.text) == fold(word.text);
    _focus.unfocus();
    setState(() {
      _checked = true;
      _correct = ok;
    });
    answerHaptic(ref, correct: ok);
    widget.onAnswered(ok, reveal: word.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final word = widget.exercise.word;
    final canCheck = _controller.text.trim().isNotEmpty && !_checked;
    final capitalSlip =
        _checked &&
        _correct &&
        word.article != null &&
        _controller.text.trim().isNotEmpty &&
        _controller.text.trim().split(' ').last[0] ==
            _controller.text.trim().split(' ').last[0].toLowerCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l.exTypeTitle,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpeakButton(text: word.text, size: 72, label: l.exListenNormal),
            const SizedBox(width: 24),
            SpeakButton(
              text: word.text,
              slow: true,
              size: 56,
              label: l.exListenSlow,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          word.primaryMeaning,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: !_checked,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (canCheck) _check();
          },
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\n\t]')),
          ],
          style: const TextStyle(fontSize: 26),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: l.exTypeField,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in _special)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  onPressed: _checked ? null : () => _insert(c),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(56, 52),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(c, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_checked) ...[
          Center(
            child: Column(
              children: [
                ScriptText(
                  word.text,
                  article: word.article,
                  style: const TextStyle(fontSize: 30),
                ),
                if (word.note.isNotEmpty)
                  Text(word.note, style: context.text.bodyMedium),
                if (capitalSlip)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(l.exTypeHint, style: context.text.bodyMedium),
                  ),
              ],
            ),
          ),
        ] else
          FilledButton(
            onPressed: canCheck ? _check : null,
            child: Text(l.lessonCheck),
          ),
      ],
    );
  }
}
