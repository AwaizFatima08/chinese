import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/listener.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'pronunciation.dart';
import 'say_panel.dart';
import 'speak_content.dart';
import 'speak_steps.dart';
import 'step_views.dart';

/// Score given to a free answer that is on topic; its pronunciation is not
/// measured, only that the answer fits the question.
const talkFreeScore = 0.85;

/// Whether [heard] looks like an answer to [turn]: a few words, with at least
/// one of the turn's topic words. Total: never throws.
bool isOnTopic(TalkTurn turn, String heard) {
  final words = tokenize(heard);
  if (words.length < 3) return false;
  final spoken = words.toSet();
  for (final k in turn.keywords) {
    if (tokenize(k).every(spoken.contains)) return true;
  }
  return false;
}

/// One turn of a role-play: the partner's line, then the learner's reply,
/// either one of the model replies (scored word by word) or their own words.
class TalkTurnView extends ConsumerStatefulWidget {
  const TalkTurnView({super.key, required this.step, required this.onAnswered});

  final TalkTurnStep step;
  final StepAnswer onAnswered;

  @override
  ConsumerState<TalkTurnView> createState() => _TalkTurnViewState();
}

class _TalkTurnViewState extends ConsumerState<TalkTurnView> {
  int _picked = 0;
  bool _own = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(playEnglish(ref, widget.step.turn.say));
      }
    });
  }

  void _finish(bool passed, double accuracy) {
    if (_done) return;
    setState(() => _done = true);
    widget.onAnswered(passed, accuracy, reveal: widget.step.turn.replies.first);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final step = widget.step;
    final turn = step.turn;
    final replyPanel = _own
        ? _OwnReply(turn: turn, onDone: _finish)
        : SayPanel(
            key: ValueKey('say-$_picked'),
            target: turn.replies[_picked],
            passAt: 0.75,
            listenLimit: Duration(
              seconds: 6 + turn.replies[_picked].length ~/ 8,
            ),
            onDone: _finish,
          );
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: [
              Text(
                l.speakTalkTurn(step.number, step.total),
                textAlign: TextAlign.center,
                style: context.text.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _Bubble(
                who: step.partner,
                text: turn.say,
                color: scheme.secondaryContainer,
                trailing: PlayButton(text: turn.say, size: 44),
              ),
              if (!_own) ...[
                const SizedBox(height: 16),
                Text(
                  l.speakTalkChoose,
                  style: context.text.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < turn.replies.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ChoiceChip(
                      key: ValueKey('reply-$i'),
                      selected: _picked == i,
                      showCheckmark: false,
                      onSelected: _done
                          ? null
                          : (_) => setState(() => _picked = i),
                      label: Text(turn.replies[i]),
                      labelStyle: context.text.bodyMedium,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
              if (!_done)
                Center(
                  child: TextButton(
                    key: const ValueKey('toggle-own'),
                    onPressed: () => setState(() => _own = !_own),
                    child: Text(_own ? l.speakTalkModel : l.speakTalkOwn),
                  ),
                ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: replyPanel,
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.who,
    required this.text,
    required this.color,
    this.trailing,
  });

  final String who;
  final String text;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(who, style: context.text.labelMedium),
              const SizedBox(height: 2),
              Text(
                text,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

/// Free answer: the learner speaks in their own words; the reply passes when
/// it is on topic.
class _OwnReply extends ConsumerStatefulWidget {
  const _OwnReply({required this.turn, required this.onDone});

  final TalkTurn turn;
  final SayDone onDone;

  @override
  ConsumerState<_OwnReply> createState() => _OwnReplyState();
}

class _OwnReplyState extends ConsumerState<_OwnReply> {
  late final VoiceListener _listener;
  bool _micReady = true;
  bool _listening = false;
  bool _passed = false;
  String _partial = '';
  String? _heard;

  @override
  void initState() {
    super.initState();
    _listener = ref.read(voiceListenerProvider);
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final ok = await _listener.init(
      ref.read(settingsProvider).englishSttLocale,
    );
    if (mounted) setState(() => _micReady = ok);
  }

  @override
  void dispose() {
    unawaited(_listener.cancel());
    super.dispose();
  }

  Future<void> _listen() async {
    if (_listening || _passed) return;
    setState(() {
      _listening = true;
      _partial = '';
    });
    final r = await _listener.listenOnce(
      limit: const Duration(seconds: 10),
      onPartial: (p) {
        if (mounted) setState(() => _partial = p);
      },
    );
    if (!mounted) return;
    final ok = r.ok && isOnTopic(widget.turn, r.text);
    setState(() {
      _listening = false;
      _heard = r.ok ? r.text : '';
      _passed = ok;
    });
    if (ok) widget.onDone(true, talkFreeScore);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final words = widget.turn.keywords.take(4).join(', ');
    if (!_micReady) {
      return Column(
        children: [
          Text(l.speakNoMic, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _passed
                ? null
                : () {
                    setState(() => _passed = true);
                    widget.onDone(true, 0.7);
                  },
            child: Text(l.speakSelfCheck),
          ),
        ],
      );
    }
    return Column(
      children: [
        Text(
          l.speakTalkOwnHint(words),
          textAlign: TextAlign.center,
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          key: const ValueKey('own-mic'),
          onTap: _listen,
          child: CircleAvatar(
            radius: 44,
            backgroundColor: _listening ? scheme.error : scheme.primary,
            child: Icon(
              _listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              size: 44,
              color: scheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _listening
              ? (_partial.isEmpty ? l.speakListening : _partial)
              : l.speakTapMic,
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (_heard != null && _heard!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l.speakHeard(_heard!), textAlign: TextAlign.center),
        ],
        if (_heard != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _passed
                  ? l.speakTalkGood
                  : (_heard!.isEmpty
                        ? l.speakNothingHeard
                        : l.speakTalkOffTopic(words)),
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                color: _passed ? context.appColors.success : scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          l.speakTalkNoteOwn,
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (!_passed && _heard != null)
          TextButton(
            onPressed: () => widget.onDone(false, 0),
            child: Text(l.commonSkip),
          ),
      ],
    );
  }
}
