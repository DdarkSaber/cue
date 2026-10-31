import 'dart:math';

import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/quick_mood.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/mood_rules.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/domain/reasons.dart';
import 'package:flutter_test/flutter_test.dart';

Title t(
  String id, {
  MediaKind kind = MediaKind.anime,
  int? year = 2024,
  List<String> genres = const ['Action'],
  int? score = 70,
  int? episodes = 12,
  bool adult = false,
  String? franchise,
  String status = 'finished',
  String? country = 'JP',
  String? name,
}) => Title(
  id: id,
  kind: kind,
  titleEn: name ?? 'Title $id',
  year: year,
  genres: genres,
  score: score,
  episodes: episodes,
  adult: adult,
  franchiseId: franchise,
  status: status,
  country: country,
);

void main() {
  final ranker = Ranker(random: Random(1));
  final all = {...MediaKind.discoverable};
  bool ok(
    Title x, [
    ProfileSignals s = const ProfileSignals(),
    DeckFilters f = const DeckFilters(),
  ]) => ranker.eligible(x, s, f, showAdult: false, enabledKinds: all);

  group('hard filters', () {
    test('adult titles are hidden unless enabled', () {
      final x = t('a', adult: true);
      expect(ok(x), isFalse);
      expect(
        ranker.eligible(
          x,
          const ProfileSignals(),
          const DeckFilters(),
          showAdult: true,
          enabledKinds: all,
        ),
        isTrue,
      );
    });

    test('exclusions, deferrals and shortlist never appear', () {
      const s = ProfileSignals(
        excluded: {'a'},
        deferred: {'b'},
        shortlisted: {'c'},
      );
      expect(ok(t('a'), s), isFalse);
      expect(ok(t('b'), s), isFalse);
      expect(ok(t('c'), s), isFalse);
      expect(ok(t('d'), s), isTrue);
    });

    test(
      'seen titles leave discovery; rewatches come back only when asked',
      () {
        const s = ProfileSignals(
          library: {
            'a': LibraryEntry(titleId: 'a', state: LibraryState.seen),
            'b': LibraryEntry(
              titleId: 'b',
              state: LibraryState.completed,
              rating: Rating.rewatched,
            ),
          },
        );
        expect(ok(t('a'), s), isFalse);
        expect(ok(t('b'), s), isFalse);
        expect(
          ok(t('b'), s, const DeckFilters(includeRewatches: true)),
          isTrue,
        );
        expect(
          ok(t('a'), s, const DeckFilters(includeRewatches: true)),
          isFalse,
        );
      },
    );

    test('Revisit deals only rewatched or would-rewatch titles', () {
      const s = ProfileSignals(
        library: {
          'r': LibraryEntry(
            titleId: 'r',
            state: LibraryState.completed,
            rating: Rating.wouldRewatch,
          ),
          'o': LibraryEntry(
            titleId: 'o',
            state: LibraryState.completed,
            rating: Rating.once,
          ),
        },
      );
      const revisit = DeckFilters(mood: QuickMood.revisit);
      expect(ok(t('r'), s, revisit), isTrue);
      expect(ok(t('o'), s, revisit), isFalse);
      expect(ok(t('new'), s, revisit), isFalse);
    });

    test('filter sheet constraints are hard', () {
      expect(
        ok(
          t('k', kind: MediaKind.kdrama),
          const ProfileSignals(),
          const DeckFilters(kinds: {MediaKind.anime}),
        ),
        isFalse,
      );
      expect(
        ok(
          t('long', episodes: 24),
          const ProfileSignals(),
          const DeckFilters(shortOnly: true),
        ),
        isFalse,
      );
      expect(
        ok(
          t('unknown', episodes: null),
          const ProfileSignals(),
          const DeckFilters(shortOnly: true),
        ),
        isFalse,
      );
      expect(
        ok(
          t('old', year: 2015),
          const ProfileSignals(),
          const DeckFilters(era: EraFilter.newArt),
        ),
        isFalse,
      );
      expect(
        ok(
          t('air', status: 'airing'),
          const ProfileSignals(),
          const DeckFilters(status: StatusFilter.finished),
        ),
        isFalse,
      );
      expect(
        ok(
          t('kr', country: 'KR'),
          const ProfileSignals(),
          const DeckFilters(countries: {'JP'}),
        ),
        isFalse,
      );
    });
  });

  group('deal', () {
    test('one card per franchise and at most ten cards', () {
      final pool = [
        for (var i = 0; i < 30; i++) t('$i', franchise: 'f${i % 15}'),
      ];
      final deck = ranker.deal(
        pool,
        const ProfileSignals(),
        const DeckFilters(),
        showAdult: false,
        enabledKinds: all,
        titlesById: const {},
      );
      expect(deck.length, 10);
      expect(deck.map((c) => c.title.franchiseKey).toSet().length, 10);
    });

    test('includes a wildcard from another kind when one exists', () {
      final pool = [
        for (var i = 0; i < 20; i++) t('a$i', score: 95),
        t('m', kind: MediaKind.manhwa, score: 10, episodes: null),
      ];
      final deck = ranker.deal(
        pool,
        const ProfileSignals(),
        const DeckFilters(),
        showAdult: false,
        enabledKinds: all,
        titlesById: const {},
      );
      expect(deck.any((c) => c.title.kind == MediaKind.manhwa), isTrue);
    });

    test('mood raises titles that match its tag set', () {
      final comfy = t(
        'c',
        genres: const ['Comedy', 'Slice of Life'],
        score: 60,
      );
      final loud = t('l', genres: const ['Action'], score: 60);
      const f = DeckFilters(mood: QuickMood.comfort);
      expect(
        ranker.score(comfy, const ProfileSignals(), f),
        greaterThan(ranker.score(loud, const ProfileSignals(), f)),
      );
    });

    test('cold start uses neutral taste; weights matter after 20 titles', () {
      final x = t('x', genres: const ['Mystery']);
      const cold = ProfileSignals(weights: {'mystery': 9}, evidenceTitles: 5);
      const warm = ProfileSignals(weights: {'mystery': 9}, evidenceTitles: 25);
      expect(
        ranker.score(x, warm, const DeckFilters()),
        greaterThan(ranker.score(x, cold, const DeckFilters())),
      );
    });

    test('unknown score counts as 0.6, never hidden', () {
      final x = t('x', score: null);
      expect(ok(x), isTrue);
    });

    test('session mood leans away from what was just skipped', () {
      final s = SessionMood();
      final action = t('a', genres: const ['Action']);
      final before = ranker.score(
        action,
        const ProfileSignals(),
        const DeckFilters(),
        session: s,
      );
      s.record({'action'}, -0.6);
      s.record({'action'}, -0.6);
      final after = ranker.score(
        action,
        const ProfileSignals(),
        const DeckFilters(),
        session: s,
      );
      expect(after, lessThan(before));
    });

    test('an empty deck names the filter that removed everything', () {
      final pool = [t('a', episodes: 24)];
      final why = ranker.explainEmpty(
        pool,
        const ProfileSignals(),
        const DeckFilters(shortOnly: true),
        showAdult: false,
        enabledKinds: all,
      );
      expect(why.message, contains('Short season'));
    });
  });

  group('reasons', () {
    test('cold start describes the work, never claims favourites', () {
      final r = reasonFor(
        t('x', genres: const ['Fantasy', 'Adventure'], score: 85),
        const ProfileSignals(),
        const DeckFilters(),
        titlesById: const {},
      );
      expect(r, 'Highly rated fantasy and adventure anime.');
      expect(r.toLowerCase(), isNot(contains('favourite')));
    });

    test('cites a rewatched title that shares features', () {
      final seen = t(
        's',
        genres: const ['Sports', 'Action', 'Comedy'],
        name: 'Synthetic Spikers',
      );
      final cand = t('c', genres: const ['Sports', 'Action']);
      const s = ProfileSignals(
        library: {
          's': LibraryEntry(
            titleId: 's',
            state: LibraryState.completed,
            rating: Rating.rewatched,
          ),
        },
        evidenceTitles: 1,
      );
      final r = reasonFor(
        cand,
        s,
        const DeckFilters(),
        titlesById: {'s': seen},
      );
      expect(r, 'Hype like Synthetic Spikers, which you rewatched.');
    });

    test('never longer than 60 characters', () {
      final seen = t('s', genres: const ['Sports', 'Action'], name: 'A' * 80);
      const s = ProfileSignals(
        library: {'s': LibraryEntry(titleId: 's', rating: Rating.rewatched)},
        evidenceTitles: 1,
      );
      final r = reasonFor(
        t('c', genres: const ['Sports', 'Action']),
        s,
        const DeckFilters(),
        titlesById: {'s': seen},
      );
      expect(r.length, lessThanOrEqualTo(maxReasonLength));
    });
  });

  group('Tell me (local rules)', () {
    test('reads format, mood, length and era', () {
      final p = parseMood(
        'something short and cozy, a korean drama with new art',
      );
      expect(p.kinds, {MediaKind.kdrama});
      expect(p.mood, QuickMood.comfort);
      expect(p.shortOnly, isTrue);
      expect(p.era, EraFilter.newArt);
    });

    test('drama alone means K, C and J dramas', () {
      expect(parseMood('a gripping drama').kinds, {
        MediaKind.kdrama,
        MediaKind.cdrama,
        MediaKind.jdrama,
      });
    });

    test('nothing recognised is empty, not a guess', () {
      expect(parseMood('purple elephant').isEmpty, isTrue);
    });

    test('rewatch words turn on rewatches', () {
      expect(parseMood('something to rewatch').rewatches, isTrue);
    });
  });
}
