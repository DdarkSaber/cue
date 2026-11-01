import 'dart:convert';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/imports/adapters/generic_csv.dart';
import 'package:cue/imports/import_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/fakes.dart';
import '../test/support/import_union.dart';
import '../test/support/test_database_web.dart';

void main() {
  testWidgets(
    'synthetic browser SQLite reopens merged imports and scoped review, then cleans up',
    (tester) async {
      await tester.runAsync(() async {
        final name = syntheticDatabaseName();
        var db = openTestDatabase(name: name);
        try {
          final fixture = await seedImportUnion(db);
          final service = ImportService(
            db,
            CatalogRepository(db, fixture.gateway),
          );
          final bytes = utf8.encode(
            'Title,Status\nInvented story 2,Completed\nInvented mystery,Watching\n',
          );
          final csv = GenericCsvAdapter();
          final imported = await service.commit(
            fixture.profile,
            await service.stage(
              fixture.profile,
              csv.parse(bytes, csv.guessMapping(bytes)),
              rawBytes: bytes,
            ),
          );
          expect(imported.review, 1);
          final before = await LibraryRepository(db).signals(fixture.profile);
          expect(before.library, hasLength(7));
          final profiles = ProfileRepository(db);
          final other = (await profiles.create(
            displayName: 'Synthetic reopen neighbour',
          )).id;
          await profiles.activate(other);
          await db.close();

          db = openTestDatabase(name: name);
          final reopened = ImportService(
            db,
            CatalogRepository(db, fixture.gateway),
          );
          expect((await ProfileRepository(db).ensureActive()).id, other);
          final persisted = await LibraryRepository(db)
              .signals(fixture.profile);
          expect(persisted.library.keys.toSet(), before.library.keys.toSet());
          expect(await reopened.batches(fixture.profile), hasLength(3));
          final queue = await reopened.reviewQueue(fixture.profile);
          expect(queue, hasLength(1));
          expect(queue.single.rawTitle, 'Invented mystery');
          expect(await reopened.reviewQueue(other), isEmpty);
          final duplicate = await reopened.commit(
            fixture.profile,
            await reopened.stage(
              fixture.profile,
              csv.parse(bytes, csv.guessMapping(bytes)),
              rawBytes: bytes,
            ),
          );
          expect(duplicate.alreadyImported, isTrue);
          expect(await reopened.reviewQueue(fixture.profile), hasLength(1));
          final catalog = CatalogRepository(db, FakeGateway());
          final ids = await catalog.upsert([CatalogItemDto(item(88))]);
          await expectLater(
            reopened.resolve(other, queue.single, ids.single),
            throwsStateError,
          );
          await reopened.resolve(fixture.profile, queue.single, ids.single);
          expect(await reopened.reviewQueue(fixture.profile), isEmpty);
          expect(
            (await LibraryRepository(db).signals(fixture.profile)).library,
            hasLength(8),
          );
          expect((await LibraryRepository(db).signals(other)).library, isEmpty);
          await db.close();

          db = openTestDatabase(name: name);
          expect(
            (await LibraryRepository(db).signals(fixture.profile)).library.keys,
            contains('anilist:88'),
          );
          expect(
            await ImportService(
              db,
              CatalogRepository(db, FakeGateway()),
            ).reviewQueue(fixture.profile),
            isEmpty,
          );
        } finally {
          await db.close();
          await deleteSyntheticDatabase(name);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
