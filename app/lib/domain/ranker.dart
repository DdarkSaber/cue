import 'dart:math';

import 'models/deck_filters.dart';
import 'models/library.dart';
import 'models/quick_mood.dart';
import 'models/title.dart';
import 'mood/mood_features.dart';
import 'mood/mood_target.dart';
import 'mood/vec.dart';
import 'mood_tags.dart';
import 'reasons.dart';

/// Everything personal the ranker may use. Built from the active profile
/// only; no names or constants about any person.
class ProfileSignals {
  const ProfileSignals({
    this.excluded = const {},
    this.deferred = const {},
    this.shortlisted = const {},
    this.library = const {},
    this.weights = const {},
    this.evidenceTitles = 0,
    this.kindRatings = const {},
  });

  final Set<String> excluded;
  final Set<String> deferred;
  final Set<String> shortlisted;
  final Map<String, LibraryEntry> library;

  /// Tag weights from ratings and decisions.
  final Map<String, double> weights;

  /// Distinct titles that produced taste evidence.
  final int evidenceTitles;

  /// How many rated titles exist per kind (drives exploration).
  final Map<MediaKind, int> kindRatings;
}

/// In-session drift: tags the person keeps skipping or keeping right now.
/// It fades with every decision and is never stored.
class SessionMood {
  SessionMood([Map<String, double>? bias]) : bias = bias ?? {};

  final Map<String, double> bias;

  static const _decay = 0.85;

  void record(Set<String> features, double signal) {
    for (final k in bias.keys.toList()) {
      bias[k] = bias[k]! * _decay;
      if (bias[k]!.abs() < 0.02) bias.remove(k);
    }
    for (final f in features) {
      bias[f] = ((bias[f] ?? 0) + signal).clamp(-1.5, 1.5);
    }
  }

  /// -1 to 1: how much the current session leans toward these features.
  double lean(Set<String> features) {
    if (features.isEmpty || bias.isEmpty) return 0;
    var sum = 0.0;
    for (final f in features) {
      sum += bias[f] ?? 0;
    }
    return (sum / features.length).clamp(-1, 1).toDouble();
  }
}

class RankedCard {
  const RankedCard(this.title, this.score, this.reason);
  final Title title;
  final double score;
  final String reason;
}

/// Why the deck is empty, for an honest no-match message.
class EmptyReason {
  const EmptyReason(this.message);
  final String message;
}

class Ranker {
  Ranker({Random? random, DateTime Function()? clock})
    : _random = random ?? Random(),
      _now = clock ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;

  static const deckSize = 10;
  static const coldStartBelow = 20;

  /// Stage 1: hard filters. Never relaxed silently.
  bool eligible(
    Title t,
    ProfileSignals s,
    DeckFilters f, {
    required bool showAdult,
    required Set<MediaKind> enabledKinds,
    bool includeRewatchesDefault = false,
  }) {
    if (t.adult && !showAdult) return false;
    if (s.excluded.contains(t.id)) return false;
    if (s.deferred.contains(t.id)) return false;
    if (s.shortlisted.contains(t.id)) return false;

    final entry = s.library[t.id];
    // Rediscover: finished 3+ years ago, only when the real date is known.
    final watched = entry?.actualWatchedAt;
    final longAgo =
        watched != null &&
        watched.isBefore(_now().subtract(const Duration(days: 3 * 365)));
    final rewatchable = (entry?.rating?.isRewatch ?? false) || longAgo;
    if (f.isRevisit) {
      if (!rewatchable) return false;
    } else if (entry != null) {
      return false;
    }

    final kinds = f.kinds.isEmpty ? enabledKinds : f.kinds;
    if (!kinds.contains(t.kind)) return false;
    if (!f.genres.every(
      (g) => t.genres.any((actual) => actual.toLowerCase() == g),
    )) {
      return false;
    }
    if (f.shortOnly && !_isShort(t)) return false;
    if (f.era == EraFilter.newArt && (t.year == null || t.year! < 2023)) {
      return false;
    }
    if (f.era == EraFilter.classic && (t.year == null || t.year! >= 2010)) {
      return false;
    }
    if (f.status == StatusFilter.finished && t.status != 'finished') {
      return false;
    }
    if (f.status == StatusFilter.ongoing &&
        t.status != 'airing' &&
        t.status != 'ongoing') {
      return false;
    }
    if (f.countries.isNotEmpty && !f.countries.contains(t.country)) {
      return false;
    }
    return true;
  }

  static bool _isShort(Title t) {
    if (t.kind == MediaKind.movie) return true;
    if (t.kind.isReading) return t.chapters != null && t.chapters! <= 60;
    if (t.seasons.length > 1) return false;
    return t.episodes != null && t.episodes! <= 13;
  }

  /// Stage 2: score in 0..1.
  double score(
    Title t,
    ProfileSignals s,
    DeckFilters f, {
    SessionMood? session,
    MoodTarget? target,
  }) {
    final features = t.features;
    final taste = s.evidenceTitles < coldStartBelow
        ? 0.5
        : _cosine(features, s.weights);
    final mood = switch (f.mood) {
      // The learned mood steers the default deck.
      QuickMood.forYou when target != null && target.confidence > 0 =>
        0.5 + 0.5 * cosine(titleVec(t), target.vec),
      QuickMood.forYou => 0.5,
      QuickMood.revisit => _revisitMood(t, s, f),
      final m => moodOverlap(features, m),
    };
    final quality = t.score == null ? 0.6 : t.score! / 100;
    var freshness = t.year == null
        ? 0.5
        : t.year! >= 2023
        ? 1.0
        : t.year! >= 2018
        ? 0.7
        : 0.4;
    if (f.era == EraFilter.classic) freshness = 1.4 - freshness;
    final rated = s.kindRatings[t.kind] ?? 0;
    final novelty = 1 / (1 + rated / 5);
    final penalty = _penalty(features, s.weights);
    final lean = session?.lean(features) ?? 0;
    final learned = f.mood == QuickMood.forYou && (target?.confidence ?? 0) > 0;
    final moodW = learned ? 0.10 + 0.25 * target!.confidence : 0.20;
    final tasteW = max(0.25, 0.40 - (moodW - 0.20));
    return tasteW * taste +
        moodW * mood +
        0.15 * quality +
        0.15 * freshness +
        0.10 * novelty -
        penalty +
        0.08 * lean;
  }

  double _revisitMood(Title t, ProfileSignals s, DeckFilters f) {
    final entry = s.library[t.id];
    return entry?.rating == Rating.rewatched ? 1 : 0.7;
  }

  static double _cosine(Set<String> features, Map<String, double> weights) {
    if (features.isEmpty || weights.isEmpty) return 0.5;
    var dot = 0.0, norm = 0.0;
    for (final w in weights.values) {
      norm += w * w;
    }
    for (final f in features) {
      dot += weights[f] ?? 0;
    }
    if (norm == 0) return 0.5;
    final cos = dot / (sqrt(norm) * sqrt(features.length));
    return ((cos + 1) / 2).clamp(0, 1).toDouble();
  }

  /// Up to 0.3 for features the profile rated badly, from data only.
  static double _penalty(Set<String> features, Map<String, double> weights) {
    var worst = 0.0;
    for (final f in features) {
      final w = weights[f] ?? 0;
      if (w < worst) worst = w;
    }
    return (-worst / 10).clamp(0, 0.3).toDouble();
  }

  /// Builds a deck: 7 top-scored, 2 exploration, 1 wildcard from another
  /// kind. One card per franchise.
  List<RankedCard> deal(
    List<Title> pool,
    ProfileSignals s,
    DeckFilters f, {
    required bool showAdult,
    required Set<MediaKind> enabledKinds,
    required Map<String, Title> titlesById,
    bool includeRewatchesDefault = false,
    SessionMood? session,
    MoodTarget? target,
    Set<String> skip = const {},
    int size = deckSize,
  }) {
    final scored = <RankedCard>[];
    for (final t in pool) {
      if (skip.contains(t.id)) continue;
      if (!eligible(
        t,
        s,
        f,
        showAdult: showAdult,
        enabledKinds: enabledKinds,
        includeRewatchesDefault: includeRewatchesDefault,
      )) {
        continue;
      }
      // Tiny jitter so equal scores do not always deal in the same order.
      final sc =
          score(t, s, f, session: session, target: target) +
          _random.nextDouble() * 0.02;
      scored.add(RankedCard(t, sc, ''));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final franchises = <String>{};
    final picked = <RankedCard>[];
    bool take(RankedCard c) {
      if (picked.length >= size) return false;
      if (!franchises.add(c.title.franchiseKey)) return false;
      picked.add(c);
      return true;
    }

    final top = (size * 0.7).round();
    final explore = (size * 0.2).round();
    for (final c in scored) {
      if (picked.length >= top) break;
      take(c);
    }
    // Exploration: kinds with the fewest ratings, from the upper half.
    final rest = scored.where((c) => !picked.contains(c)).toList();
    final half = rest.take(max(rest.length ~/ 2, explore)).toList()
      ..sort(
        (a, b) => (s.kindRatings[a.title.kind] ?? 0).compareTo(
          s.kindRatings[b.title.kind] ?? 0,
        ),
      );
    var explored = 0;
    for (final c in half) {
      if (explored >= explore) break;
      if (take(c)) explored++;
    }
    // Wildcard: the best card from a kind not yet in the deck.
    final kindsInDeck = picked.map((c) => c.title.kind).toSet();
    for (final c in scored) {
      if (picked.length >= size) break;
      if (!kindsInDeck.contains(c.title.kind) && take(c)) break;
    }
    for (final c in scored) {
      if (picked.length >= size) break;
      take(c);
    }

    return [
      for (final c in picked)
        RankedCard(
          c.title,
          c.score,
          reasonFor(c.title, s, f, titlesById: titlesById, now: _now()),
        ),
    ];
  }

  /// Explains an empty deck by naming the constraint that removed the most.
  EmptyReason explainEmpty(
    List<Title> pool,
    ProfileSignals s,
    DeckFilters f, {
    required bool showAdult,
    required Set<MediaKind> enabledKinds,
  }) {
    if (pool.isEmpty) {
      return const EmptyReason(
        'No stories cached yet. Connect to the internet once and Cue keeps them for offline use.',
      );
    }
    if (f.isRevisit) {
      return const EmptyReason(
        'Revisit deals titles you rated Rewatched or Would rewatch. Rate some in Library, or import your list.',
      );
    }
    final checks = <String, DeckFilters>{
      'the format filter': f.copyWith(kinds: {}),
      'Short season': f.copyWith(shortOnly: false),
      'the art era filter': f.copyWith(era: EraFilter.any),
      'the status filter': f.copyWith(status: StatusFilter.any),
      'the country filter': f.copyWith(countries: {}),
      'the genre filter': f.copyWith(genres: {}),
    };
    for (final e in checks.entries) {
      if (e.value == f) continue;
      final n = pool
          .where(
            (t) => eligible(
              t,
              s,
              e.value,
              showAdult: showAdult,
              enabledKinds: enabledKinds,
            ),
          )
          .map((t) => t.franchiseKey)
          .toSet()
          .length;
      if (n > 0) {
        return EmptyReason(
          'Nothing matches with ${e.key} on. Without it there are $n picks.',
        );
      }
    }
    return const EmptyReason(
      'You have decided on every cached story for these filters. Cue will fetch more when online.',
    );
  }
}
