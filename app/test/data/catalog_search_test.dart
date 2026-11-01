import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'uncached remote MAL aliases deduplicate by identity, not title text',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway();
      gateway.searchResults['invented'] = [
        item(40, idMal: 50),
        item(50, provider: 'mal', providerKind: 'anime'),
        item(41),
      ];
      final result = await CatalogRepository(db, gateway).search('invented');
      expect(result.items.map((d) => d.titleId), ['anilist:40', 'anilist:41']);
      expect(await db.select(db.catalogTitles).get(), isEmpty);
    },
  );

  for (final kind in MediaKind.discoverable) {
    test(
      'a cached deck ${kind.name} remains searchable offline by every name',
      () async {
        final db = memoryDb();
        addTearDown(db.close);
        final gateway = FakeGateway(offline: true);
        final catalog = CatalogRepository(db, gateway);
        await catalog.upsert([
          CatalogItemDto({
            ...item(81, kind: kind.name),
            'titleEn': 'Invented Explorer',
            'titleRomaji': 'Sorairo no Tabi',
            'titleNative': '空色の旅',
            'synopsis': 'Synthetic cached details.',
          }),
        ], detailed: true);
        for (final query in ['invented explorer', 'Sorairo no Tabi', '空色の旅']) {
          final result = await catalog.search(query);
          expect(result.items.single.titleId, 'anilist:81');
          expect(result.failureCode, 'offline');
          expect(result.warning, contains('available matches'));
          final id = (await catalog.upsert(result.items)).single;
          expect(id, 'anilist:81');
          expect(
            (await catalog.titleById(id))!.synopsis,
            'Synthetic cached details.',
          );

          expect((await catalog.titleById(id))!.detailed, isTrue);
        }
      },
    );
  }

  test(
    'native-script and accented names remain searchable, not empty keys',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final catalog = CatalogRepository(db, FakeGateway(offline: true));
      await catalog.upsert([
        CatalogItemDto({
          ...item(81),
          'titleEn': 'Invented Café',
          'titleNative': 'Звёздный Странник',
        }),
      ]);
      expect((await catalog.search('Café')).items.single.titleId, 'anilist:81');
      expect(
        (await catalog.search('Звёздный')).items.single.titleId,
        'anilist:81',
      );
    },
  );

  test(
    'remote identity aliases deduplicate without merging unrelated names',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway();
      final catalog = CatalogRepository(db, gateway);
      await catalog.upsert([
        CatalogItemDto({
          ...item(10, provider: 'mal', providerKind: 'anime', idMal: 10),
          'titleEn': 'Invented shared title',
        }),
      ]);
      gateway.searchResults['invented shared title'] = [
        {...item(99, idMal: 10), 'titleEn': 'Invented shared title'},
        {...item(100), 'titleEn': 'Invented shared title'},
      ];
      final result = await catalog.search('Invented shared title');
      expect(result.items, hasLength(2));
      expect(
        result.items.map((d) => d.titleId),
        containsAll(['mal:anime:10', 'anilist:100']),
      );
      expect(result.warning, isNull);
    },
  );

  test(
    'partial results survive and adult cached/remote titles stay hidden',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = _PartialSearch();
      final catalog = CatalogRepository(db, gateway);
      await catalog.upsert([
        CatalogItemDto({...item(1), 'titleEn': 'Invented Cached'}),
        CatalogItemDto({...item(2, adult: true), 'titleEn': 'Invented Hidden'}),
        CatalogItemDto({
          ...item(5, kind: 'manga'),
          'titleEn': 'Invented Novel',
          'format': 'NOVEL',
        }),
      ]);
      final result = await catalog.search('Invented');
      expect(result.items.map((d) => d.titleId), ['anilist:1', 'anilist:3']);
      expect(result.failureCode, 'rate_limited');
      expect(result.warning, contains('busy'));
      expect((await catalog.search('   ')).items, isEmpty);
    },
  );
}

class _PartialSearch extends FakeGateway {
  @override
  Future<List<CatalogItemDto>> search(String query, {MediaKind? kind}) async {
    throw CatalogSearchIncomplete('rate_limited', [
      CatalogItemDto({...item(3), 'titleEn': 'Invented Remote'}),
      CatalogItemDto(item(4, adult: true)),
      CatalogItemDto({...item(6), 'format': 'MUSIC'}),
    ]);
  }
}
