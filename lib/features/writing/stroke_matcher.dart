import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Decides whether a stroke the learner drew matches the expected stroke.
///
/// All points live in the 1024x1024 character box. The check is deliberately
/// forgiving: a finger is not a brush. It still insists on the right place,
/// shape and direction, because stroke direction is part of writing.
class StrokeMatcher {
  const StrokeMatcher._();

  /// Total length of the polyline through [points].
  static double length(List<Offset> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }

  /// The point a fraction [f] (0..1) of the way along [points].
  static Offset pointAt(List<Offset> points, double f) {
    if (points.length == 1) return points.first;
    final target = length(points) * f.clamp(0, 1);
    var walked = 0.0;
    for (var i = 1; i < points.length; i++) {
      final seg = (points[i] - points[i - 1]).distance;
      if (walked + seg >= target && seg > 0) {
        final t = (target - walked) / seg;
        return Offset.lerp(points[i - 1], points[i], t)!;
      }
      walked += seg;
    }
    return points.last;
  }

  /// [n] evenly spaced points along [points].
  static List<Offset> resample(List<Offset> points, int n) => [
    for (var i = 0; i < n; i++) pointAt(points, i / (n - 1)),
  ];

  /// True when [drawn] is a good enough attempt at [median].
  static bool matches(
    List<Offset> drawn,
    List<Offset> median, {
    double tolerance = 210,
  }) {
    if (drawn.length < 2 || median.length < 2) return false;
    final drawnLength = length(drawn);
    final medianLength = length(median);
    if (drawnLength < math.max(0.3 * medianLength, 45)) return false;

    if ((drawn.first - median.first).distance > tolerance) return false;
    if ((drawn.last - median.last).distance > tolerance) return false;

    final expected = median.last - median.first;
    final actual = drawn.last - drawn.first;
    if (expected.distance > 120 && actual.distance > 0) {
      final cos =
          (expected.dx * actual.dx + expected.dy * actual.dy) /
          (expected.distance * actual.distance);
      if (cos < 0.3) return false;
    }

    // Shape: points along the expected stroke must lie near the drawn one.
    final dense = resample(drawn, 48);
    var worst = 0.0;
    var sum = 0.0;
    const samples = 6;
    for (var i = 0; i < samples; i++) {
      final p = pointAt(median, i / (samples - 1));
      final d = dense.map((q) => (q - p).distance).reduce(math.min);
      worst = math.max(worst, d);
      sum += d;
    }
    return sum / samples <= tolerance * 0.55 && worst <= tolerance * 0.85;
  }
}
