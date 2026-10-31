import 'dart:convert';
import 'dart:typed_data';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/matcher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Uint8List backup(List<Map<String, Object?>> items) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({'cue': 'backup', 'schema_version': 1, 'items': items}),
  ),
);

void main() {
  late CueDatabase db;
  late FakeGateway gateway;
  late CatalogRepository catalog;
  late ImportService service;
  late LibraryRepository library;
  late String profile;

  setUp(() async {
    db = memoryDb();
    gateway = FakeGateway();
    catalog = CatalogRepository(db, gateway);
    service = ImportService(db, catalog);
    library = LibraryRepository(db);
    profile = (await ProfileRepository(db).ensureActive()).id;
    gateway.matchCatalog['synthetic one'] = [
      item(
        1,
        title: 'Synthetic One',
      ).map((k, v) => MapEntry(k, k == 'titleEn' ? 'Synthetic One' : v)),
    ];
    gateway.matchCatalog['synthetic two'] = [
      item(
        2,
        kind: 'manhwa',
        title: 'x',
      ).map((k, v) => MapEntry(k, k == 'titleEn' ? 'Synthetic Two' : v)),
    ];
    gateway.matchCatalog['close but no'] = [
      item(3)
          .map((k, v) => MapEntry(k, k == 'titleEn' ? 'Different Title' : v)),
    ];
  });

  tearDown(() => db.close());

  final file = backup([
    {
      'title': 'Synthetic One',
      'media': 'anime',
      'status': 'completed',
      'rating': 'rewatched',
      'rewatch_mood': 'Comfort',
    },
    {'title': 'Synthetic Two', 'media': 'manhwa', 'status': 'reading'},
    {'title': 'Close but no', 'media': 'anime', 'status': 'seen'},
  ]);

  Future<StagedImport> stage(Uint8List bytes) => service.stage(
    profile,
    parseDetected(detect(bytes, 'b.json')),
    rawBytes: bytes,
  );

  test('matches by exact title, queues the rest, batches requests', () async {
    final s = await stage(file);
    expect(
      s.matched.where((m) => m.matchClass == MatchClass.suggested).length,
      2,
    );
    expect(s.needsReview, 1);
    expect(gateway.matchCalls, 1);
  });

  test('commit adds, then the same file again changes nothing', () async {
    final first = await service.commit(profile, await stage(file));
    expect(first.added, 2);
    expect(first.review, 1);
    final e = await library.entry(profile, 'anilist:1');
    expect(e!.rating, Rating.rewatched);
    expect(e.rewatchMood, RewatchMood.comfort);

    final again = await service.commit(profile, await stage(file));
    expect(again.alreadyImported, isTrue);
    expect((await db.select(db.userTitles).get()).length, 2);
  });

  test('a different file with the same records is idempotent', () async {
    await service.commit(profile, await stage(file));
    final reordered = backup([
      {'title': 'Synthetic Two', 'media': 'manhwa', 'status': 'reading'},
      {
        'title': 'Synthetic One',
        'media': 'anime',
        'status': 'completed',
        'rating': 'rewatched',
        'rewatch_mood': 'Comfort',
      },
    ]);
    final r = await service.commit(profile, await stage(reordered));
    expect(r.added, 0);
    expect(r.updated, 0);
    expect(r.unchanged, 2);
  });

  test('a manual edit in Cue wins over a later import', () async {
    await service.commit(profile, await stage(file));
    await library.saveEntry(
      profile,
      'anilist:2',
      state: LibraryState.dropped,
      rating: Rating.dropped,
    );
    final upgraded = backup([
      {
        'title': 'Synthetic Two',
        'media': 'manhwa',
        'status': 'completed',
        'rating': 'favourite',
      },
    ]);
    await service.commit(profile, await stage(upgraded));
    final e = await library.entry(profile, 'anilist:2');
    expect(e!.state, LibraryState.dropped);
    expect(e.rating, Rating.dropped);
  });

  test('statuses are never downgraded by import', () async {
    await service.commit(profile, await stage(file));
    final older = backup([
      {'title': 'Synthetic One', 'media': 'anime', 'status': 'planned'},
    ]);
    await service.commit(profile, await stage(older));
    expect(
      (await library.entry(profile, 'anilist:1'))!.state,
      LibraryState.completed,
    );
  });

  test('undo import reverses only that batch and keeps later edits', () async {
    await library.saveEntry(profile, 'manual', state: LibraryState.seen);
    final r = await service.commit(profile, await stage(file));
    await library.saveEntry(profile, 'anilist:2', state: LibraryState.dropped);

    final undo = await service.undo(profile, r.batchId!);
    expect(undo.reverted, 1);
    expect(undo.kept, 1);
    expect(await library.entry(profile, 'anilist:1'), isNull);
    expect(
      (await library.entry(profile, 'anilist:2'))!.state,
      LibraryState.dropped,
    );
    expect(await library.entry(profile, 'manual'), isNotNull);

    // After undo the same file can be imported again.
    final again = await service.commit(profile, await stage(file));
    expect(again.alreadyImported, isFalse);
  });

  test(
    'unmatched titles wait in the review queue and can be resolved',
    () async {
      await service.commit(profile, await stage(file));
      final queue = await service.reviewQueue(profile);
      expect(queue.single.rawTitle, 'Close but no');
      await catalog.upsert([CatalogItemDto(item(9))]);
      await service.resolve(profile, queue.single, 'anilist:9');
      expect(await service.reviewQueue(profile), isEmpty);
      expect(
        (await library.entry(profile, 'anilist:9'))!.state,
        LibraryState.seen,
      );
    },
  );

  test('offline matching uses only the local cache', () async {
    gateway.offline = true;
    final s = await service.stage(
      profile,
      parseDetected(detect(file, 'b.json')),
      offlineOnly: true,
    );
    expect(s.needsReview, 3);
    expect(gateway.matchCalls, 0);
  });

  test('MAL ids resolve exactly through the batch MAL lookup', () async {
    gateway.malCatalog[101] = {...item(77), 'idMal': 101};
    const xml =
        '<myanimelist><anime><series_animedb_id>101</series_animedb_id>'
        '<series_title>Whatever</series_title><my_status>Completed</my_status></anime></myanimelist>';
    final bytes = Uint8List.fromList(utf8.encode(xml));
    final s = await service.stage(
      profile,
      parseDetected(detect(bytes, 'a.xml')),
    );
    expect(s.matched.single.matchClass, MatchClass.exactId);
    expect(s.matched.single.titleId, 'anilist:77');
  });
}
