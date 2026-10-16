import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../languages/models.dart';
import 'stroke_matcher.dart';

/// A character parsed into drawable outlines and centre-lines, all in a
/// 1024x1024 y-down box.
class StrokeGlyph {
  StrokeGlyph._(this.outlines, this.medians);

  factory StrokeGlyph.from(StrokeData data) {
    // Source outlines are y-up; flip with y' = 900 - y.
    final flip = Matrix4(1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 0, 900, 0, 1);
    return StrokeGlyph._([
      for (final d in data.strokes) parseSvgPathData(d).transform(flip.storage),
    ], data.medians);
  }

  final List<Path> outlines;
  final List<List<Offset>> medians;

  int get count => outlines.length;
}

/// Lets the screen around a [StrokeBoard] trigger its demos.
class StrokeBoardController {
  _StrokeBoardState? _state;

  /// Plays the whole character stroke by stroke, then lets the learner trace.
  void watch() => _state?._watch();

  /// Shows the next stroke to draw.
  void hint() => _state?._hint();

  /// Clears the learner's strokes to start again.
  void reset() => _state?._reset();

  int get completedStrokes => _state?._completed ?? 0;
}

/// A square writing pad: a faint character guide, strokes the learner draws,
/// and animated demonstrations of stroke order and direction.
class StrokeBoard extends StatefulWidget {
  const StrokeBoard({
    super.key,
    required this.glyph,
    required this.controller,
    this.onStrokeAccepted,
    this.onMistake,
    this.onComplete,
    this.semanticLabel,
  });

  final StrokeGlyph glyph;
  final StrokeBoardController controller;

  /// Called with the number of strokes finished so far.
  final ValueChanged<int>? onStrokeAccepted;
  final VoidCallback? onMistake;

  /// Called with the total number of rejected strokes once all are drawn.
  final ValueChanged<int>? onComplete;
  final String? semanticLabel;

  @override
  State<StrokeBoard> createState() => _StrokeBoardState();
}

class _StrokeBoardState extends State<StrokeBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);
  int _completed = 0;
  int _mistakes = 0;
  int _strokeMistakes = 0;
  int _demoFrom = 0;
  int _demoTo = 0;
  bool _demoing = false;
  bool _flashWrong = false;
  List<Offset> _user = const [];
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _demoing = false);
      }
    });
  }

  @override
  void didUpdateWidget(StrokeBoard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._state = this;
    }
    if (!identical(old.glyph, widget.glyph)) _reset();
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _flashTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _watch() {
    setState(() {
      _completed = 0;
      _user = const [];
      _demoFrom = 0;
      _demoTo = widget.glyph.count;
      _demoing = true;
    });
    _anim.duration = Duration(milliseconds: 750 * widget.glyph.count + 300);
    unawaited(_anim.forward(from: 0));
  }

  void _hint() {
    if (_completed >= widget.glyph.count || _demoing) return;
    setState(() {
      _demoFrom = _completed;
      _demoTo = _completed + 1;
      _demoing = true;
    });
    _anim.duration = const Duration(milliseconds: 900);
    unawaited(_anim.forward(from: 0));
  }

  void _reset() {
    _anim.stop();
    setState(() {
      _completed = 0;
      _mistakes = 0;
      _strokeMistakes = 0;
      _user = const [];
      _demoing = false;
    });
  }

  Offset _toGlyph(Offset local, double side) => local * (1024 / side);

  void _down(PointerDownEvent e, double side) {
    if (_demoing || _completed >= widget.glyph.count) return;
    setState(() {
      _user = [_toGlyph(e.localPosition, side)];
      _flashWrong = false;
    });
  }

  void _move(PointerMoveEvent e, double side) {
    if (_user.isEmpty) return;
    final p = _toGlyph(e.localPosition, side);
    if ((p - _user.last).distance < 6) return;
    setState(() => _user = [..._user, p]);
  }

  void _up(PointerUpEvent e) {
    if (_user.isEmpty) return;
    final drawn = _user;
    if (StrokeMatcher.length(drawn) < 40) {
      setState(() => _user = const []);
      return;
    }
    final ok = StrokeMatcher.matches(drawn, widget.glyph.medians[_completed]);
    if (ok) {
      setState(() {
        _completed++;
        _strokeMistakes = 0;
        _user = const [];
      });
      widget.onStrokeAccepted?.call(_completed);
      if (_completed >= widget.glyph.count) widget.onComplete?.call(_mistakes);
    } else {
      _mistakes++;
      _strokeMistakes++;
      widget.onMistake?.call();
      setState(() => _flashWrong = true);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            _user = const [];
            _flashWrong = false;
          });
        }
      });
      if (_strokeMistakes >= 3) {
        _strokeMistakes = 0;
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _hint();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return Semantics(
            label: widget.semanticLabel,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _down(e, side),
              onPointerMove: (e) => _move(e, side),
              onPointerUp: _up,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    border: Border.all(color: scheme.outlineVariant, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _BoardPainter(
                        glyph: widget.glyph,
                        completed: _completed,
                        demoing: _demoing,
                        demoFrom: _demoFrom,
                        demoTo: _demoTo,
                        user: _user,
                        wrong: _flashWrong,
                        ink: scheme.onSurface,
                        ghost: scheme.outlineVariant.withValues(alpha: 0.55),
                        grid: scheme.outlineVariant,
                        accent: scheme.primary,
                        error: scheme.error,
                        anim: _anim,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.glyph,
    required this.completed,
    required this.demoing,
    required this.demoFrom,
    required this.demoTo,
    required this.user,
    required this.wrong,
    required this.ink,
    required this.ghost,
    required this.grid,
    required this.accent,
    required this.error,
    required this.anim,
  }) : super(repaint: anim);

  final StrokeGlyph glyph;
  final int completed;
  final bool demoing;
  final int demoFrom;
  final int demoTo;
  final List<Offset> user;
  final bool wrong;
  final Color ink;
  final Color ghost;
  final Color grid;
  final Color accent;
  final Color error;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 1024);
    _paintGrid(canvas);

    final fill = Paint()..style = PaintingStyle.fill;
    for (final outline in glyph.outlines) {
      canvas.drawPath(outline, fill..color = ghost);
    }

    if (demoing) {
      final span = (demoTo - demoFrom).toDouble();
      final progress = anim.value * span;
      final index = math.min(demoFrom + progress.floor(), demoTo - 1);
      final t = anim.value >= 1 ? 1.0 : progress - progress.floor();
      // Strokes before the demonstrated one are solid.
      final solidUpTo = demoFrom == 0 ? index : completed;
      for (var i = 0; i < solidUpTo; i++) {
        canvas.drawPath(glyph.outlines[i], fill..color = ink);
      }
      _paintPartial(canvas, index, t, accent);
    } else {
      for (var i = 0; i < completed; i++) {
        canvas.drawPath(glyph.outlines[i], fill..color = ink);
      }
    }

    if (user.length > 1) {
      final line = Path()..moveTo(user.first.dx, user.first.dy);
      for (final p in user.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 36
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = (wrong ? error : accent).withValues(alpha: 0.75),
      );
    }
    canvas.restore();
  }

  void _paintPartial(Canvas canvas, int index, double t, Color color) {
    if (index < 0 || index >= glyph.count) return;
    final median = glyph.medians[index];
    final path = Path()..moveTo(median.first.dx, median.first.dy);
    for (final p in median.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Reveal the outline only where the pen has already passed: clip to a
    // chain of discs laid along the centre-line up to the pen position.
    final reveal = Path();
    for (final m in path.computeMetrics()) {
      final end = m.length * t;
      for (var d = 0.0; d <= end; d += 14) {
        final tangent = m.getTangentForOffset(d);
        if (tangent != null) {
          reveal.addOval(Rect.fromCircle(center: tangent.position, radius: 95));
        }
      }
      final tip = m.getTangentForOffset(end);
      if (tip != null) {
        reveal.addOval(Rect.fromCircle(center: tip.position, radius: 95));
      }
    }
    canvas
      ..save()
      ..clipPath(reveal)
      ..drawPath(glyph.outlines[index], Paint()..color = color)
      ..restore();
    // A dot marks where this stroke begins.
    canvas.drawCircle(
      median.first,
      26,
      Paint()..color = color.withValues(alpha: 0.9),
    );
  }

  void _paintGrid(Canvas canvas) {
    final paint = Paint()
      ..color = grid.withValues(alpha: 0.7)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    void dashed(Offset a, Offset b) {
      const dash = 28.0;
      const gap = 22.0;
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        final end = math.min(d + dash, total);
        canvas.drawLine(a + dir * d, a + dir * end, paint);
        d += dash + gap;
      }
    }

    dashed(const Offset(0, 512), const Offset(1024, 512));
    dashed(const Offset(512, 0), const Offset(512, 1024));
    dashed(Offset.zero, const Offset(1024, 1024));
    dashed(const Offset(1024, 0), const Offset(0, 1024));
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.completed != completed ||
      old.demoing != demoing ||
      old.demoFrom != demoFrom ||
      old.demoTo != demoTo ||
      old.user != user ||
      old.wrong != wrong ||
      old.glyph != glyph ||
      old.ink != ink;
}
