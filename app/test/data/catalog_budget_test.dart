import 'package:cue/data/catalog_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('page 51 is never requested; mood cursors are distinct and expire at seven days', () async {
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
    expect(gateway.calls, hasLength(50));
    expect(gateway.calls.last, 'discover:anime:-:50');
    expect(await catalog.pageState(MediaKind.anime), CatalogPageState.limited);
    expect(await catalog.pageState(MediaKind.manhwa), CatalogPageState.more);
    await catalog.fetchNext(MediaKind.anime, mood: 'comfort');
    expect(gateway.calls.last, 'discover:anime:comfort:1');
    now = now.add(const Duration(days: 7));
    await catalog.fetchNext(MediaKind.anime);
    expect(gateway.calls.last, 'discover:anime:-:1');
    expect(await db.select(db.catalogTitles).get(), hasLength(50));
  });

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
}
