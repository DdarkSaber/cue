import 'dart:math';

import 'models/title.dart';
import 'models/library.dart';
import 'ranker.dart';

enum NotNowReason { tooLong, wrongMood, savingLater }

class _TemporarySignal {
  const _TemporarySignal(this.id, this.features, this.signal);
  final String id;
  final Set<String> features;
  final double signal;
}

/// Never serialized: these controls must not become ratings or learned moods.
class RecommendationSession {
  RecommendationSession({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;
  final DateTime Function() _now;
  String? _profile;
  DateTime? _last;
  double exploration = 0.35;
  final bias = SessionMood();
  final shown = <String>{};
  final _signals = <_TemporarySignal>[];
  int _sequence = 0;
  int _surpriseRemaining = 0;
  int _shorterRemaining = 0;
  int _notNowStreak = 0;
  bool _directionSuggested = false;
  String? _lengthEvent;

  double get effectiveExploration => _surpriseRemaining > 0 ? 1 : exploration;
  int get surpriseRemaining => _surpriseRemaining;
  bool get preferShorter => _shorterRemaining > 0;
  bool get repeatedNotNow => _notNowStreak >= 3;

  bool activate(String profile) {
    final now = _now();
    final last = _last;
    final expired =
        _profile != profile ||
        last == null ||
        now.difference(last) >= const Duration(minutes: 45) ||
        (now.year, now.month, now.day) != (last.year, last.month, last.day);
    if (expired) reset();
    _profile = profile;
    _last = now;
    return expired;
  }

  void reset() {
    bias.bias.clear();
    exploration = 0.35;
    shown.clear();
    _signals.clear();
    _surpriseRemaining = 0;
    _shorterRemaining = 0;
    _notNowStreak = 0;
    _directionSuggested = false;
    _lengthEvent = null;
    _last = _now();
  }

  void feedback(Title title, {required bool more}) {
    _add('local:${++_sequence}', title.features, more ? 0.6 : -0.6);
  }

  void trait(Title title, String feature) {
    final key = feature.trim().toLowerCase();
    if (!title.features.contains(key)) {
      throw ArgumentError('unsupported_title_feature');
    }
    _add('local:${++_sequence}', {key}, 0.6);
  }

  void immediateInterest(Title title, String eventId) =>
      _add(eventId, title.features, 0.9);

  void _add(String id, Set<String> features, double signal) {
    if (_signals.any((s) => s.id == id)) return;
    _signals.add(_TemporarySignal(id, features.take(32).toSet(), signal));
    if (_signals.length > 40) _signals.removeAt(0);
    _replay();
  }

  void undoInterest(String eventId) {
    _signals.removeWhere((s) => s.id == eventId);
    _replay();
    if (_lengthEvent == eventId) {
      _lengthEvent = null;
      _shorterRemaining = 0;
    }
  }

  void _replay() {
    bias.bias.clear();
    for (final signal in _signals) {
      bias.record(signal.features, signal.signal);
    }
    if (bias.bias.length > 256) {
      final keep =
          (bias.bias.entries.toList()
                ..sort((a, b) => b.value.abs().compareTo(a.value.abs())))
              .take(256)
              .map((e) => e.key)
              .toSet();
      bias.bias.removeWhere((k, _) => !keep.contains(k));
    }
  }

  void explore(double value) {
    exploration = value.clamp(0, 1);
    _surpriseRemaining = 0;
  }

  void surprise() => _surpriseRemaining = 5;

  void differentDirection() {
    _signals.clear();
    bias.bias.clear();
    _notNowStreak = 0;
    surprise();
  }

  /// Counts actual card choices, not taps, failed saves, or opening details.
  bool choice({
    required bool notNow,
    required String eventId,
    NotNowReason? reason,
  }) {
    if (_surpriseRemaining > 0) _surpriseRemaining--;
    if (_shorterRemaining > 0) _shorterRemaining--;
    _notNowStreak = notNow && reason != NotNowReason.savingLater
        ? _notNowStreak + 1
        : 0;
    if (reason == NotNowReason.tooLong) {
      _shorterRemaining = 5;
      _lengthEvent = eventId;
    } else if (reason == NotNowReason.wrongMood) {
      differentDirection();
    }
    if (repeatedNotNow && !_directionSuggested) {
      _directionSuggested = true;
      return true;
    }
    return false;
  }
}

class InterestCluster {
  const InterestCluster(this.features, this.strength);
  final Set<String> features;
  final double strength;
  double affinity(Title title) => title.features.isEmpty || features.isEmpty
      ? 0
      : title.features.intersection(features).length /
            sqrt(title.features.length * features.length);
}

double clusterAffinity(Title title, List<InterestCluster> clusters) {
  if (clusters.isEmpty) return 0;
  final strongest = clusters.map((c) => c.strength).reduce(max);
  if (strongest <= 0) return 0;
  return clusters
      .map((c) => c.affinity(title) * (c.strength / strongest))
      .reduce(max);
}

/// At most four transparent on-device theme groups, not inferred star ratings.
List<InterestCluster> interestClusters(
  ProfileSignals signals,
  Map<String, Title> titles,
) {
  final evidence = <(Title, double)>[];
  for (final entry in signals.library.values) {
    final t = titles[entry.titleId];
    final weight =
        entry.rating?.weight ??
        (signals.weakHistoryIds.contains(entry.titleId)
            ? (entry.state == LibraryState.completed ? 0.15 : 0.2)
            : 0);
    if (t != null && t.features.isNotEmpty && weight > 0) {
      evidence.add((t, weight));
    }
  }
  for (final id in signals.shortlisted.difference(
    signals.library.keys.toSet(),
  )) {
    final t = titles[id];
    if (t != null && t.features.isNotEmpty) evidence.add((t, 1));
  }
  evidence.sort((a, b) => b.$2.compareTo(a.$2));
  final groups = <Map<String, double>>[];
  final strengths = <double>[];
  for (final (title, strength) in evidence.take(64)) {
    final features = title.features
        .where((f) => (signals.weights[f] ?? 0) >= 0)
        .take(8)
        .toSet();
    if (features.isEmpty) continue;
    var group = groups.indexWhere(
      (g) =>
          features.intersection(g.keys.toSet()).length / features.length >= 0.5,
    );
    if (group < 0) {
      if (groups.length >= 4) continue;
      group = groups.length;
      groups.add({});
      strengths.add(0);
    }
    for (final f in features) {
      groups[group][f] = (groups[group][f] ?? 0) + strength;
    }
    strengths[group] += strength;
  }
  return [
    for (var i = 0; i < groups.length; i++)
      InterestCluster(
        (groups[i].entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(8)
            .map((e) => e.key)
            .toSet(),
        strengths[i],
      ),
  ];
}

/// How many liked titles seed taste-seeded retrieval and its reasons.
const maxTasteSeeds = 24;

/// The profile's strongest positive titles, strongest first: Favourite and
/// Rewatched, then Would rewatch and Enjoyed, then Once was enough; ties go
/// to the most recently finished. Without enough ratings, imported
/// watching/completed history fills in (it is weak evidence, but it is what
/// the person chose to watch). Okay, negative, planned and dropped titles
/// never seed.
List<String> selectTasteSeeds(
  ProfileSignals signals, {
  int limit = maxTasteSeeds,
}) {
  final rated =
      signals.library.values
          .where((e) => (e.rating?.weight ?? 0) >= 1.5)
          .toList()
        ..sort((a, b) {
          final w = b.rating!.weight.compareTo(a.rating!.weight);
          if (w != 0) return w;
          final at = a.actualWatchedAt, bt = b.actualWatchedAt;
          if (at != null && bt != null && at != bt) return bt.compareTo(at);
          if ((at == null) != (bt == null)) return at == null ? 1 : -1;
          return a.titleId.compareTo(b.titleId);
        });
  final history =
      signals.library.values
          .where(
            (e) =>
                e.rating == null &&
                signals.weakHistoryIds.contains(e.titleId) &&
                !signals.excluded.contains(e.titleId),
          )
          .toList()
        ..sort((a, b) {
          // Completed before watching, then most recently finished.
          final c = (b.state == LibraryState.completed ? 1 : 0).compareTo(
            a.state == LibraryState.completed ? 1 : 0,
          );
          if (c != 0) return c;
          final at = a.actualWatchedAt, bt = b.actualWatchedAt;
          if (at != null && bt != null && at != bt) return bt.compareTo(at);
          if ((at == null) != (bt == null)) return at == null ? 1 : -1;
          return a.titleId.compareTo(b.titleId);
        });
  return [
    for (final e in [...rated, ...history]) e.titleId,
  ].take(limit).toList();
}

class RetrievalRequest {
  const RetrievalRequest(this.kind, this.route, {this.mood});
  final MediaKind kind;
  final String route;
  final String? mood;
}

/// One fair broad page per enabled kind plus at most three related pages.
/// Fresh and adjacent candidates are drawn from that cache, never fabricated.
List<RetrievalRequest> retrievalPlan(
  Set<MediaKind> kinds,
  List<InterestCluster> clusters,
  Map<MediaKind, int> ratedKinds,
  int round, {
  String? explicitMood,
}) {
  final sorted = kinds.toList()..sort((a, b) => a.index.compareTo(b.index));
  if (sorted.isEmpty) return const [];
  final rotated = [
    for (var i = 0; i < sorted.length; i++) sorted[(i + round) % sorted.length],
  ];
  final requests = [
    for (final kind in rotated) RetrievalRequest(kind, 'broad'),
  ];
  final themes = clusters.expand((c) => c.features).toSet();
  final moods = <String>[
    ?explicitMood,
    if (themes.any({'comedy', 'romance', 'slice of life'}.contains)) 'comfort',
    if (themes.any({'action', 'adventure', 'sports'}.contains)) 'hype',
    if (themes.any({'mystery', 'thriller', 'psychological'}.contains))
      'gripping',
  ];
  final underexplored = List.of(rotated)
    ..sort((a, b) => (ratedKinds[a] ?? 0).compareTo(ratedKinds[b] ?? 0));
  // The taste route goes to the kind the person rates most, so a big anime
  // library gets taste-shaped anime pages, not only one broad page while
  // the related routes all go to the kinds they barely use.
  final favourite = underexplored.last;
  final useFavourite =
      underexplored.length > 1 && (ratedKinds[favourite] ?? 0) > 0;
  final related = [
    if (useFavourite) favourite,
    ...underexplored.where((k) => !useFavourite || k != favourite),
  ];
  for (var i = 0; i < min(3, related.length); i++) {
    if (moods.isEmpty) break;
    requests.add(
      RetrievalRequest(
        related[i],
        i == 0
            ? 'taste'
            : i == 1
            ? 'cluster'
            : 'adjacent',
        mood: moods[(i + round) % moods.length],
      ),
    );
  }
  return requests.take(12).toList();
}
