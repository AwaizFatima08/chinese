import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/audio_capture.dart';
import '../../core/services/listener.dart';
import '../../core/util/pcm.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import 'prosody.dart';
import 'speak_providers.dart';
import 'speak_steps.dart';
import 'step_views.dart';

enum _Stage { preparing, noModel, ready, recording, analysing, result }

/// Copy the melody, rhythm and pace of a sentence. The learner hears the
/// model voice, says the sentence, and the app compares the two recordings.
class MelodyView extends ConsumerStatefulWidget {
  const MelodyView({super.key, required this.step, required this.onAnswered});

  final MelodyStep step;
  final StepAnswer onAnswered;

  @override
  ConsumerState<MelodyView> createState() => _MelodyViewState();
}

class _MelodyViewState extends ConsumerState<MelodyView> {
  _Stage _stage = _Stage.preparing;
  Prosody? _model;
  MelodyScore? _score;
  double _level = 0;
  double _best = 0;
  bool _noPermission = false;
  bool _finished = false;
  final _scroll = ScrollController();
  late final AudioCapture _capture;
  late final VoiceListener _listener;

  @override
  void initState() {
    super.initState();
    _capture = ref.read(audioCaptureProvider);
    _listener = ref.read(voiceListenerProvider);
    unawaited(_prepare());
  }

  @override
  void dispose() {
    unawaited(_capture.cancel());
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the result card into view once it has been laid out.
  void _showResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _prepare() async {
    final locale = ref.read(settingsProvider).englishTtsLocale;
    final wav = await ref
        .read(speakerProvider)
        .synthesizeWav(widget.step.text, locale);
    final pcm = wav == null ? null : Pcm.fromWav(wav);
    Prosody? model;
    if (pcm != null) {
      model = await ref.read(prosodyAnalyzerProvider)(pcm);
    }
    if (!mounted) return;
    setState(() {
      _model = model;
      _stage = model == null ? _Stage.noModel : _Stage.ready;
    });
    if (model != null) {
      unawaited(playEnglish(ref, widget.step.text));
    }
  }

  void _finish(bool passed, double accuracy) {
    if (_finished) return;
    _finished = true;
    widget.onAnswered(passed, accuracy, reveal: widget.step.text);
  }

  Future<void> _record() async {
    if (_stage == _Stage.recording || _stage == _Stage.analysing) return;
    final model = _model;
    if (model == null || _finished) return;
    if (!await _capture.init()) {
      if (mounted) setState(() => _noPermission = true);
      return;
    }
    // One microphone user at a time, and no model voice in the recording.
    await ref.read(speakerProvider).stop();
    await _listener.cancel();
    if (ref.read(settingsProvider).haptics) {
      unawaited(HapticFeedback.selectionClick());
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.recording;
      _level = 0;
    });
    final pcm = await _capture.capture(
      onLevel: (v) {
        if (mounted) setState(() => _level = v);
      },
    );
    if (!mounted) return;
    setState(() => _stage = _Stage.analysing);
    final MelodyScore score;
    if (pcm == null) {
      score = const MelodyScore.noVoice();
    } else {
      final clock = Stopwatch()..start();
      final learner = await ref.read(prosodyAnalyzerProvider)(pcm);
      if (kDebugMode) {
        debugPrint('MELODY analysis ${clock.elapsedMilliseconds} ms');
      }
      score = compareProsody(model, learner);
      if (kDebugMode) {
        debugPrint(
          'MELODY melody=${score.melody.toStringAsFixed(2)} '
          'rhythm=${score.rhythm.toStringAsFixed(2)} '
          'pace=${score.pace.toStringAsFixed(2)} '
          'range=${score.rangeRatio.toStringAsFixed(2)} ${score.issue.name}',
        );
      }
    }
    if (!mounted) return;
    if (score.accuracy > _best) _best = score.accuracy;
    setState(() {
      _score = score;
      _stage = _Stage.result;
    });
    _showResult();
    if (score.passed) {
      if (ref.read(settingsProvider).haptics) {
        unawaited(HapticFeedback.lightImpact());
      }
      _finish(true, score.accuracy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final step = widget.step;
    final score = _score;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: [
              Text(
                l.speakMelodyHow,
                textAlign: TextAlign.center,
                style: context.text.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                step.text,
                textAlign: TextAlign.center,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: PlayButton(
                  text: step.text,
                  size: 52,
                  label: l.speakListenNormal,
                ),
              ),
              if (_stage == _Stage.preparing) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                Text(
                  l.speakMelodyPreparing,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
              ],
              if (_stage == _Stage.result && score != null) ...[
                const SizedBox(height: 14),
                _Result(score: score),
              ],
            ],
          ),
        ),
        if (!_finished)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _controls(context),
            ),
          ),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final l = context.l10n;
    final scheme = context.scheme;
    final busy = _stage == _Stage.recording || _stage == _Stage.analysing;
    switch (_stage) {
      case _Stage.preparing:
        return const SizedBox.shrink();
      case _Stage.noModel:
        return _fallback(context, l.speakMelodyNoModel);
      default:
        break;
    }
    if (_noPermission) return _fallback(context, l.speakMelodyNoPerm);

    final recording = _stage == _Stage.recording;
    final analysing = _stage == _Stage.analysing;
    final score = _score;
    return Column(
      children: [
        Semantics(
          button: true,
          label: l.speakMelodyRecord,
          child: GestureDetector(
            key: const ValueKey('melody-mic'),
            onTap: _finished || busy ? null : _record,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 80 + (recording ? _level * 16 : 0),
              height: 80 + (recording ? _level * 16 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recording
                    ? scheme.error
                    : _finished
                    ? scheme.surfaceContainerHighest
                    : scheme.primary,
              ),
              child: Icon(
                recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                size: 40,
                color: _finished ? scheme.onSurfaceVariant : scheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          analysing
              ? l.speakMelodyAnalysing
              : recording
              ? l.speakMelodyStop
              : l.speakMelodyRecord,
          textAlign: TextAlign.center,
          style: context.text.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (_stage == _Stage.result &&
            score != null &&
            !score.passed &&
            !_finished)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('melody-again'),
                onPressed: _record,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.speakTryAgain),
              ),
              TextButton(
                onPressed: () => _finish(false, _best),
                child: Text(l.commonSkip),
              ),
            ],
          )
        else if (_stage == _Stage.ready && !_finished)
          TextButton(
            onPressed: () => _finish(false, 0),
            child: Text(l.commonSkip),
          ),
        const SizedBox(height: 6),
        Text(
          l.speakMelodyNote,
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _fallback(BuildContext context, String message) => Column(
    children: [
      Text(
        message,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium,
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _finished ? null : () => _finish(true, 0.7),
        child: Text(context.l10n.speakSelfCheck),
      ),
    ],
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.score});

  final MelodyScore score;

  String _message(BuildContext context) {
    final l = context.l10n;
    return switch (score.issue) {
      MelodyIssue.none => l.speakMelodyOk,
      MelodyIssue.noVoice => l.speakMelodyNoVoice,
      MelodyIssue.flat => l.speakMelodyFlat,
      MelodyIssue.tooFast => l.speakMelodyFast,
      MelodyIssue.tooSlow => l.speakMelodySlow,
      MelodyIssue.melody => l.speakMelodyOff,
      MelodyIssue.rhythm => l.speakMelodyBeat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.appColors;
    final scheme = context.scheme;
    final ok = score.passed;
    final voiced = score.issue != MelodyIssue.noVoice;
    final paceOk =
        score.pace >= MelodyScore.paceLow && score.pace <= MelodyScore.paceHigh;
    return Column(
      children: [
        if (voiced)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _Check(
                l.speakMelodyMelody,
                score.melody >= MelodyScore.melodyPass &&
                    score.rangeRatio >= MelodyScore.minRange,
              ),
              _Check(
                l.speakMelodyRhythm,
                score.rhythm >= MelodyScore.rhythmPass,
              ),
              _Check(l.speakMelodyPace, paceOk),
            ],
          ),
        if (voiced && score.ref.isNotEmpty) ...[
          const SizedBox(height: 10),
          Semantics(
            label: '${l.speakMelodyModel} / ${l.speakMelodyYou}',
            child: SizedBox(
              height: 90,
              width: double.infinity,
              child: CustomPaint(
                painter: _CurvePainter(
                  model: score.ref,
                  you: score.learner,
                  modelColor: scheme.primary,
                  youColor: colors.gold,
                  grid: scheme.outlineVariant,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Key(l.speakMelodyModel, scheme.primary),
              const SizedBox(width: 16),
              _Key(l.speakMelodyYou, colors.gold),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _message(context),
          textAlign: TextAlign.center,
          style: context.text.titleMedium?.copyWith(
            color: ok ? colors.success : scheme.error,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.label, this.ok);

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? context.appColors.success : context.scheme.error;
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: color,
        size: 18,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 14, height: 4, color: color),
      const SizedBox(width: 6),
      Text(label, style: context.text.labelMedium),
    ],
  );
}

/// The model's pitch curve and the learner's, on one scale.
class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.model,
    required this.you,
    required this.modelColor,
    required this.youColor,
    required this.grid,
  });

  final List<double> model;
  final List<double> you;
  final Color modelColor;
  final Color youColor;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    var range = 6.0;
    for (final v in [...model, ...you]) {
      if (v.abs() > range) range = v.abs();
    }
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    void draw(List<double> v, Color c) {
      if (v.length < 2) return;
      final path = Path();
      for (var i = 0; i < v.length; i++) {
        final x = size.width * i / (v.length - 1);
        final y = mid - (v[i] / range) * (size.height / 2 - 4);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    draw(model, modelColor);
    draw(you, youColor);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.model != model || old.you != you;
}
