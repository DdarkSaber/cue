import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('random posters: only cached titles with a poster, adult when '
      'allowed, at most the limit, in a fresh order each time', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final catalog = CatalogRepository(db, FakeGateway());
    await catalog.upsert([
      for (var i = 1; i <= 10; i++)
        CatalogItemDto({...item(i), 'posterUrl': 'https://posters.test/$i'}),
      // No poster, or an empty one: never dealt.
      for (var i = 11; i <= 13; i++) CatalogItemDto(item(i)),
      CatalogItemDto({...item(14), 'posterUrl': ''}),
      for (var i = 21; i <= 24; i++)
        CatalogItemDto({
          ...item(i, adult: true),
          'posterUrl': 'https://posters.test/adult-$i',
        }),
    ]);
    final safe = {for (var i = 1; i <= 10; i++) 'https://posters.test/$i'};
    final adult = {
      for (var i = 21; i <= 24; i++) 'https://posters.test/adult-$i',
    };

    final all = await catalog.randomPosters(limit: 50);
    expect(all.toSet(), safe);
    expect(all, hasLength(10));

    final some = await catalog.randomPosters(limit: 4);
    expect(some, hasLength(4));
    expect(some.toSet(), hasLength(4));
    expect(safe.containsAll(some), isTrue);

    final withAdult = await catalog.randomPosters(limit: 50, showAdult: true);
    expect(withAdult.toSet(), {...safe, ...adult});

    // Shuffled by SQLite: ten draws of ten posters are not all one order.
    final orders = {
      for (var i = 0; i < 10; i++)
        (await catalog.randomPosters(limit: 50)).join(','),
    };
    expect(orders.length, greaterThan(1));
  });

  test('random posters on an empty cache is empty', () async {
    final db = memoryDb();
    addTearDown(db.close);
    expect(await CatalogRepository(db, FakeGateway()).randomPosters(), isEmpty);
  });
}
