import 'dart:math';

import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:flutter_test/flutter_test.dart';

Title _t(
  String id, {
  List<String> genres = const ['Action'],
  List<String> tags = const [],
  int score = 70,
  MediaKind kind = MediaKind.anime,
}) => Title(
  id: id,
  kind: kind,
  titleEn: 'Title $id',
  year: 2024,
  genres: genres,
  tags: tags,
  score: score,
  episodes: 12,
  status: 'finished',
  country: 'JP',
);

const _genres = [
  'Action',
  'Comedy',
  'Drama',
  'Fantasy',
  'Mystery',
  'Sci-Fi',
  'Slice of Life',
  'Sports',
  'Thriller',
  'Adventure',
];

void main() {
  final all = {...MediaKind.discoverable};
  const f = DeckFilters();

  List<RankedCard> deal(
    List<Title> pool,
    ProfileSignals s, {
    int seed = 1,
    double? explore = 0.35,
  }) => Ranker(random: Random(seed)).deal(
    pool,
    s,
    f,
    showAdult: false,
    enabledKinds: all,
    titlesById: {for (final t in pool) t.id: t},
    explorePreference: explore,
  );

  group('also liked (co-visitation)', () {
    test('is 0 without edges and saturates with strong agreeing seeds', () {
      const s = ProfileSignals(
        becauseOf: {
          'one': ['a'],
          'deep': ['a'],
          'many': ['a', 'b', 'c'],
        },
        becauseRank: {
          'one': [0],
          'deep': [20],
          'many': [0, 0, 0],
        },
        seedStrength: {'a': 1, 'b': 1, 'c': 1},
      );
      expect(Ranker.coVisit('none', s), 0);
      expect(Ranker.coVisit('one', s), closeTo(1 - exp(-1), 1e-9));
      expect(Ranker.coVisit('deep', s), closeTo(1 - exp(-1 / 5), 1e-9));
      expect(Ranker.coVisit('many', s), closeTo(1 - exp(-3), 1e-9));
      expect(Ranker.rankDecay(5), 0.5);
    });

    test('weak seeds count less than strong ones', () {
      const s = ProfileSignals(
        becauseOf: {
          'strong': ['fav'],
          'weak': ['once'],
        },
        seedStrength: {'fav': 1.6, 'once': 0.35},
      );
      expect(
        Ranker.coVisit('strong', s),
        greaterThan(Ranker.coVisit('weak', s)),
      );
    });

    test('seeded candidates take most of the familiar slots', () {
      final seeded = [
        for (var i = 0; i < 10; i++)
          _t('s$i', genres: [_genres[i % _genres.length]]),
      ];
      final unseeded = [
        for (var i = 0; i < 50; i++)
          _t('u$i', genres: [_genres[i % _genres.length]], score: 70 + i % 15),
      ];
      final s = ProfileSignals(
        tasteSeeds: const ['liked'],
        becauseOf: {
          for (final t in seeded) t.id: const ['liked'],
        },
        becauseRank: {
          for (var i = 0; i < seeded.length; i++) seeded[i].id: [i],
        },
        seedStrength: const {'liked': 1},
      );
      for (var seed = 1; seed <= 5; seed++) {
        final cards = deal([...unseeded, ...seeded], s, seed: seed);
        final firstSix = cards.take(6).where((c) => c.title.id[0] == 's');
        expect(firstSix.length, greaterThanOrEqualTo(4), reason: 'seed $seed');
        // Seeded cards still say why.
        for (final c in firstSix) {
          expect(c.becauseOf, ['liked']);
        }
      }
    });
  });

  group('session seeds', () {
    test('a save boosts what it recommends, fading with each decision', () {
      final seeds = SessionSeeds()..add('saved', {'a': 0, 'b': 5});
      expect(seeds.bonus('a'), closeTo(0.10, 1e-12));
      expect(seeds.bonus('z'), 0);
      expect(seeds.edgeSum('b'), closeTo(0.5, 1e-12));
      const s = ProfileSignals();
      expect(
        Ranker.coVisit('a', s, session: seeds),
        closeTo(1 - exp(-1), 1e-12),
      );
      final ranker = Ranker();
      final base = ranker.score(_t('a'), s, f);
      final boosted = ranker.score(_t('a'), s, f, sessionSeeds: seeds);
      expect(
        boosted - base,
        closeTo(0.10 + Ranker.coVisitWeight * (1 - exp(-1)), 1e-9),
      );
      seeds.record();
      expect(seeds.bonus('a'), closeTo(0.085, 1e-12));
      for (var i = 0; i < 30; i++) {
        seeds.record();
      }
      expect(seeds.isEmpty, isTrue);
    });
  });

  group('negatives', () {
    test('three rejections sharing a feature suppress it for the session', () {
      final s = SessionSuppression();
      s.reject({'romance', 'school'});
      s.reject({'romance', 'drama'});
      expect(s.penaltyFor({'romance'}), 0);
      s.reject({'romance'});
      expect(s.suppressed, {'romance'});
      expect(s.penaltyFor({'romance', 'action'}), SessionSuppression.penalty);
      expect(s.penaltyFor({'action'}), 0);
      // Penalised, not excluded: the score drops by exactly the penalty.
      final ranker = Ranker();
      const p = ProfileSignals();
      final title = _t('r', genres: const ['Romance']);
      expect(
        ranker.score(title, p, f) - ranker.score(title, p, f, suppression: s),
        closeTo(SessionSuppression.penalty, 1e-9),
      );
      // Saving a card with it lifts the suppression, and the count restarts.
      s.save({'romance', 'comedy'});
      expect(s.suppressed, isEmpty);
      s.reject({'romance'});
      expect(s.suppressed, isEmpty);
    });

    test('long-term penalty is the mean of the two worst feature weights', () {
      const weights = {'gore': -3.0, 'ecchi': -2.0, 'action': 1.0};
      expect(
        Ranker.penaltyOf({'gore', 'action'}, weights),
        closeTo(0.15, 1e-12),
      );
      expect(
        Ranker.penaltyOf({'gore', 'ecchi', 'action'}, weights),
        closeTo(0.25, 1e-12),
      );
      expect(Ranker.penaltyOf({'action'}, weights), 0);
      expect(Ranker.penaltyOf({'a', 'b'}, const {'a': -9.0, 'b': -8.0}), 0.3);
    });
  });

  group('theme cap', () {
    final romance = [
      for (var i = 0; i < 10; i++)
        _t('r$i', genres: const ['Romance'], score: 95),
    ];
    final others = [
      for (var i = 0; i < 20; i++)
        _t('o$i', genres: [_genres[i % _genres.length]], score: 55),
    ];

    test('primary theme is the rarest genre in the pool, ties by name', () {
      final pool = [
        _t('a', genres: const ['Action', 'Romance']),
        _t('b', genres: const ['Action']),
        _t('c', genres: const ['Action', 'Comedy']),
        _t('d', genres: const ['Zany', 'Comedy']),
        _t('e', genres: const []),
      ];
      final themes = Ranker.primaryThemes(pool);
      expect(themes['a'], 'romance');
      expect(themes['b'], 'action');
      // Comedy (2 titles) is commoner than Zany (1).
      expect(themes['d'], 'zany');
      expect(themes['c'], 'comedy');
      expect(themes.containsKey('e'), isFalse);
      expect(Ranker.themeCap(10), 2);
      expect(Ranker.themeCap(20), 4);
    });

    for (final explore in [0.35, null]) {
      test('at most two Romance-primary cards in ten (explore $explore)', () {
        for (var seed = 1; seed <= 5; seed++) {
          final cards = deal(
            [...romance, ...others],
            const ProfileSignals(),
            seed: seed,
            explore: explore,
          );
          expect(cards, hasLength(10));
          final n = cards
              .take(10)
              .where((c) => c.title.genres.contains('Romance'))
              .length;
          expect(n, lessThanOrEqualTo(2), reason: 'seed $seed');
          // The best of the capped theme still lead.
          expect(
            cards.where((c) => c.title.genres.contains('Romance')),
            isNotEmpty,
          );
        }
      });

      test('the cap never shortens the deck (explore $explore)', () {
        final cards = deal(
          [
            ...romance,
            _t('x', genres: const ['Action']),
          ],
          const ProfileSignals(),
          explore: explore,
        );
        expect(cards, hasLength(10));
      });
    }
  });
}
