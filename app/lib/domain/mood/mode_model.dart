import 'dart:math' as math;

import 'mood_features.dart';
import 'sessions.dart';
import 'vec.dart';

/// One learned way of watching ("trash isekai", "slow rom-com"), as a
/// weight vector over mood features.
class Mode {
  Mode({
    required this.id,
    required this.centroid,
    this.label = '',
    this.userLabel = false,
    this.sessions = 1,
    List<int>? hours,
  }) : hours = hours ?? List.filled(4, 0);

  final String id;
  String label;
  bool userLabel;
  Vec centroid;
  int sessions;

  /// Sessions per hour bucket (see [hourBucket]).
  final List<int> hours;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'userLabel': userLabel,
    'centroid': centroid,
    'sessions': sessions,
    'hours': hours,
  };

  factory Mode.fromJson(Map<String, Object?> j) => Mode(
    id: j['id']! as String,
    label: (j['label'] as String?) ?? '',
    userLabel: (j['userLabel'] as bool?) ?? false,
    centroid: {
      for (final e in ((j['centroid'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num).toDouble(),
    },
    sessions: (j['sessions'] as num?)?.toInt() ?? 1,
    hours: [
      for (final h in (j['hours'] as List?) ?? const []) (h as num).toInt(),
    ],
  );
}

/// The person's modes, learned by online spherical k-means over the
/// positive picks of finished sessions.
class ModeModel {
  ModeModel([List<Mode>? modes, String Function()? newId])
    : modes = modes ?? [],
      _newId = newId ?? _randomId;

  static const maxModes = 6;
  static const newModeBelow = 0.35;
  static const minPositives = 3;
  static const lr = 0.2;
  static const keep = 60;

  final List<Mode> modes;
  final String Function() _newId;

  static final _rng = math.Random();
  static String _randomId() =>
      List.generate(12, (_) => _rng.nextInt(36).toRadixString(36)).join();

  /// Learns from one finished session. Sessions with fewer than
  /// [minPositives] positive picks say too little and are skipped.
  void absorb(Vec sessionVec, DateTime start, {int positives = minPositives}) {
    if (positives < minPositives || sessionVec.isEmpty) return;
    final v = normalize(sessionVec);
    final bucket = hourBucket(start);
    Mode? best;
    var bestSim = -1.0;
    for (final m in modes) {
      final s = cosine(v, m.centroid);
      if (s > bestSim) {
        bestSim = s;
        best = m;
      }
    }
    if (best == null || bestSim < newModeBelow) {
      if (modes.length >= maxModes) _mergeClosest();
      final m = Mode(id: _newId(), centroid: topK(v, keep));
      m.hours[bucket]++;
      _relabel(m);
      modes.add(m);
      return;
    }
    best
      ..centroid = normalize(topK(addScaled(best.centroid, v, lr), keep))
      ..sessions += 1;
    best.hours[bucket]++;
    _relabel(best);
  }

  void _mergeClosest() {
    var a = 0, b = 1;
    var bestSim = -2.0;
    for (var i = 0; i < modes.length; i++) {
      for (var j = i + 1; j < modes.length; j++) {
        final s = cosine(modes[i].centroid, modes[j].centroid);
        if (s > bestSim) {
          bestSim = s;
          a = i;
          b = j;
        }
      }
    }
    _mergePair(a, b);
  }

  /// The person said two moods are really one: [dropId] folds into [keepId].
  void merge(String keepId, String dropId) {
    final a = modes.indexWhere((m) => m.id == keepId);
    final b = modes.indexWhere((m) => m.id == dropId);
    if (a < 0 || b < 0 || a == b) return;
    _mergePair(a, b);
  }

  /// The person said a mood is wrong: forget it.
  void remove(String id) => modes.removeWhere((m) => m.id == id);

  void _mergePair(int a, int b) {
    final x = modes[a], y = modes[b];
    final total = x.sessions + y.sessions;
    x
      ..centroid = normalize(
        topK(
          addScaled(
            {for (final e in x.centroid.entries) e.key: e.value * x.sessions},
            y.centroid,
            y.sessions.toDouble(),
          ),
          keep,
        ),
      )
      ..sessions = total
      ..userLabel = x.userLabel || y.userLabel;
    for (var i = 0; i < 4; i++) {
      x.hours[i] += y.hours[i];
    }
    if (!x.userLabel) _relabel(x);
    modes.removeAt(b);
  }

  static void _relabel(Mode m) {
    if (m.userLabel) return;
    final named =
        m.centroid.entries.where((e) => !isDerivedFeature(e.key)).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final words = [for (final e in named.take(2)) _title(e.key)];
    if (words.isEmpty) {
      final kind = m.centroid.keys.firstWhere(
        (k) => k.startsWith('kind:'),
        orElse: () => 'kind:mix',
      );
      words.add(_title(kind.substring(5)));
    }
    m.label = words.join(' · ');
  }

  static String _title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Rebuilds the modes from all finished sessions, oldest first.
  static ModeModel discover(
    List<MoodSession> sessions,
    Set<String>? Function(String titleId) features, {
    String Function()? newId,
  }) {
    final model = ModeModel(null, newId);
    for (final s in sessions) {
      model.absorb(s.positiveVec(features), s.start, positives: s.positives);
    }
    return model;
  }

  /// Seeds modes from liked library titles when there is no swipe history:
  /// each liked title is absorbed like a small session.
  static ModeModel seed(
    List<Set<String>> likedFeatures, {
    DateTime? at,
    String Function()? newId,
  }) {
    final model = ModeModel(null, newId);
    final when = at ?? DateTime(2026, 1, 1, 20);
    for (final f in likedFeatures) {
      model.absorb(featureVec(f), when, positives: minPositives);
    }
    return model;
  }
}
