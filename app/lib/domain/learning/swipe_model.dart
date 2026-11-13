import 'dart:math';

import '../models/decision.dart';
import '../models/title.dart';

/// Value of the non-tag features (kind, year, score, length, country, status,
/// seeded). Below 1 so that these, which sit on every card, do not outweigh
/// idf-scaled tags once the model normalises the vector.
const double swipeMetaValue = 0.5;

/// Sparse feature names for one title, e.g. 'tag:isekai', 'kind:anime',
/// 'year:2020-22', 'score:80', 'len:short', 'country:KR', 'status:finished',
/// 'seeded' (when [seeded] is true), plus a few crosses 'kind:anime|tag:isekai'
/// for the title's genres only (not all tags), to keep the vector small.
///
/// Tag and cross values are the tag's [idf] (1 when the tag is not in [idf]);
/// every other feature is [swipeMetaValue].
Map<String, double> swipeFeatures(
  Title t, {
  bool seeded = false,
  Map<String, double> idf = const {},
}) {
  final x = <String, double>{};
  final kind = 'kind:${t.kind.name}';
  x[kind] = swipeMetaValue;

  for (final f in t.features) {
    x['tag:$f'] = idf[f] ?? 1;
  }
  for (final g in t.genres) {
    final f = g.toLowerCase();
    x['$kind|tag:$f'] = idf[f] ?? 1;
  }

  final year = _yearBucket(t.year);
  if (year != null) {
    x['year:$year'] = swipeMetaValue;
  }

  final score = t.score;
  if (score != null) {
    x['score:${(score.clamp(0, 99) ~/ 10) * 10}'] = swipeMetaValue;
  }

  final length = _lengthBucket(t);
  if (length != null) {
    x['len:$length'] = swipeMetaValue;
  }

  final country = t.country?.trim().toUpperCase();
  if (country != null && country.isNotEmpty) {
    x['country:$country'] = swipeMetaValue;
  }

  final status = t.status.trim().toLowerCase();
  if (status.isNotEmpty && status != 'unknown') {
    x['status:$status'] = swipeMetaValue;
  }

  if (seeded) x['seeded'] = swipeMetaValue;
  return x;
}

String? _yearBucket(int? year) {
  if (year == null) return null;
  if (year < 2000) return 'pre2000';
  if (year < 2010) return '2000s';
  if (year < 2015) return '2010-14';
  if (year < 2020) return '2015-19';
  if (year < 2023) return '2020-22';
  return '2023+';
}

String? _lengthBucket(Title t) {
  if (t.kind == MediaKind.movie || t.format?.toUpperCase() == 'MOVIE') {
    return 'short';
  }
  final reading = t.kind.isReading;
  final count = reading ? t.chapters : t.episodes;
  if (count == null || count <= 0) return null;
  if (count <= (reading ? 60 : 13)) return 'short';
  if (count > (reading ? 200 : 50)) return 'long';
  return 'mid';
}

/// Inverse document frequency for tag/genre features over a pool of titles,
/// so 'action' and 'comedy' count less than rare tags. Smoothed, in (0, 1].
/// Keys are the lower-cased feature names as in Title.features.
Map<String, double> featureIdf(Iterable<Title> pool) {
  final df = <String, int>{};
  var n = 0;
  for (final t in pool) {
    n++;
    for (final f in t.features) {
      df[f] = (df[f] ?? 0) + 1;
    }
  }
  // (ln((n + 1) / (df + 1)) + 1) / (ln(n + 1) + 1): 1 for a tag nobody has,
  // still above 0 for a tag everybody has.
  final top = log(n + 1) + 1;
  return {
    for (final e in df.entries) e.key: (log((n + 1) / (e.value + 1)) + 1) / top,
  };
}

/// Online logistic regression over sparse named features.
///
/// Per feature it keeps the weight, the accumulated squared gradient (the
/// AdaGrad step size) and the evidence seen (the uncertainty). Inputs are
/// L2-normalised, weights are clamped and the map is pruned, so the state
/// stays small and bounded however long it trains.
class SwipeModel {
  SwipeModel({
    this.learningRate = 0.15,
    this.l2 = 0.001,
    this.maxFeatures = 800,
  });

  /// Restores [toJson] output. Anything unknown or malformed gives a fresh
  /// model; this never throws.
  factory SwipeModel.fromJson(Map<String, Object?> json) {
    try {
      if (json['v'] != _version) return SwipeModel();
      final model = SwipeModel(
        learningRate: _finite(json['learningRate']),
        l2: _finite(json['l2']),
        maxFeatures: (json['maxFeatures'] as num).toInt(),
      );
      if (model.learningRate <= 0 || model.l2 < 0 || model.maxFeatures < 1) {
        return SwipeModel();
      }
      model._bias = _finite(json['bias']).clamp(-_maxWeight, _maxWeight);
      model._biasG = _nonNegative(json['biasG']);
      model._updates = _nonNegative(json['updates']);
      final features = json['features'] as Map;
      for (final e in features.entries) {
        final row = e.value as List;
        if (row.length != 3) return SwipeModel();
        model._features[e.key as String] = _Feature()
          ..w = _finite(row[0]).clamp(-_maxWeight, _maxWeight)
          ..g = _nonNegative(row[1])
          ..n = _nonNegative(row[2]);
      }
      if (model._features.length > model.maxFeatures) return SwipeModel();
      return model;
    } on Object {
      return SwipeModel();
    }
  }

  static const _version = 1;
  static const _maxWeight = 4.0;

  /// Keeps the first AdaGrad step proportional to the gradient, so a weak
  /// (low-weight) signal moves the model less than a swipe does.
  static const _stepFloor = 0.05;

  /// Spread of [sample] in logit units for a fully unseen vector.
  static const _sampleSpread = 1.0;

  /// [confidence] reaches 1 at this many updates.
  static const _trustedUpdates = 40.0;

  final double learningRate;
  final double l2;
  final int maxFeatures;

  final Map<String, _Feature> _features = {};
  double _bias = 0;
  double _biasG = 0;
  double _updates = 0;

  /// P(save) in 0..1 for a feature vector. About 0.5 before any update.
  double predict(Map<String, double> x) => _sigmoid(_logit(x, _norm(x)));

  /// One online update. [label] 1 = positive, 0 = negative; [weight] scales
  /// the step (implicit signals use < 1).
  void update(Map<String, double> x, double label, {double weight = 1}) {
    if (!label.isFinite || !weight.isFinite || weight <= 0) return;
    final y = label.clamp(0.0, 1.0);
    final norm = _norm(x);
    final error = _sigmoid(_logit(x, norm)) - y;

    _biasG += weight * error * error;
    _bias = (_bias - learningRate * weight * error / sqrt(_stepFloor + _biasG))
        .clamp(-_maxWeight, _maxWeight);

    if (norm > 0) {
      final shrink = 1 - learningRate * l2 * min(weight, 1.0);
      for (final e in x.entries) {
        final v = _value(e.value) / norm;
        if (v == 0) continue;
        final f = _features[e.key] ??= _Feature();
        final gradient = error * v;
        f.g += weight * gradient * gradient;
        f.n += weight;
        final step = learningRate * weight * gradient / sqrt(_stepFloor + f.g);
        f.w = (f.w * shrink - step).clamp(-_maxWeight, _maxWeight);
      }
      if (_features.length > maxFeatures) _prune();
    }
    _updates += weight;
  }

  /// Thompson-style draw: predict with weights perturbed by per-feature
  /// uncertainty (features seen less are perturbed more). Deterministic for a
  /// seeded [random].
  ///
  /// Perturbing each weight by an independent normal of scale sigma_f shifts
  /// the logit by a normal of variance sum(x_f^2 * sigma_f^2), so one draw of
  /// that size is the same distribution and does not depend on map order.
  double sample(Map<String, double> x, Random random) {
    final norm = _norm(x);
    final spread = _sampleSpread * sqrt(_variance(x, norm));
    return _sigmoid(_logit(x, norm) + spread * _gaussian(random));
  }

  /// 0..1: how unsure the model is about this vector (1 = all features
  /// unseen, falls as the features in x accumulate updates). An empty vector
  /// is 1.
  double uncertainty(Map<String, double> x) {
    final norm = _norm(x);
    return norm > 0 ? _variance(x, norm) : 1;
  }

  /// Sum of update weights so far.
  double get updates => _updates;

  /// 0..1 trust: min(1, updates / 40).
  double get confidence => min(1, _updates / _trustedUpdates);

  /// The strongest learned features, for explanations/debug: by |weight|.
  List<MapEntry<String, double>> topFeatures({int n = 10}) {
    final all = [for (final e in _features.entries) MapEntry(e.key, e.value.w)]
      ..sort((a, b) {
        final c = b.value.abs().compareTo(a.value.abs());
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return all.take(max(0, n)).toList();
  }

  Map<String, Object?> toJson() => {
    'v': _version,
    'learningRate': learningRate,
    'l2': l2,
    'maxFeatures': maxFeatures,
    'bias': _bias,
    'biasG': _biasG,
    'updates': _updates,
    'features': {
      for (final e in _features.entries)
        e.key: [e.value.w, e.value.g, e.value.n],
    },
  };

  /// Drops the weakest features (smallest |weight|, then least evidence)
  /// until 90% of the cap is left.
  void _prune() {
    final keep = max(1, (maxFeatures * 0.9).floor());
    final order = _features.entries.toList()
      ..sort((a, b) {
        var c = a.value.w.abs().compareTo(b.value.w.abs());
        if (c == 0) c = a.value.n.compareTo(b.value.n);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    for (final e in order.take(order.length - keep)) {
      _features.remove(e.key);
    }
  }

  double _logit(Map<String, double> x, double norm) {
    var z = _bias;
    if (norm == 0) return z;
    for (final e in x.entries) {
      final f = _features[e.key];
      if (f != null) z += f.w * _value(e.value) / norm;
    }
    return z;
  }

  /// sum(x_f^2 * sigma_f^2) over the normalised vector, with
  /// sigma_f = 1 / sqrt(1 + evidence_f); 0 for an empty vector.
  double _variance(Map<String, double> x, double norm) {
    if (norm == 0) return 0;
    var sum = 0.0;
    for (final e in x.entries) {
      final v = _value(e.value) / norm;
      sum += v * v / (1 + (_features[e.key]?.n ?? 0));
    }
    return sum.clamp(0.0, 1.0);
  }

  static double _norm(Map<String, double> x) {
    var sum = 0.0;
    for (final v in x.values) {
      final value = _value(v);
      sum += value * value;
    }
    return sqrt(sum);
  }

  /// Non-finite inputs count as absent.
  static double _value(double v) => v.isFinite ? v : 0;

  static double _sigmoid(double z) => 1 / (1 + exp(-z));

  /// Standard normal by Box-Muller; two draws from [random] per call.
  static double _gaussian(Random random) {
    final u = 1 - random.nextDouble();
    final v = random.nextDouble();
    return sqrt(-2 * log(u)) * cos(2 * pi * v);
  }

  static double _finite(Object? raw) {
    final v = (raw as num).toDouble();
    if (!v.isFinite) throw const FormatException('not finite');
    return v;
  }

  static double _nonNegative(Object? raw) {
    final v = _finite(raw);
    if (v < 0) throw const FormatException('negative');
    return v;
  }
}

class _Feature {
  /// Weight.
  double w = 0;

  /// Accumulated squared gradient.
  double g = 0;

  /// Evidence: sum of the update weights this feature took part in.
  double n = 0;
}

/// What a decision teaches. null = teaches nothing.
/// willTry -> (1, 1.0); notInterested -> (0, 1.0); watched -> (1, 0.5)
/// (already seen means it was relevant); notNow -> (0, 0.25) unless
/// [savingForLater] is true, then null.
({double label, double weight})? decisionLabel(
  Decision d, {
  bool savingForLater = false,
}) => switch (d) {
  Decision.willTry => (label: 1, weight: 1),
  Decision.notInterested => (label: 0, weight: 1),
  Decision.watched => (label: 1, weight: 0.5),
  Decision.notNow => savingForLater ? null : (label: 0, weight: 0.25),
};

/// Weak positives from behaviour without a swipe. Returns null when nothing
/// notable happened. openedDetails -> (1, 0.3); heldPoster -> (1, 0.15);
/// dwell >= 8s without either -> (1, 0.1). The strongest one only.
({double label, double weight})? implicitLabel({
  required Duration dwell,
  bool openedDetails = false,
  bool heldPoster = false,
}) {
  if (openedDetails) return (label: 1, weight: 0.3);
  if (heldPoster) return (label: 1, weight: 0.15);
  if (dwell >= const Duration(seconds: 8)) return (label: 1, weight: 0.1);
  return null;
}
