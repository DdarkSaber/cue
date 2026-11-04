import 'dart:convert';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/request_priority.dart';
import 'package:cue/domain/models/title.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

Future<void> _fill(CueDatabase db, int n, DateTime at) => db.batch((b) {
  for (var i = 0; i < n; i++) {
    b.insert(
      db.catalogTitles,
      CatalogTitlesCompanion.insert(
        id: 'anilist:$i',
        mediaKind: i % 7 == 0 ? 'movie' : 'anime',
        titleEn: Value('Synthetic $i'),
        year: Value(1990 + i % 35),
        country: const Value('JP'),
        format: Value(i % 50 == 1 ? 'NOVEL' : (i % 50 == 2 ? 'MUSIC' : 'TV')),
        episodes: const Value(12),
        genresJson: Value(jsonEncode(['Action', if (i.isEven) 'Drama'])),
        tagsJson: Value(jsonEncode(['t${i % 40}', 't${i % 13}'])),
        score: Value(i % 11 == 0 ? null : 30 + i % 70),
        adult: Value(i % 97 == 3),
        franchiseId: Value(i % 400 == 5 ? 'tmdb:collection:${i % 3}' : null),
        updatedAt: at.add(Duration(seconds: i)),
      ),
    );
  }
});

http.Response _ok() => http.Response(
  jsonEncode({
    'data': {
      'Page': {
        'pageInfo': {'hasNextPage': false},
        'media': <Object>[],
      },
    },
  }),
  200,
);

void main() {
  group('AniList request budget', () {
    test(
      'lets 25 requests through a minute, then waits for the window',
      () async {
        var now = DateTime(2026, 11, 1, 12);
        final sleeps = <Duration>[];
        final client = AniListClient(
          client: MockClient((_) async => _ok()),
          sleep: (d) async {
            sleeps.add(d);
            now = now.add(d);
          },
          clock: () => now,
        );
        for (var i = 0; i < 25; i++) {
          await client.discover(MediaKind.anime);
        }
        expect(sleeps, isEmpty);
        await client.discover(MediaKind.anime);
        expect(sleeps, hasLength(1));
        expect(sleeps.single, greaterThan(const Duration(seconds: 55)));
      },
    );

    test('a waiting deck refill goes before seeds and AI lookups', () async {
      var now = DateTime(2026, 11, 1, 12);
      final order = <String>[];
      final client = AniListClient(
        client: MockClient((_) async => _ok()),
        // The wait ends a moment later, as a real timer would.
        sleep: (d) async {
          await Future<void>.delayed(Duration.zero);
          now = now.add(d);
        },
        clock: () => now,
      );
      for (var i = 0; i < 25; i++) {
        await client.discover(MediaKind.anime);
      }
      Future<void> ask(RequestPriority p) => withRequestPriority(
        p,
        () => client.discover(MediaKind.anime),
      ).then((_) => order.add(p.name));
      await Future.wait([
        ask(RequestPriority.ai),
        ask(RequestPriority.seed),
        ask(RequestPriority.deck),
      ]);
      expect(order, ['deck', 'seed', 'ai']);
    });

    test('a 429 carries the Retry-After it was given', () async {
      final client = AniListClient(
        client: MockClient(
          (_) async => http.Response('{}', 429, headers: {'retry-after': '9'}),
        ),
        sleep: (_) async {},
      );
      await expectLater(
        client.discover(MediaKind.anime),
        throwsA(
          isA<CatalogUnavailable>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 9),
              ),
        ),
      );
    });
  });

  group('candidate pool at scale', () {
    test(
      '20k cached titles: exclusions and the cap hold, and it is quick',
      () async {
        final db = memoryDb();
        addTearDown(db.close);
        await _fill(db, 20000, DateTime(2026, 1, 1));
        final repo = CatalogRepository(db, FakeGateway());
        final excluded = {for (var i = 0; i < 20000; i += 9) 'anilist:$i'};

        final watch = Stopwatch()..start();
        final pool = await repo.candidatePool(
          {MediaKind.anime},
          excludeIds: excluded,
          excludeFranchises: {'tmdb:collection:1'},
        );
        watch.stop();

        expect(
          pool.length,
          lessThanOrEqualTo(CatalogRepository.candidateLimit),
        );
        expect(pool.length, greaterThan(5000));
        expect(pool.every((t) => t.kind == MediaKind.anime), isTrue);
        expect(pool.any((t) => excluded.contains(t.id)), isFalse);
        expect(pool.any((t) => t.adult), isFalse);
        expect(
          pool.any((t) => t.format == 'NOVEL' || t.format == 'MUSIC'),
          isFalse,
        );
        expect(pool.any((t) => t.franchiseId == 'tmdb:collection:1'), isFalse);
        expect(pool.map((t) => t.id).toSet(), hasLength(pool.length));
        // Generous: a full unfiltered load of these rows is several times this.
        expect(watch.elapsed, lessThan(const Duration(seconds: 20)));

        final all = await repo.candidatePool(
          {MediaKind.anime},
          excludeIds: excluded,
          limit: null,
        );
        expect(all.length, greaterThan(pool.length));
        expect(all.any((t) => excluded.contains(t.id)), isFalse);
        // The old behaviour is still available to search.
        expect((await repo.pool(MediaKind.values)).length, 20000);
      },
    );

    test('adult titles come back only when asked for', () async {
      final db = memoryDb();
      addTearDown(db.close);
      await _fill(db, 400, DateTime(2026, 1, 1));
      final repo = CatalogRepository(db, FakeGateway());
      final hidden = await repo.candidatePool(MediaKind.values, limit: null);
      final shown = await repo.candidatePool(
        MediaKind.values,
        limit: null,
        showAdult: true,
      );
      expect(hidden.any((t) => t.adult), isFalse);
      expect(shown.any((t) => t.adult), isTrue);
    });
  });

  group('recommendation edge pruning', () {
    Future<int> edges(CueDatabase db) async =>
        (await db.select(db.catalogRecommendations).get()).length;

    test('keeps current seeds and recent rows, once a day', () async {
      final db = memoryDb();
      addTearDown(db.close);
      var now = DateTime(2026, 11, 1, 12);
      final repo = CatalogRepository(db, FakeGateway(), clock: () => now);
      Future<void> edge(String seed, String title, Duration age) => db
          .into(db.catalogRecommendations)
          .insert(
            CatalogRecommendationsCompanion.insert(
              seedId: seed,
              titleId: title,
              rank: 0,
              fetchedAt: now.subtract(age),
            ),
          );
      await edge('keep', 'a', const Duration(days: 200)); // current seed
      await edge('old', 'b', const Duration(days: 200)); // dropped
      await edge('old', 'c', const Duration(days: 30)); // recent
      await edge('gone', 'd', const Duration(days: 91)); // dropped

      expect(await repo.pruneRecommendations(['keep']), 2);
      expect(
        {
          for (final r in await db.select(db.catalogRecommendations).get())
            r.titleId,
        },
        {'a', 'c'},
      );

      // Within the day nothing runs again.
      await edge('old', 'e', const Duration(days: 300));
      expect(await repo.pruneRecommendations(['keep']), 0);
      expect(await edges(db), 3);

      now = now.add(const Duration(hours: 25));
      expect(await repo.pruneRecommendations(['keep']), 1);
      expect(await edges(db), 2);
    });
  });
}
