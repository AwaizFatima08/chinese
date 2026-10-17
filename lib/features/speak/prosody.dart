import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/util/pcm.dart';

/// Frame-by-frame pitch and loudness of one recording.
class Prosody {
  const Prosody({
    required this.f0,
    required this.rms,
    required this.hopSeconds,
    required this.gate,
  });

  /// Fundamental frequency per frame in Hz, 0 where there is no clear voice.
  final List<double> f0;

  /// Loudness per frame.
  final List<double> rms;
  final double hopSeconds;

  /// Loudness above which a frame counts as speech.
  final double gate;

  int get frames => f0.length;
}

/// Pitch (YIN) and loudness of [pcm]. Pure and total: silence gives frames
/// with no pitch.
Prosody extractProsody(Pcm pcm) {
  const rate = 8000;
  final x = pcm.resampled(rate).samples;
  const hop = 80; // 10 ms
  const win = 320; // 40 ms
  const tauMin = 20; // 400 Hz
  const tauMax = 125; // 64 Hz
  final frames = x.length >= win + tauMax
      ? (x.length - win - tauMax) ~/ hop
      : 0;
  final rms = List<double>.filled(frames, 0);
  for (var k = 0; k < frames; k++) {
    var e = 0.0;
    final s = k * hop;
    for (var j = 0; j < win; j++) {
      e += x[s + j] * x[s + j];
    }
    rms[k] = math.sqrt(e / win);
  }
  final sorted = [...rms]..sort();
  final p95 = sorted.isEmpty ? 0.0 : sorted[(sorted.length * 0.95).floor()];
  // Speech is well above the room's noise: at least 15% of the loud parts
  // and four times the quietest tenth.
  final quiet = sorted.isEmpty ? 0.0 : sorted[(sorted.length * 0.1).floor()];
  final gate = math.max(
    0.004,
    math.max(p95 * 0.15, math.min(quiet * 4, p95 * 0.5)),
  );

  final f0 = List<double>.filled(frames, 0);
  final d = Float64List(tauMax + 2);
  final cmnd = Float64List(tauMax + 2);
  for (var k = 0; k < frames; k++) {
    if (rms[k] < gate) continue;
    final s = k * hop;
    for (var tau = 1; tau <= tauMax + 1; tau++) {
      var sum = 0.0;
      for (var j = 0; j < win; j++) {
        final diff = x[s + j] - x[s + j + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }
    var running = 0.0;
    cmnd[0] = 1;
    for (var tau = 1; tau <= tauMax + 1; tau++) {
      running += d[tau];
      cmnd[tau] = running == 0 ? 1 : d[tau] * tau / running;
    }
    var best = -1;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (cmnd[tau] < 0.2) {
        while (tau + 1 <= tauMax && cmnd[tau + 1] < cmnd[tau]) {
          tau++;
        }
        best = tau;
        break;
      }
    }
    if (best < 0) {
      var lowest = 1.0;
      for (var tau = tauMin; tau <= tauMax; tau++) {
        if (cmnd[tau] < lowest) {
          lowest = cmnd[tau];
          best = tau;
        }
      }
      if (lowest > 0.3) best = -1;
    }
    if (best < 0) continue;
    var tau = best.toDouble();
    if (best > 1 && best < tauMax + 1) {
      final a = cmnd[best - 1];
      final b = cmnd[best];
      final c = cmnd[best + 1];
      final denom = a - 2 * b + c;
      if (denom.abs() > 1e-9) tau += 0.5 * (a - c) / denom;
    }
    f0[k] = rate / tau;
  }
  return Prosody(f0: f0, rms: rms, hopSeconds: hop / rate, gate: gate);
}

/// What the comparison found, most important first.
enum MelodyIssue { none, noVoice, flat, tooFast, tooSlow, melody, rhythm }

/// How closely a learner followed the model's melody and rhythm.
class MelodyScore {
  const MelodyScore({
    required this.melody,
    required this.rhythm,
    required this.pace,
    required this.rangeRatio,
    required this.issue,
    required this.ref,
    required this.learner,
  });

  const MelodyScore.noVoice()
    : melody = 0,
      rhythm = 0,
      pace = 0,
      rangeRatio = 0,
      issue = MelodyIssue.noVoice,
      ref = const [],
      learner = const [];

  /// 0..1: how well the rises and falls of the voice match.
  final double melody;

  /// 0..1: how well the beat of loud and quiet matches.
  final double rhythm;

  /// Learner's speaking time divided by the model's.
  final double pace;

  /// How wide the learner's pitch moves compared with the model's.
  final double rangeRatio;
  final MelodyIssue issue;

  /// The two pitch curves in semitones around each speaker's own average,
  /// resampled to the same length, for drawing.
  final List<double> ref;
  final List<double> learner;

  bool get passed => issue == MelodyIssue.none;

  /// Overall 0..1 accuracy.
  double get accuracy {
    if (issue == MelodyIssue.noVoice) return 0;
    final paceScore = pace >= paceLow && pace <= paceHigh
        ? 1.0
        : (1 - ((pace < 1 ? 1 / pace : pace) - 1.4).abs().clamp(0, 1))
              .toDouble();
    return (0.5 * melody + 0.3 * rhythm + 0.2 * paceScore).clamp(0, 1);
  }

  static const paceLow = 0.7;
  static const paceHigh = 1.5;
  static const melodyPass = 0.7;
  static const rhythmPass = 0.6;
  static const minRange = 0.4;
}

const _points = 64;

/// The measurements behind a [MelodyScore], for tuning.
typedef MelodyFeatures = ({
  double corr,
  double dist,
  double endGap,
  double beatMatch,
  double beatRatio,
  double energyDist,
});

/// Points the curves may drift from a straight time match (about 8%).
const _band = 5;

/// How far apart two beats may be (share of the sentence) and still match.
const _beatTolerance = 0.06;

MelodyFeatures _melodyFeatures(_Curve r, _Curve l) {
  final m = _dtw(r.pitch, l.pitch, _band);
  final e = _dtw(r.energy, l.energy, _band);
  final most = math.max(r.beats.length, l.beats.length);
  return (
    corr: m.corr,
    dist: m.dist,
    endGap: (_endMove(r.pitch) - _endMove(l.pitch)).abs(),
    beatMatch: _beatMatch(r.beats, l.beats),
    beatRatio: most == 0
        ? 0.0
        : math.min(r.beats.length, l.beats.length) / most,
    energyDist: e.dist,
  );
}

/// Semitones the voice moves over the last fifth of the sentence, compared
/// with the fifth before it: positive for a rise, negative for a fall.
double _endMove(List<double> pitch) {
  final n = pitch.length;
  final cut = (n * 0.2).round();
  double mean(int from, int to) {
    var s = 0.0;
    for (var i = from; i < to; i++) {
      s += pitch[i];
    }
    return s / (to - from);
  }

  return mean(n - cut, n) - mean(n - 2 * cut, n - cut);
}

/// Share of beats that have a partner in the other recording at about the
/// same place (an F-score, 0..1).
double _beatMatch(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final used = List<bool>.filled(b.length, false);
  var matched = 0;
  for (final x in a) {
    var best = -1;
    var bestGap = _beatTolerance;
    for (var j = 0; j < b.length; j++) {
      final gap = (b[j] - x).abs();
      if (!used[j] && gap <= bestGap) {
        best = j;
        bestGap = gap;
      }
    }
    if (best >= 0) {
      used[best] = true;
      matched++;
    }
  }
  return 2 * matched / (a.length + b.length);
}

/// Compares the learner's recording with the model reading.
MelodyScore compareProsody(Prosody ref, Prosody learner) {
  final r = _Curve.of(ref);
  final l = _Curve.of(learner);
  if (l == null || r == null) return const MelodyScore.noVoice();

  final pace = l.seconds / r.seconds;
  final f = _melodyFeatures(r, l);
  // Melody: do the rises and falls agree, how far apart are the curves, and
  // does the sentence end the same way (a question rising, a statement
  // falling)?
  final melody =
      (0.45 * f.corr.clamp(0.0, 1.0) +
              0.25 * (1 - f.dist / 4).clamp(0.0, 1.0) +
              0.30 * (1 - f.endGap / 5).clamp(0.0, 1.0))
          .clamp(0.0, 1.0);
  // Rhythm: the syllable beats fall in the same places, and there are about
  // as many of them.
  final rhythm =
      (0.6 * f.beatMatch +
              0.25 * ((f.beatRatio - 0.5) / 0.4).clamp(0.0, 1.0) +
              0.15 * (1 - f.energyDist / 0.35).clamp(0.0, 1.0))
          .clamp(0.0, 1.0);
  final rangeRatio = r.spread < 0.8 ? 1.0 : l.spread / r.spread;

  var issue = MelodyIssue.none;
  if (pace > MelodyScore.paceHigh) {
    issue = MelodyIssue.tooSlow;
  } else if (pace < MelodyScore.paceLow) {
    issue = MelodyIssue.tooFast;
  } else if (rangeRatio < MelodyScore.minRange) {
    issue = MelodyIssue.flat;
  } else if (melody < MelodyScore.melodyPass) {
    issue = MelodyIssue.melody;
  } else if (rhythm < MelodyScore.rhythmPass) {
    issue = MelodyIssue.rhythm;
  }
  return MelodyScore(
    melody: melody,
    rhythm: rhythm,
    pace: pace,
    rangeRatio: rangeRatio,
    issue: issue,
    ref: r.pitch,
    learner: l.pitch,
  );
}

/// One recording reduced to a pitch curve and a loudness curve of
/// [_points] samples each, over the stretch where someone is speaking.
class _Curve {
  _Curve(this.pitch, this.energy, this.seconds, this.spread, this.beats);

  final List<double> pitch;

  /// Positions (0..1 along the speech) of the loudness peaks, roughly one
  /// per syllable.
  final List<double> beats;
  final List<double> energy;
  final double seconds;
  final double spread;

  static _Curve? of(Prosody p) {
    final extent = _speechExtent(p);
    if (extent == null) return null;
    final (first, last) = extent;

    final voiced = <double>[
      for (var i = first; i <= last; i++)
        if (p.f0[i] > 0) p.f0[i],
    ];
    if (voiced.length < 15) return null;
    final sortedHz = [...voiced]..sort();
    final median = sortedHz[sortedHz.length ~/ 2];

    // Semitones around the speaker's own median; null where unvoiced.
    final st = <double?>[
      for (var i = first; i <= last; i++)
        p.f0[i] > 0 ? 12 * math.log(p.f0[i] / median) / math.ln2 : null,
    ];
    _dropOctaveJumps(st);
    _medianFilter(st);
    final filled = _fill(st);
    if (filled == null) return null;

    final env = <double>[
      for (var i = first; i <= last; i++) math.sqrt(p.rms[i]),
    ];
    final smooth = _smooth(env, 5);
    final peak = smooth.reduce(math.max);
    final energy = [for (final v in smooth) peak == 0 ? 0.0 : v / peak];

    final pitch = _resample(filled, _points);
    final mean = pitch.reduce((a, b) => a + b) / pitch.length;
    final centred = [for (final v in pitch) v - mean];
    var varSum = 0.0;
    for (final v in centred) {
      varSum += v * v;
    }
    final spread = math.sqrt(varSum / centred.length);
    return _Curve(
      centred,
      _resample(energy, _points),
      (last - first + 1) * p.hopSeconds,
      spread,
      _beats(smooth),
    );
  }
}

/// The first and last frame of the main stretch of speech: loud frames are
/// grouped when less than 0.4 s apart and the group with most sound wins, so
/// a click or a cough before or after the sentence is left out.
(int, int)? _speechExtent(Prosody p) {
  final join = (0.4 / p.hopSeconds).round();
  var bestFirst = -1;
  var bestLast = -1;
  var bestSum = 0.0;
  var first = -1;
  var last = -1;
  var sum = 0.0;
  void close() {
    if (first >= 0 && sum > bestSum) {
      bestSum = sum;
      bestFirst = first;
      bestLast = last;
    }
    first = -1;
    sum = 0;
  }

  for (var i = 0; i < p.frames; i++) {
    if (p.rms[i] < p.gate) continue;
    if (first >= 0 && i - last > join) close();
    if (first < 0) first = i;
    last = i;
    sum += p.rms[i];
  }
  close();
  if (bestFirst < 0 || bestLast - bestFirst < 20) return null;
  return (bestFirst, bestLast);
}

/// Loudness peaks of [env] that stand clear of the dips around them.
List<double> _beats(List<double> env) {
  if (env.length < 10) return const [];
  final peak = env.reduce(math.max);
  final out = <int>[];
  const reach = 6;
  for (var i = 0; i < env.length; i++) {
    if (env[i] < 0.3 * peak) continue;
    var top = true;
    for (
      var j = math.max(0, i - reach);
      j <= math.min(env.length - 1, i + reach);
      j++
    ) {
      if (env[j] > env[i] || (env[j] == env[i] && j < i)) {
        top = false;
        break;
      }
    }
    if (!top) continue;
    if (out.isNotEmpty) {
      final prev = out.last;
      var dip = env[prev];
      for (var j = prev; j <= i; j++) {
        dip = math.min(dip, env[j]);
      }
      // Two peaks only count as separate if the loudness really dips between.
      if (dip > 0.75 * math.min(env[prev], env[i])) {
        if (env[i] > env[prev]) out[out.length - 1] = i;
        continue;
      }
    }
    out.add(i);
  }
  return [for (final i in out) i / (env.length - 1)];
}

void _dropOctaveJumps(List<double?> st) {
  for (var i = 0; i < st.length; i++) {
    final v = st[i];
    if (v == null) continue;
    final near = <double>[
      for (var j = math.max(0, i - 4); j <= math.min(st.length - 1, i + 4); j++)
        if (j != i && st[j] != null) st[j]!,
    ];
    if (near.length < 2) continue;
    near.sort();
    if ((v - near[near.length ~/ 2]).abs() > 7) st[i] = null;
  }
}

void _medianFilter(List<double?> st) {
  final copy = [...st];
  for (var i = 0; i < st.length; i++) {
    if (copy[i] == null) continue;
    final w = <double>[
      for (var j = math.max(0, i - 2); j <= math.min(st.length - 1, i + 2); j++)
        if (copy[j] != null) copy[j]!,
    ]..sort();
    st[i] = w[w.length ~/ 2];
  }
}

/// Joins gaps with straight lines and extends the ends.
List<double>? _fill(List<double?> st) {
  final idx = [
    for (var i = 0; i < st.length; i++)
      if (st[i] != null) i,
  ];
  if (idx.length < 10) return null;
  final out = List<double>.filled(st.length, 0);
  for (var i = 0; i < st.length; i++) {
    if (st[i] != null) {
      out[i] = st[i]!;
      continue;
    }
    final before = idx.lastWhere((j) => j < i, orElse: () => -1);
    final after = idx.firstWhere((j) => j > i, orElse: () => -1);
    if (before < 0) {
      out[i] = st[after]!;
    } else if (after < 0) {
      out[i] = st[before]!;
    } else {
      final t = (i - before) / (after - before);
      out[i] = st[before]! + (st[after]! - st[before]!) * t;
    }
  }
  return out;
}

List<double> _smooth(List<double> v, int width) {
  final half = width ~/ 2;
  return [
    for (var i = 0; i < v.length; i++)
      () {
        var s = 0.0;
        var n = 0;
        for (
          var j = math.max(0, i - half);
          j <= math.min(v.length - 1, i + half);
          j++
        ) {
          s += v[j];
          n++;
        }
        return s / n;
      }(),
  ];
}

List<double> _resample(List<double> v, int n) {
  if (v.length == 1) return List<double>.filled(n, v.first);
  return [
    for (var i = 0; i < n; i++)
      () {
        final pos = i * (v.length - 1) / (n - 1);
        final lo = pos.floor();
        final hi = math.min(lo + 1, v.length - 1);
        return v[lo] + (v[hi] - v[lo]) * (pos - lo);
      }(),
  ];
}

/// Mean absolute difference along the best alignment of [a] and [b], where
/// each point may drift at most [band] places from the straight diagonal.
({double dist, double corr}) _dtw(List<double> a, List<double> b, int band) {
  final n = a.length;
  final m = b.length;
  const inf = double.infinity;
  final cost = List.generate(n, (_) => List<double>.filled(m, inf));
  final steps = List.generate(n, (_) => List<int>.filled(m, 0));
  final from = List.generate(n, (_) => List<int>.filled(m, -1));
  for (var i = 0; i < n; i++) {
    for (var j = math.max(0, i - band); j <= math.min(m - 1, i + band); j++) {
      final c = (a[i] - b[j]).abs();
      if (i == 0 && j == 0) {
        cost[i][j] = c;
        steps[i][j] = 1;
        continue;
      }
      var best = inf;
      var bestSteps = 0;
      var bestFrom = -1;
      void tryFrom(int pi, int pj) {
        if (pi < 0 || pj < 0) return;
        if (cost[pi][pj] < best) {
          best = cost[pi][pj];
          bestSteps = steps[pi][pj];
          bestFrom = pi * m + pj;
        }
      }

      tryFrom(i - 1, j);
      tryFrom(i, j - 1);
      tryFrom(i - 1, j - 1);
      if (best == inf) continue;
      cost[i][j] = best + c;
      steps[i][j] = bestSteps + 1;
      from[i][j] = bestFrom;
    }
  }
  final total = cost[n - 1][m - 1];
  if (total == inf) return (dist: 99, corr: -1);
  // Correlation along the best path: do the rises and falls agree?
  var i = n - 1;
  var j = m - 1;
  var sa = 0.0, sb = 0.0, saa = 0.0, sbb = 0.0, sab = 0.0;
  var count = 0;
  while (i >= 0 && j >= 0) {
    sa += a[i];
    sb += b[j];
    saa += a[i] * a[i];
    sbb += b[j] * b[j];
    sab += a[i] * b[j];
    count++;
    final f = from[i][j];
    if (f < 0) break;
    i = f ~/ m;
    j = f % m;
  }
  final cov = sab / count - (sa / count) * (sb / count);
  final va = saa / count - (sa / count) * (sa / count);
  final vb = sbb / count - (sb / count) * (sb / count);
  final corr = va <= 1e-9 || vb <= 1e-9 ? 0.0 : cov / math.sqrt(va * vb);
  return (dist: total / steps[n - 1][m - 1], corr: corr);
}
