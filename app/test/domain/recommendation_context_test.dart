import 'dart:math';

import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/domain/recommendation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const comedy = Title(
    id: 'c',
    titleEn: 'Invented comedy',
    kind: MediaKind.anime,
    genres: ['Comedy'],
    score: 80,
    year: 2025,
  );
  test(
    'temporary feedback is bounded, expires by gap/day/profile, never ratings',
    () {
      var now = DateTime(2026, 1, 1, 12);
      final session = RecommendationSession(clock: () => now);
      final weights = <String, double>{'comedy': 3};
      final signals = ProfileSignals(weights: weights, evidenceStrength: 1);
      expect(session.activate('a'), isTrue);
      session.feedback(comedy, more: true);
      session.explore(1);
      expect(session.bias.lean(comedy.features), 0.6);
      final ranker = Ranker();
      final base = ranker.score(comedy, signals, const DeckFilters());
      expect(
        ranker.score(
          comedy,
          signals,
          const DeckFilters(),
          temporary: session.bias,
        ),
        greaterThan(base),
      );
      expect(weights, {'comedy': 3});
      expect(signals.library, isEmpty);
      for (var i = 0; i < 20; i++) {
        session.feedback(comedy, more: false);
      }
      expect(session.bias.bias.values.every((v) => v.abs() <= 1.5), isTrue);
      now = now.add(const Duration(minutes: 44));
      expect(session.activate('a'), isFalse);
      now = now.add(const Duration(minutes: 45));
      expect(session.activate('a'), isTrue);
      expect(session.bias.bias, isEmpty);
      expect(session.exploration, 0.35);
      session.feedback(comedy, more: true);
      expect(session.activate('b'), isTrue);
      expect(session.bias.bias, isEmpty);
      now = DateTime(2026, 1, 1, 23, 55);
      session.activate('b');
      session.feedback(comedy, more: true);
      now = DateTime(2026, 1, 2, 0, 1);
      expect(session.activate('b'), isTrue);
      expect(session.bias.bias, isEmpty);
    },
  );
  test(
    'clusters are bounded, distinct and explicit ratings dominate weak themes',
    () {
      final titles = {
        'c': comedy,
        'w': const Title(id: 'w', kind: MediaKind.manhwa, genres: ['Action']),
        'd': const Title(id: 'd', kind: MediaKind.movie, genres: ['Horror']),
        'p': const Title(id: 'p', kind: MediaKind.series, genres: ['Romance']),
      };
      const s = ProfileSignals(
        library: {
          'c': LibraryEntry(titleId: 'c', rating: Rating.favourite),
          'w': LibraryEntry(titleId: 'w', state: LibraryState.watching),
          'd': LibraryEntry(titleId: 'd', rating: Rating.dropped),
          'p': LibraryEntry(titleId: 'p', state: LibraryState.planned),
        },
        weakHistoryIds: {'w'},
        weights: {'comedy': 3, 'action': 0.2, 'horror': -1.5},
      );
      final clusters = interestClusters(s, titles);
      expect(clusters.length, 2);
      expect(clusters.expand((c) => c.features), isNot(contains('horror')));
      expect(clusters.expand((c) => c.features), isNot(contains('romance')));
      expect(clusterAffinity(comedy, clusters), 1);
      expect(clusterAffinity(titles['w']!, clusters), closeTo(0.2 / 3, 0.001));
    },
  );
  test(
    'Try now is idempotent and Undo preserves newer temporary trait choices',
    () {
      final s = RecommendationSession()..activate('a');
      s.immediateInterest(comedy, 'intent');
      s.immediateInterest(comedy, 'intent');
      expect(s.bias.lean(comedy.features), closeTo(0.9, 0.00001));
      s.trait(comedy, 'Comedy');
      s.undoInterest('intent');
      expect(s.bias.lean(comedy.features), closeTo(0.6, 0.00001));
      expect(() => s.trait(comedy, 'invented appeal'), throwsArgumentError);
      s.activate('b');
      expect(s.bias.bias, isEmpty);
    },
  );
  test(
    'Surprise lasts five choices and reasons stay temporary without ratings',
    () {
      final s = RecommendationSession()..activate('a');
      s.explore(0.2);
      s.surprise();
      for (var i = 0; i < 5; i++) {
        expect(s.effectiveExploration, 1);
        s.choice(notNow: false, eventId: '$i');
      }
      expect(s.effectiveExploration, 0.2);
      s.choice(notNow: true, eventId: 'length', reason: NotNowReason.tooLong);
      expect(s.preferShorter, isTrue);
      s.undoInterest('length');
      expect(s.preferShorter, isFalse);
      s.reset();
      for (var i = 0; i < 3; i++) {
        expect(
          s.choice(
            notNow: true,
            eventId: 'later$i',
            reason: NotNowReason.savingLater,
          ),
          isFalse,
        );
      }
      expect(s.repeatedNotNow, isFalse);
      expect(s.choice(notNow: true, eventId: 'n1'), isFalse);
      expect(s.choice(notNow: true, eventId: 'n2'), isFalse);
      expect(s.choice(notNow: true, eventId: 'n3'), isTrue);
      expect(s.choice(notNow: true, eventId: 'n4'), isFalse);
      s.differentDirection();
      expect(s.effectiveExploration, 1);
      expect(s.bias.bias, isEmpty);
      expect(s.repeatedNotNow, isFalse);
    },
  );
  test('retrieval is fair, rotated, <=12 requests, supported moods only', () {
    final kinds = MediaKind.discoverable.toSet();
    const clusters = [
      InterestCluster({'comedy', 'action', 'mystery'}, 3),
    ];
    for (var round = 0; round < 30; round++) {
      final plan = retrievalPlan(kinds, clusters, {}, round);
      expect(plan.length, lessThanOrEqualTo(12));
      expect(
        plan.where((r) => r.route == 'broad').map((r) => r.kind).toSet(),
        kinds,
      );
      expect(
        plan.every(
          (r) =>
              r.mood == null ||
              {'hype', 'comfort', 'gripping', 'feels'}.contains(r.mood),
        ),
        isTrue,
      );
      expect(
        plan.first.kind,
        (kinds.toList()
          ..sort((a, b) => a.index.compareTo(b.index)))[round % kinds.length],
      );
    }
    final filtered = retrievalPlan(
      {MediaKind.movie},
      clusters,
      {},
      0,
      explicitMood: 'comfort',
    );
    expect(filtered.length, 2);
    expect(filtered.every((r) => r.kind == MediaKind.movie), isTrue);
    expect(filtered.first.mood, isNull);
    expect(filtered.last.mood, 'comfort');
  });
  test('adaptive allocation preserves hard constraints and mixes early across seeds', () {
    final pool = [
      for (var i = 0; i < 40; i++)
        Title(
          id: 'm$i',
          titleEn: 'Invented reading $i',
          kind: MediaKind.manhwa,
          genres: const ['Action'],
          score: 95,
          year: 2025,
        ),
      for (final k in [
        MediaKind.anime,
        MediaKind.movie,
        MediaKind.kdrama,
        MediaKind.series,
      ])
        for (var i = 0; i < 8; i++)
          Title(
            id: '${k.name}$i',
            titleEn: 'Invented ${k.name} $i',
            kind: k,
            genres: const ['Comedy'],
            score: 65,
            year: 2024,
          ),
      const Title(
        id: 'adult',
        titleEn: 'Invented adult',
        adult: true,
        kind: MediaKind.anime,
        score: 100,
      ),
    ];
    for (var seed = 0; seed < 30; seed++) {
      final ranker = Ranker(random: Random(seed));
      for (final explore in [0.0, 0.35, 1.0]) {
        final deck = ranker.deal(
          pool,
          const ProfileSignals(),
          const DeckFilters(),
          showAdult: false,
          enabledKinds: MediaKind.discoverable.toSet(),
          titlesById: {for (final t in pool) t.id: t},
          explorePreference: explore,
        );
        expect(deck.length, 10);
        expect(deck.every((c) => c.reason.length <= 60), isTrue);
        expect(deck.every((c) => c.title.id != 'adult'), isTrue);
        expect(
          deck.map((c) => c.title.kind).toSet().length,
          greaterThanOrEqualTo(4),
        );
        expect(
          deck.take(3).map((c) => c.title.kind).toSet().length,
          greaterThanOrEqualTo(2),
        );
        expect(deck.map((c) => c.title.franchiseKey).toSet().length, 10);
      }
      final deck = ranker.deal(
        pool,
        const ProfileSignals(),
        const DeckFilters(kinds: {MediaKind.movie}, excludedGenres: {'horror'}),
        showAdult: false,
        enabledKinds: MediaKind.discoverable.toSet(),
        titlesById: {for (final t in pool) t.id: t},
        explorePreference: 1,
      );
      expect(
        deck.every(
          (c) =>
              c.title.kind == MediaKind.movie &&
              c.title.genres.contains('Comedy'),
        ),
        isTrue,
      );
    }
  });
  test('recent exposures are soft penalties, never permanent exclusions', () {
    final r = Ranker();
    const s = ProfileSignals();
    final score = r.score(comedy, s, const DeckFilters());
    expect(
      r.score(comedy, s, const DeckFilters(), recentExposures: {'c'}),
      closeTo(score - 0.04, 0.00001),
    );
    expect(
      r.eligible(
        comedy,
        s,
        const DeckFilters(),
        showAdult: false,
        enabledKinds: {MediaKind.anime},
      ),
      isTrue,
    );
  });
  test('missing feature metadata remains neutral even with strong interest clusters', () {
    const unknown = Title(id: 'unknown', kind: MediaKind.anime);
    final r = Ranker();
    const s = ProfileSignals(weights: {'comedy': 3}, evidenceStrength: 20);
    const clusters = [
      InterestCluster({'comedy'}, 3),
    ];
    expect(
      r.score(unknown, s, const DeckFilters(), clusters: clusters),
      r.score(unknown, const ProfileSignals(), const DeckFilters()),
    );
  });
}
