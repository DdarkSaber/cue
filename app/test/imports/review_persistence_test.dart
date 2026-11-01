import 'dart:io';
import 'dart:convert';

import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/imports/adapters/generic_csv.dart';
import 'package:cue/imports/import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/import_union.dart';

void main() {
  test('additional CSV merges; unresolved review survives disk reopen and stays scoped', () async {
    final temp = await Directory.systemTemp.createTemp('cue-review-');
    final file = File('${temp.path}${Platform.pathSeparator}cue.sqlite');
    var db = CueDatabase(NativeDatabase(file));
    try {
      final fixture = await seedImportUnion(db);
      final service = ImportService(db, CatalogRepository(db, fixture.gateway));
      final bytes = utf8.encode(
        'Title,Status\nInvented story 2,Completed\nInvented mystery,Watching\n',
      );
      final csv = GenericCsvAdapter();
      final result = await service.commit(
        fixture.profile,
        await service.stage(
          fixture.profile,
          csv.parse(bytes, csv.guessMapping(bytes)),
          rawBytes: bytes,
        ),
      );
      expect(result.review, 1);
      expect(
        (await LibraryRepository(db).signals(fixture.profile)).library,
        hasLength(7),
      );
      final other = (await ProfileRepository(db).create()).id;
      await ProfileRepository(db).activate(other);
      await db.close();
      db = CueDatabase(NativeDatabase(file));
      final reopened = ImportService(db, CatalogRepository(db, FakeGateway()));
      final queue = await reopened.reviewQueue(fixture.profile);
      expect(queue, hasLength(1));
      expect(queue.single.rawTitle, 'Invented mystery');
      expect(await reopened.reviewQueue(other), isEmpty);
      final catalog = CatalogRepository(db, FakeGateway());
      final ids = await catalog.upsert([CatalogItemDto(item(88))]);
      await expectLater(
        reopened.resolve(other, queue.single, ids.single),
        throwsStateError,
      );
      expect(await reopened.reviewQueue(fixture.profile), hasLength(1));
      await reopened.resolve(fixture.profile, queue.single, ids.single);
      expect(await reopened.reviewQueue(fixture.profile), isEmpty);
      expect(
        (await LibraryRepository(db).signals(fixture.profile)).library,
        hasLength(8),
      );
      expect((await LibraryRepository(db).signals(other)).library, isEmpty);
    } finally {
      await db.close();
      await file.delete();
      await temp.delete();
    }
  });
}
