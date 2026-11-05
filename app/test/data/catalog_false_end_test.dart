import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/domain/models/title.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

// AniList once answered null filters with an empty first page marked final,
// and Cue remembered that as "no more anime" for a week.
void main() {
  test('an empty first page is not remembered as the end', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeGateway(pages: {MediaKind.anime: []});
    final catalog = CatalogRepository(db, gateway);
    expect(await catalog.fetchNext(MediaKind.anime), 0);
    expect(await db.select(db.catalogPages).get(), isEmpty);
    expect(await catalog.pageState(MediaKind.anime), CatalogPageState.more);
  });

  test('a false end saved by an earlier build is forgotten', () async {
    final db = memoryDb();
    addTearDown(db.close);
    for (final kind in ['anime', 'manhwa', 'kdrama']) {
      await db
          .into(db.catalogPages)
          .insert(
            CatalogPagesCompanion.insert(
              mediaKind: kind,
              mood: const Value(''),
              page: 1,
              hasNext: false,
              fetchedAt: DateTime.now(),
            ),
          );
    }
    final gateway = FakeGateway(
      pages: {
        MediaKind.anime: [
          [item(1), item(2)],
        ],
      },
    );
    final catalog = CatalogRepository(db, gateway);
    expect(await catalog.pageState(MediaKind.anime), CatalogPageState.more);
    expect(await catalog.fetchNext(MediaKind.anime), 2);
    // Worker kinds can truly end on page 1; their rows stay.
    final left = await db.select(db.catalogPages).get();
    expect(
      left.where((p) => p.mediaKind == 'kdrama' && !p.hasNext),
      hasLength(1),
    );
    expect(left.where((p) => p.mediaKind == 'manhwa'), isEmpty);
  });
}
