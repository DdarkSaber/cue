import 'dart:convert';
import 'dart:typed_data';

import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/import_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Uint8List _backup(List<Map<String, Object?>> items) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({'cue': 'backup', 'schema_version': 1, 'items': items}),
  ),
);

Map<String, dynamic> _named(int id, String name, {String kind = 'anime'}) =>
    item(id, kind: kind).map((k, v) => MapEntry(k, k == 'titleEn' ? name : v));

void main() {
  late CueDatabase db;
  late FakeGateway gateway;
  late ImportService service;
  late LibraryRepository library;
  late String profile;

  setUp(() async {
    db = memoryDb();
    gateway = FakeGateway();
    service = ImportService(db, CatalogRepository(db, gateway));
    library = LibraryRepository(db);
    profile = (await ProfileRepository(db).ensureActive()).id;
    // Nothing is known at import time: every row lands in the review queue.
    final bytes = _backup([
      {'title': 'Lantern Road', 'media': 'anime', 'status': 'completed'},
      {'title': 'The Quiet Harbour', 'media': 'anime', 'status': 'seen'},
      {'title': 'Nowhere To Be Found', 'media': 'anime', 'status': 'seen'},
    ]);
    await service.commit(
      profile,
      await service.stage(
        profile,
        parseDetected(detect(bytes, 'b.json')),
        rawBytes: bytes,
      ),
    );
    expect(await service.reviewQueue(profile), hasLength(3));
  });

  tearDown(() => db.close());

  test('links exact titles, stores close ones, leaves the rest', () async {
    gateway.searchResults['lantern road'] = [_named(11, 'Lantern Road')];
    gateway.searchResults['the quiet harbour'] = [_named(12, 'Quiet Harbour')];
    final progress = <(int, int)>[];
    final s = await service.recheckReview(
      profile,
      onProgress: (d, t) => progress.add((d, t)),
    );
    expect(s.matched, 1);
    expect(s.suggested, 1);
    expect(s.remaining, 2);
    expect(progress.last, (3, 3));
    expect(await library.entry(profile, 'anilist:11'), isNotNull);
    final queue = await service.reviewQueue(profile);
    expect(
      queue.singleWhere((o) => o.candidateJson != null).rawTitle,
      'The Quiet Harbour',
    );
    // A suggestion is never linked without a yes.
    expect(await library.entry(profile, 'anilist:12'), isNull);
  });

  test('a failed lookup counts as not checked, not as no match', () async {
    gateway.offline = true;
    final s = await service.recheckReview(profile);
    expect(s.matched, 0);
    expect(s.unchecked, 3);
    expect(s.remaining, 3);
  });

  test('stopping keeps what was already found', () async {
    gateway.searchResults['lantern road'] = [_named(11, 'Lantern Road')];
    var calls = 0;
    final s = await service.recheckReview(
      profile,
      cancelled: () => ++calls > 2,
    );
    expect(s.checked, lessThan(3));
    expect(s.remaining, greaterThanOrEqualTo(2));
  });

  test('a rejected suggestion stays queued without its candidate', () async {
    gateway.searchResults['the quiet harbour'] = [_named(12, 'Quiet Harbour')];
    await service.recheckReview(profile);
    final o = (await service.reviewQueue(profile))
        .singleWhere((o) => o.candidateJson != null);
    await service.rejectSuggestion(o);
    final queue = await service.reviewQueue(profile);
    expect(queue, hasLength(3));
    expect(queue.every((o) => o.candidateJson == null), isTrue);
  });
}
