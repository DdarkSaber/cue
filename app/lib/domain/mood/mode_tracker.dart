import 'dart:math' as math;

import 'mode_model.dart';
import 'mood_features.dart';
import 'sessions.dart';
import 'vec.dart';

/// Which learned mode the person is in during this session, as a
/// probability per mode. The first few swipes move it most.
class ModeTracker {
  ModeTracker(this.modes, {required DateTime now, Vec? textVec}) {
    final bucket = hourBucket(now);
    final raw = <String, double>{
      for (final m in modes)
        m.id:
            (m.sessions + 1) *
            (m.hours[bucket] + 1) *
            math.exp(2 * cosine(textVec ?? const {}, m.centroid)),
    };
    p = _normalized(raw);
  }

  static const beta = 3.0;
  static const floor = 0.02;

  final List<Mode> modes;
  late Map<String, double> p;

  /// Updates after a swipe on a title with these mood features.
  void observe(Set<String> features, double signal) {
    if (modes.isEmpty) return;
    final raw = <String, double>{
      for (final m in modes)
        m.id:
            p[m.id]! *
            math.exp(beta * signal * cosine(featureVec(features), m.centroid)),
    };
    p = _floored(_normalized(raw));
  }

  /// The person said which mode they are in.
  void force(String modeId) {
    if (!p.containsKey(modeId)) return;
    final rest = modes.length > 1 ? 0.1 / (modes.length - 1) : 0.0;
    p = {for (final m in modes) m.id: m.id == modeId ? 0.9 : rest};
  }

  double get confidence => p.isEmpty ? 0 : p.values.reduce(math.max);

  Mode? get top {
    if (p.isEmpty) return null;
    final id = p.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return modes.firstWhere((m) => m.id == id);
  }

  /// The runner-up, used to keep some variety in the deck.
  Mode? get second {
    if (p.length < 2) return null;
    final sorted = p.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return modes.firstWhere((m) => m.id == sorted[1].key);
  }

  /// Sum of mode centroids weighted by their probability.
  Vec mixture() {
    var v = <String, double>{};
    for (final m in modes) {
      v = addScaled(v, m.centroid, p[m.id] ?? 0);
    }
    return normalize(v);
  }

  static Map<String, double> _normalized(Map<String, double> raw) {
    final total = raw.values.fold<double>(0, (s, x) => s + x);
    if (total <= 0) {
      return {for (final k in raw.keys) k: 1 / raw.length};
    }
    return {for (final e in raw.entries) e.key: e.value / total};
  }

  /// Every mode keeps at least [floor], so a change of mood stays possible.
  static Map<String, double> _floored(Map<String, double> p) {
    final spare = 1 - floor * p.length;
    if (spare <= 0) return _normalized({for (final k in p.keys) k: 1});
    return {for (final e in p.entries) e.key: floor + spare * e.value};
  }
}
