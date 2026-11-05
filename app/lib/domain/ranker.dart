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
import 'recommendation_context.dart';
import 'franchise_identity.dart';

/// Everything personal the ranker may use. Built from the active profile
/// only; no names or constants about any person.
class ProfileSignals {
  const ProfileSignals({
    this.excluded = const {},
    this.known = const {},
    this.seenNames = const {},
    this.excludedFranchises = const {},
    this.deferred = const {},
    this.shortlisted = const {},
    this.library = const {},
    this.weights = const {},
    this.evidenceTitles = 0,
    this.evidenceStrength,
    this.weakHistoryIds = const {},
    this.kindRatings = const {},
    this.tasteSeeds = const [],
    this.becauseOf = const {},
  });

  /// The profile's strongest liked titles, strongest first (see
  /// [selectTasteSeeds]). Seeded retrieval asks providers about these.
  final List<String> tasteSeeds;

  /// Candidate title id -> ids of [tasteSeeds] whose provider "more like
  /// this" lists include it, strongest seed first. Public edges joined with
  /// this profile's likes in memory; never stored per person.
  final Map<String, List<String>> becauseOf;

  final Set<String> excluded;

  /// Titles the person's imports listed but did not add to the library
  /// (unconfirmed Netflix plays, suggestions left unticked, the review
  /// queue). Never dealt as new picks, and never read as taste.
  final Set<String> known;

  /// [workName]s of every library and [known] title. A title of another
  /// format with the same name (the manga of a watched anime, the anime of
  /// a read manhwa) is the same story, so it is not dealt as new.
  final Set<String> seenNames;
  final Set<String> excludedFranchises;
  final Set<String> deferred;
  final Set<String> shortlisted;
  final Map<String, LibraryEntry> library;

  /// Tag weights from ratings and decisions.
  final Map<String, double> weights;

  /// Distinct titles that produced taste evidence.
  final int evidenceTitles;
  final double? evidenceStrength;
  final Set<String> weakHistoryIds;
  double get tasteConfidence =>
      ((evidenceStrength ?? evidenceTitles) / Ranker.coldStartBelow)
          .clamp(0, 1)
          .toDouble();

  /// How many rated titles exist per kind (drives exploration).
  final Map<MediaKind, int> kindRatings;
}

/// A title's names reduced to letters and digits, for spotting the same work
/// across formats. Very short names are left out: too many works share them.
Iterable<String> workNames(Title t) => {
  for (final n in [t.titleEn, t.titleRomaji])
    if (n != null) n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
}.where((n) => n.length >= 5);

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
  const RankedCard(
    this.title,
    this.score,
    this.reason, {
    this.becauseOf = const [],
  });
  final Title title;
  final double score;
  final String reason;

  /// Catalog ids of the liked titles ("seeds") whose provider "more like
  /// this" lists recommended this card, strongest seed first. Empty when the
  /// card did not come from taste-seeded retrieval. Use it to show
  /// "Because you liked `seed`"; [reason] already does when it fits.
  final List<String> becauseOf;
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
    if (t.format == 'NOVEL' || t.format == 'MUSIC') return false;
    if (t.adult && !showAdult) return false;
    if (s.excluded.contains(t.id)) return false;
    final franchise = reliableFranchiseId(t);
    if (franchise != null && s.excludedFranchises.contains(franchise)) {
      return false;
    }
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
    } else if (entry != null || s.known.contains(t.id)) {
      return false;
    } else if (s.seenNames.isNotEmpty &&
        workNames(t).any(s.seenNames.contains)) {
      return false;
    }

    final kinds = f.kinds.isEmpty ? enabledKinds : f.kinds;
    if (!kinds.contains(t.kind)) return false;
    if (f.excludedKinds.contains(t.kind)) return false;
    if (f.excludedGenres.isNotEmpty &&
        (t.genres.isEmpty ||
            t.genres.any((g) => f.excludedGenres.contains(g.toLowerCase())))) {
      return false;
    }
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
    SessionMood? temporary,
    bool preferShorter = false,
    List<InterestCluster> clusters = const [],
    Set<String> recentExposures = const {},
  }) {
    final features = t.features;
    final clusterTaste = clusters.isEmpty ? null : clusterAffinity(t, clusters);
    final rawTaste = features.isEmpty
        ? 0.5
        : clusterTaste == null
        ? _cosine(features, s.weights)
        : 0.7 * _cosine(features, s.weights) + 0.3 * clusterTaste;
    final taste = 0.5 + s.tasteConfidence * (rawTaste - 0.5);
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
        0.08 * lean +
        0.08 * (temporary?.lean(features) ?? 0) -
        (recentExposures.contains(t.id) ? 0.04 : 0) +
        (preferShorter ? _lengthPreference(t) : 0) +
        seedBoost(s.becauseOf[t.id]?.length ?? 0);
  }

  /// Taste-seeded boost: +0.04 when one liked title's "more like this"
  /// list includes the candidate, +0.04 more per further liked seed, capped
  /// at +0.12. Modest on purpose: agreement between several of your likes
  /// counts, one list alone does not outrank taste and mood.
  static double seedBoost(int seeds) => min(0.12, 0.04 * seeds);

  static double _lengthPreference(Title t) {
    // Episode/chapter counts cannot establish a film's runtime.
    if (t.kind == MediaKind.movie) return 0;
    final known = t.kind.isReading ? t.chapters : t.episodes;
    if (known == null) return 0;
    return _isShort(t) ? 0.04 : -0.08;
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

  /// Adaptive familiar/adjacent/explore slots when a preference is supplied;
  /// otherwise retains the legacy 7/2/1 allocation. One card per franchise.
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
    SessionMood? temporary,
    bool preferShorter = false,
    List<InterestCluster> clusters = const [],
    Set<String> recentExposures = const {},
    double? explorePreference,
    Set<String> skip = const {},
    bool shortestFirst = false,
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
          score(
            t,
            s,
            f,
            session: session,
            target: target,
            temporary: temporary,
            preferShorter: preferShorter,
            clusters: clusters,
            recentExposures: recentExposures,
          ) +
          _random.nextDouble() * 0.02;
      scored.add(
        RankedCard(t, sc, '', becauseOf: s.becauseOf[t.id] ?? const []),
      );
    }
    scored.sort((a, b) {
      if (shortestFirst) {
        final length = (a.title.episodes ?? 1 << 30).compareTo(
          b.title.episodes ?? 1 << 30,
        );
        if (length != 0) return length;
      }
      return b.score.compareTo(a.score);
    });
    if (shortestFirst) {
      final franchises = <String>{};
      return [
        for (final c
            in scored
                .where((c) => franchises.add(c.title.franchiseKey))
                .take(size))
          RankedCard(
            c.title,
            c.score,
            reasonFor(c.title, s, f, titlesById: titlesById, now: _now()),
            becauseOf: c.becauseOf,
          ),
      ];
    }
    if (explorePreference != null) {
      return [
        for (final c in _adaptive(
          scored,
          size,
          s,
          clusters,
          explorePreference,
          recentExposures,
        ))
          RankedCard(
            c.title,
            c.score,
            (temporary?.lean(c.title.features) ?? 0).abs() > 0.1
                ? "Today's interest and direction; ratings unchanged."
                // A seeded pick is explained by its seed, not as exploring.
                : c.reason.isNotEmpty && c.becauseOf.isEmpty
                ? c.reason.trim()
                : reasonFor(c.title, s, f, titlesById: titlesById, now: _now()),
            becauseOf: c.becauseOf,
          ),
      ];
    }

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
    final exploration = <RankedCard>[];
    final broadFirstRun =
        s.evidenceTitles < coldStartBelow &&
        f.activeCount == 0 &&
        f.mood == QuickMood.forYou &&
        (target?.confidence ?? 0) == 0;
    // The old upper-half-only exploration could repeat the dominant kind.
    // First-run exploration can use any eligible kind, but never relax filters.
    if (broadFirstRun) {
      final candidates = List.of(rest)
        ..sort(
          (a, b) => (s.kindRatings[a.title.kind] ?? 0).compareTo(
            s.kindRatings[b.title.kind] ?? 0,
          ),
        );
      for (final c in candidates) {
        if (exploration.length >= explore) break;
        if (picked.any((p) => p.title.kind == c.title.kind)) continue;
        if (take(c)) exploration.add(c);
      }
    }
    var explored = exploration.length;
    for (final c in half) {
      if (explored >= explore) break;
      if (take(c)) {
        explored++;
        if (broadFirstRun) exploration.add(c);
      }
    }
    // Wildcard: the best card from a kind not yet in the deck.
    final kindsInDeck = picked.map((c) => c.title.kind).toSet();
    for (final c in scored) {
      if (picked.length >= size) break;
      if (!kindsInDeck.contains(c.title.kind) && take(c)) {
        if (broadFirstRun) exploration.add(c);
        break;
      }
    }
    for (final c in scored) {
      if (picked.length >= size) break;
      take(c);
    }

    final ordered = List.of(picked);
    if (broadFirstRun) {
      ordered.removeWhere(exploration.contains);
      for (var i = 0; i < exploration.length; i++) {
        ordered.insert(min(2 + i * 3, ordered.length), exploration[i]);
      }
    }
    return [
      for (final c in ordered)
        RankedCard(
          c.title,
          c.score,
          reasonFor(c.title, s, f, titlesById: titlesById, now: _now()),
          becauseOf: c.becauseOf,
        ),
    ];
  }

  List<RankedCard> _adaptive(
    List<RankedCard> scored,
    int size,
    ProfileSignals signals,
    List<InterestCluster> clusters,
    double preference,
    Set<String> recent,
  ) {
    final familiar =
        (size *
                (0.55 +
                        0.20 * signals.tasteConfidence -
                        0.35 * preference.clamp(0, 1))
                    .clamp(0.25, 0.60))
            .round();
    final adjacent = (size * 0.20).round();
    final picked = <RankedCard>[];
    final varied = <RankedCard>[];
    final franchises = <String>{};
    bool take(RankedCard c, {bool variety = false}) {
      if (picked.length >= size || !franchises.add(c.title.franchiseKey)) {
        return false;
      }
      picked.add(c);
      if (variety) varied.add(c);
      return true;
    }

    for (final c in scored) {
      if (picked.length >= familiar) break;
      take(c);
    }
    final remaining = scored
        .where(
          (c) =>
              !picked.contains(c) &&
              (c.title.score == null || c.title.score! >= 40),
        )
        .toList();
    for (var i = 0; i < adjacent; i++) {
      final candidates = remaining
          .where(
            (c) =>
                !picked.contains(c) &&
                !franchises.contains(c.title.franchiseKey),
          )
          .toList();
      candidates.sort((a, b) {
        double value(RankedCard c) =>
            (picked.any((p) => p.title.kind == c.title.kind) ? 0 : 1) +
            (clusters.isEmpty
                ? 0
                : clusters.map((g) => g.affinity(c.title)).reduce(max)) +
            (recent.contains(c.title.id) ? 0 : 0.2);
        return value(b).compareTo(value(a));
      });
      if (candidates.isEmpty) break;
      take(candidates.first, variety: true);
    }
    while (picked.length < size) {
      final candidates =
          remaining
              .where(
                (c) =>
                    !picked.contains(c) &&
                    !franchises.contains(c.title.franchiseKey),
              )
              .toList()
            ..shuffle(_random);
      candidates.sort((a, b) {
        double value(RankedCard c) =>
            (picked.any((p) => p.title.kind == c.title.kind) ? 0 : 1) +
            1 / (1 + (signals.kindRatings[c.title.kind] ?? 0)) +
            (recent.contains(c.title.id) ? 0 : 0.2) +
            (c.title.year != null && c.title.year! >= 2023 ? 0.05 : 0);
        return value(b).compareTo(value(a));
      });
      if (candidates.isEmpty) break;
      take(candidates.first, variety: true);
    }
    for (final c in scored) {
      if (picked.length >= size) break;
      take(c);
    }
    final ordered = picked.where((c) => !varied.contains(c)).toList();
    for (var i = 0; i < varied.length; i++) {
      ordered.insert(min(2 + i * 2, ordered.length), varied[i]);
    }
    return [
      for (final c in ordered)
        RankedCard(
          c.title,
          c.score,
          varied.contains(c)
              ? ' Exploring another eligible theme or format.'
              : '',
          becauseOf: c.becauseOf,
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
      'excluded formats': f.copyWith(excludedKinds: {}),
      'excluded genres (unknown genres are also excluded)': f.copyWith(
        excludedGenres: {},
      ),
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
      'No more untried stories in the checked catalog pages. Try a different direction or choose from saved.',
    );
  }
}
