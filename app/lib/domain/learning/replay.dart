/// Offline replay of past decisions against any scorer ("progressive
/// validation"): each event is first predicted, then learned from, so every
/// score is made without knowing its own answer.
///
/// Pure Dart. Nothing here knows which model is under test.
library;

import 'dart:math' as math;

import '../models/title.dart';

/// One past decision as training and test material.
class ReplayEvent {
  const ReplayEvent(
    this.title,
    this.label, {
    this.weight = 1,
    required this.at,
  });

  final Title title;

  /// 1 when the person wanted the title, 0 when not.
  final double label;

  /// How much the event counts when learning and in [ReplayReport.logLoss].
  final double weight;
  final DateTime at;
}

/// Any scorer under test: predict BEFORE learning from the event, then learn.
abstract class ReplayScorer {
  /// The chance, 0 to 1, that the person wants [t].
  double predict(Title t);

  void learn(Title t, double label, double weight);
}

/// The trivial baseline: always predicts the running (weighted) base rate,
/// 0.5 before it has seen anything.
class ConstantScorer implements ReplayScorer {
  double _positive = 0;
  double _total = 0;

  @override
  double predict(Title t) => _total <= 0 ? 0.5 : _positive / _total;

  @override
  void learn(Title t, double label, double weight) {
    _positive += label * weight;
    _total += weight;
  }
}

class ReplayReport {
  const ReplayReport({
    required this.events,
    required this.positives,
    required this.auc,
    required this.logLoss,
    required this.precisionAt10,
    required this.baseRate,
  });

  /// Scored events (warmup excluded).
  final int events;

  /// Scored events with a positive label.
  final int positives;

  /// Chance a positive was scored above a negative; 0.5 when undefined
  /// (all one class). Unweighted.
  final double auc;

  /// Mean negative log likelihood, probabilities clipped away from 0 and 1,
  /// each event counted by its weight. 0 when nothing was scored.
  final double logLoss;

  /// Within consecutive windows of 10 scored events, the share of positives
  /// among the 3 highest scored, averaged over the windows. A trailing
  /// partial window is left out, unless it is the only one.
  final double precisionAt10;

  /// positives / events, 0 when nothing was scored.
  final double baseRate;

  Map<String, Object?> toJson() => {
    'events': events,
    'positives': positives,
    'auc': auc,
    'logLoss': logLoss,
    'precisionAt10': precisionAt10,
    'baseRate': baseRate,
  };
}

const _clip = 1e-6;
const _window = 10;
const _top = 3;

bool _positive(double label) => label >= 0.5;

/// Events are processed in time order; the first [warmup] events only train.
ReplayReport replay(
  List<ReplayEvent> events,
  ReplayScorer scorer, {
  int warmup = 20,
}) {
  // List.sort is not stable, so equal times keep their given order by index.
  final order = List<int>.generate(events.length, (i) => i)
    ..sort((a, b) {
      final byTime = events[a].at.compareTo(events[b].at);
      return byTime != 0 ? byTime : a.compareTo(b);
    });

  final scores = <double>[];
  final labels = <double>[];
  var lossSum = 0.0;
  var weightSum = 0.0;
  var seen = 0;
  for (final i in order) {
    final e = events[i];
    if (seen++ >= warmup) {
      final raw = scorer.predict(e.title);
      final p = raw.isNaN ? 0.5 : raw.clamp(_clip, 1 - _clip).toDouble();
      scores.add(raw.isNaN ? 0.5 : raw);
      labels.add(e.label);
      lossSum +=
          -e.weight * (e.label * math.log(p) + (1 - e.label) * math.log(1 - p));
      weightSum += e.weight;
    }
    scorer.learn(e.title, e.label, e.weight);
  }

  final positives = labels.where(_positive).length;
  return ReplayReport(
    events: scores.length,
    positives: positives,
    auc: auc(scores, labels),
    logLoss: weightSum > 0 ? lossSum / weightSum : 0,
    precisionAt10: _precisionAtTop(scores, labels),
    baseRate: scores.isEmpty ? 0 : positives / scores.length,
  );
}

double _precisionAtTop(List<double> scores, List<double> labels) {
  final n = scores.length;
  if (n == 0) return 0;
  var sum = 0.0;
  var windows = 0;
  for (var start = 0; start < n; start += _window) {
    final end = math.min(start + _window, n);
    if (end - start < _window && windows > 0) break;
    // Highest score first; ties go to the card that was shown first.
    final idx = List<int>.generate(end - start, (i) => start + i)
      ..sort((a, b) {
        final byScore = scores[b].compareTo(scores[a]);
        return byScore != 0 ? byScore : a.compareTo(b);
      });
    final top = idx.take(_top).toList();
    sum += top.where((i) => _positive(labels[i])).length / top.length;
    windows++;
  }
  return sum / windows;
}

/// Tie-aware AUC: the chance that a random positive (label >= 0.5) is scored
/// above a random negative, a tie counting half. 0.5 when either class is
/// missing.
double auc(List<double> scores, List<double> labels) {
  if (scores.length != labels.length) {
    throw ArgumentError('scores and labels must have the same length');
  }
  final n = scores.length;
  final idx = List<int>.generate(n, (i) => i)
    ..sort((a, b) => scores[a].compareTo(scores[b]));
  var positives = 0;
  var rankSum = 0.0;
  var i = 0;
  while (i < n) {
    var j = i;
    while (j + 1 < n && scores[idx[j + 1]] == scores[idx[i]]) {
      j++;
    }
    // Tied scores share the mean of their 1-based ranks.
    final rank = (i + j) / 2 + 1;
    for (var k = i; k <= j; k++) {
      if (_positive(labels[idx[k]])) {
        positives++;
        rankSum += rank;
      }
    }
    i = j + 1;
  }
  final negatives = n - positives;
  if (positives == 0 || negatives == 0) return 0.5;
  return (rankSum - positives * (positives + 1) / 2) / (positives * negatives);
}
