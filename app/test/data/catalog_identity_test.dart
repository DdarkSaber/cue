import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'list updates retain detailed metadata and still link identities',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final catalog = CatalogRepository(db, FakeGateway());
      final legacy = CatalogItemDto(
        item(55, provider: 'mal', providerKind: 'anime', idMal: 55),
      );
      await catalog.upsert([legacy], detailed: true);
      final alias = CatalogItemDto(item(1, idMal: 55, title: 'List metadata'));
      expect(await catalog.upsert([alias]), [legacy.titleId]);
      expect(await catalog.findByIdentity('anilist', '1'), legacy.titleId);
      expect(
        (await catalog.titleById(legacy.titleId))!.displayTitle,
        'Synthetic 55',
      );
      expect(await catalog.upsert([CatalogItemDto(item(1))]), [legacy.titleId]);
      expect(await db.select(db.catalogTitles).get(), hasLength(1));
    },
  );

  test(
    'shared identities arriving together create only one catalog row',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final catalog = CatalogRepository(db, FakeGateway());
      final legacy = CatalogItemDto(
        item(55, provider: 'mal', providerKind: 'anime', idMal: 55),
      );
      final alias = CatalogItemDto(item(1, idMal: 55));
      expect(await catalog.upsert([legacy, alias]), [
        legacy.titleId,
        legacy.titleId,
      ]);
      expect(await db.select(db.catalogTitles).get(), hasLength(1));
      expect(await catalog.findByIdentity('anilist', '1'), legacy.titleId);
    },
  );
}
