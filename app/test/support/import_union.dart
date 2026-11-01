import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/imports/adapters/list_api.dart';
import 'package:cue/imports/adapters/xlsx_import.dart';
import 'package:cue/imports/import_service.dart';

import '../imports/xlsx_test.dart' show buildXlsx;
import 'fakes.dart';

class ImportUnionFixture {
  const ImportUnionFixture(this.profile, this.gateway, this.historyIds);
  final String profile;
  final FakeGateway gateway;
  final Set<String> historyIds;
}

/// Excel plus a read-only MAL response, using invented titles only.
Future<ImportUnionFixture> seedImportUnion(CueDatabase db) async {
  final catalogItems = [
    for (var i = 1; i <= 12; i++)
      item(
        i,
        title: 'Invented story',
        kind: i >= 10
            ? 'kdrama'
            : (i >= 3 && i <= 6 || i == 9)
            ? 'manhwa'
            : 'anime',
        country: i >= 10 || i >= 3 && i <= 6 || i == 9 ? 'KR' : 'JP',
        idMal: i == 1 ? 55 : (i == 7 ? 95 : null),
        genres: i == 10 || i == 12 ? ['Comedy'] : ['Action'],
        tags: i == 1 ? ['Male Protagonist'] : [],
      ),
  ];
  final gateway = FakeGateway(
    pages: {
      for (final kind in [MediaKind.anime, MediaKind.manhwa, MediaKind.kdrama])
        kind: [
          [
            for (final dto in catalogItems)
              if (dto['kind'] == kind.name) dto,
          ],
        ],
    },
  );
  for (final dto in catalogItems) {
    gateway.matchCatalog[(dto['titleEn'] as String).toLowerCase()] = [dto];
  }
  gateway.malCatalog[55] = catalogItems.first;
  gateway.malCatalog[95] = catalogItems[6];
  final profile = (await ProfileRepository(db).ensureActive()).id;
  final catalog = CatalogRepository(db, gateway);
  final service = ImportService(db, catalog);
  final bytes = buildXlsx({
    'Anime': [
      ['Title', 'Status', 'Rating'],
      ['Invented story 1', 'Finished', 'Would rewatch'],
      ['Invented story 2', 'Watching'],
    ],
    'Reading': [
      ['Title', 'Kind', 'Status'],
      ['Invented story 3', 'Manhwa', 'Caught up'],
      ['Invented story 4', 'Manhwa', 'Reading'],
      ['Invented story 5', 'Manhwa', 'In library, not started'],
      ['Invented story 6', 'Manhwa', 'Read (from review)'],
    ],
  });
  await service.commit(
    profile,
    await service.stage(
      profile,
      XlsxImportAdapter().parse(bytes),
      rawBytes: bytes,
    ),
  );
  final mal = parseListEntries('mal', [
    {
      'title': 'Another name for invented story 1',
      'kind': 'anime',
      'malId': 55,
      'status': 'completed',
      'score': 0,
    },
    {
      'title': 'Invented story 7',
      'kind': 'anime',
      'malId': 95,
      'status': 'completed',
      'score': 0,
    },
  ]);
  await service.commit(profile, await service.stage(profile, mal));
  await catalog.upsert(catalogItems.map(CatalogItemDto.new).toList());
  return ImportUnionFixture(profile, gateway, {
    for (var i = 1; i <= 7; i++) 'anilist:$i',
  });
}
