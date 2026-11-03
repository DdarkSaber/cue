import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'no page ceiling; mood cursors are distinct and expire at seven days',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            for (var i = 1; i <= 55; i++) [item(i)],
          ],
        },
      );
      var now = DateTime.utc(2026, 1, 1);
      final catalog = CatalogRepository(db, gateway, clock: () => now);
      for (var i = 0; i < 53; i++) {
        await catalog.fetchNext(MediaKind.anime);
      }
      // Pages past 50 are asked for: a big library needs depth.
      expect(gateway.calls, hasLength(53));
      expect(gateway.calls.last, 'discover:anime:-:53');
      expect(await catalog.pageState(MediaKind.anime), CatalogPageState.more);
      expect(await catalog.pageState(MediaKind.manhwa), CatalogPageState.more);
      await catalog.fetchNext(MediaKind.anime, mood: 'comfort');
      // Its own cursor from page 1; these titles are already cached, so the
      // call digs on, but no further than its bound.
      expect(gateway.calls.skip(53), [
        'discover:anime:comfort:1',
        'discover:anime:comfort:2',
        'discover:anime:comfort:3',
      ]);
      now = now.add(const Duration(days: 7));
      await catalog.fetchNext(MediaKind.anime);
      expect(gateway.calls[56], 'discover:anime:-:1');
      expect(await db.select(db.catalogTitles).get(), hasLength(53));
    },
  );

  test('an empty nonterminal page does not mean catalog exhaustion', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final catalog = CatalogRepository(
      db,
      FakeGateway(
        pages: {
          MediaKind.anime: [
            [],
            [item(1)],
          ],
        },
      ),
    );
    expect(await catalog.fetchNext(MediaKind.anime), 0);
    expect(await catalog.pageState(MediaKind.anime), CatalogPageState.more);
    expect(await catalog.fetchNext(MediaKind.anime), 1);
    expect(
      await catalog.pageState(MediaKind.anime),
      CatalogPageState.exhausted,
    );
  });

  test('orders take turns, each with its own cursor, and only all final pages exhaust', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeGateway(
      pages: {
        MediaKind.anime: [
          [for (var i = 1; i <= 20; i++) item(i)],
          [for (var i = 21; i <= 40; i++) item(i)],
        ],
      },
    );
    gateway.sorts[MediaKind.anime] = ['POPULARITY_DESC', 'SCORE_DESC'];
    gateway.sortedPages['anime:SCORE_DESC'] = [
      [for (var i = 101; i <= 120; i++) item(i)],
    ];
    final catalog = CatalogRepository(db, gateway);
    for (var i = 0; i < 3; i++) {
      await catalog.fetchNext(MediaKind.anime);
    }
    expect(gateway.calls, [
      'discover:anime:-:1',
      'discover:anime:-:1:SCORE_DESC',
      'discover:anime:-:2',
    ]);
    expect(
      await catalog.pageState(MediaKind.anime),
      CatalogPageState.exhausted,
    );
    expect(await catalog.fetchNext(MediaKind.anime), 0);
    expect(gateway.calls, hasLength(3));
  });

  test(
    'a page of mostly known titles digs deeper within one bounded call',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final known = [for (var i = 1; i <= 200; i++) item(i)];
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            for (var p = 0; p < 4; p++)
              [...known.skip(p * 50).take(48), item(1000 + p), item(2000 + p)],
            [for (var i = 3000; i < 3050; i++) item(i)],
          ],
        },
      );
      final catalog = CatalogRepository(db, gateway);
      await catalog.upsert([for (final i in known) CatalogItemDto(i)]);
      final arrived = await catalog.fetchNext(MediaKind.anime);
      // Two new titles a page is not enough, but one call stays bounded.
      expect(gateway.calls, hasLength(CatalogRepository.maxPagesPerFetch));
      expect(arrived, 150);
      await catalog.fetchNext(MediaKind.anime);
      // The fourth page is still mostly known; the fifth is all new.
      expect(gateway.calls.last, 'discover:anime:-:5');
    },
  );
}
