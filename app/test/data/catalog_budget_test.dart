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
    await catalog.fetchNext(MediaKind.anime, mood: 'comfort');
    expect(gateway.calls.last, 'discover:anime:comfort:1');
    now = now.add(const Duration(days: 7));
    await catalog.fetchNext(MediaKind.anime);
    expect(gateway.calls.last, 'discover:anime:-:1');
    expect(await db.select(db.catalogTitles).get(), hasLength(50));
  });
}
