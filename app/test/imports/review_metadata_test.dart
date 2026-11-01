import 'dart:io';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('review and undo never overwrite an existing manual rating', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final profile = (await ProfileRepository(db).create()).id;
    final catalog = CatalogRepository(db, FakeGateway());
    final title = (await catalog.upsert([CatalogItemDto(item(9))])).single;
    await db
        .into(db.userTitles)
        .insert(
          UserTitlesCompanion.insert(
            profileId: profile,
            titleId: title,
            updatedAt: DateTime.utc(2025),
            state: Value(LibraryState.completed.code),
            rating: Value(Rating.favourite.code),
          ),
        );
    final service = ImportService(db, catalog);
    final result = await service.commit(
      profile,
      await service.stage(
        profile,
        const ParsedImport(
          sourceType: 'generic_csv',
          adapterVersion: '1',
          records: [
            NormalizedRecord(
              sourceEntryKey: 'unmatched',
              title: 'Invented unknown alias',
              state: LibraryState.watching,
              rating: Rating.okay,
            ),
          ],
        ),
        offlineOnly: true,
      ),
    );
    await service.resolve(
      profile,
      (await service.reviewQueue(profile)).single,
      title,
    );
    expect(
      (await LibraryRepository(db).entry(profile, title))!.rating,
      Rating.favourite,
    );
    await service.undo(profile, result.batchId!);
    expect(
      (await LibraryRepository(db).entry(profile, title))!.rating,
      Rating.favourite,
    );
    expect(
      (await LibraryRepository(db).entry(profile, title))!.state,
      LibraryState.completed,
    );
  });

  test('review after disk reopen preserves original rating/progress and supports undo', () async {
    final dir = await Directory.systemTemp.createTemp('cue-review-metadata-');
    final file = File('${dir.path}${Platform.pathSeparator}review.sqlite');
    var db = CueDatabase(NativeDatabase(file));
    try {
      final profile = (await ProfileRepository(db).create()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      final service = ImportService(db, catalog);
      final result = await service.commit(
        profile,
        await service.stage(
          profile,
          ParsedImport(
            sourceType: 'generic_csv',
            adapterVersion: '1',
            records: [
              NormalizedRecord(
                sourceEntryKey: 'invented',
                title: 'Invented unresolved name',
                state: LibraryState.reading,
                rating: Rating.enjoyed,
                ratingOriginal: '8',
                ratingScale: '10',
                rewatchMood: RewatchMood.comfort,
                progressUnit: 'chapter',
                progressValue: 25,
                latestKnown: 30,
                actualWatchedAt: DateTime.utc(2020, 1, 2),
                note: 'Synthetic imported note.',
              ),
            ],
          ),
          offlineOnly: true,
        ),
      );
      expect((await service.reviewQueue(profile)).single.recordJson, isNotNull);
      await db.close();
      db = CueDatabase(NativeDatabase(file));
      final reopenedCatalog = CatalogRepository(db, FakeGateway());
      final reopened = ImportService(db, reopenedCatalog);
      final observation = (await reopened.reviewQueue(profile)).single;
      final title = (await reopenedCatalog.upsert([
        CatalogItemDto(item(7, kind: 'manhwa')),
      ])).single;
      await reopened.resolve(profile, observation, title);
      final entry = await LibraryRepository(db).entry(profile, title);
      expect(entry!.state, LibraryState.reading);
      expect(entry.rating, Rating.enjoyed);
      expect(entry.rewatchMood, RewatchMood.comfort);
      expect(entry.progressUnit, 'chapter');
      expect(entry.progressValue, 25);
      expect(entry.latestKnown, 30);
      expect(entry.actualWatchedAt?.toUtc(), DateTime.utc(2020, 1, 2));
      final row = await (db.select(
        db.userTitles,
      )..where((t) => t.titleId.equals(title))).getSingle();
      expect(row.note, 'Synthetic imported note.');
      final saved = await (db.select(
        db.sourceObservations,
      )..where((o) => o.id.equals(observation.id))).getSingle();
      expect(saved.recordJson, isNull);
      expect(saved.candidateJson, isNull);
      expect(saved.ratingOriginal, '8');
      expect(saved.ratingScale, '10');
      await reopened.undo(profile, result.batchId!);
      expect(await LibraryRepository(db).entry(profile, title), isNull);
    } finally {
      await db.close();
      await file.delete();
      await dir.delete();
    }
  });

  test('version 4 review rows migrate without loss and retain available original fields', () async {
    final dir = await Directory.systemTemp.createTemp('cue-review-v4-');
    final file = File('${dir.path}${Platform.pathSeparator}review.sqlite');
    var db = CueDatabase(NativeDatabase(file));
    try {
      final profile = (await ProfileRepository(db).create()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      final service = ImportService(db, catalog);
      await service.commit(
        profile,
        await service.stage(
          profile,
          const ParsedImport(
            sourceType: 'generic_csv',
            adapterVersion: '1',
            records: [
              NormalizedRecord(
                sourceEntryKey: 'legacy',
                title: 'Invented legacy row',
                state: LibraryState.completed,
                ratingOriginal: '7',
                ratingScale: '10',
              ),
            ],
          ),
          offlineOnly: true,
        ),
      );
      await db.customStatement(
        'ALTER TABLE source_observations DROP COLUMN record_json',
      );
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();
      db = CueDatabase(NativeDatabase(file));
      final reopenedCatalog = CatalogRepository(db, FakeGateway());
      final reopened = ImportService(db, reopenedCatalog);
      final observation = (await reopened.reviewQueue(profile)).single;
      expect(observation.recordJson, isNull);
      expect(observation.ratingOriginal, '7');
      final title = (await reopenedCatalog.upsert([CatalogItemDto(item(8))]))
          .single;
      await reopened.resolve(profile, observation, title);
      final row = await (db.select(
        db.userTitles,
      )..where((t) => t.titleId.equals(title))).getSingle();
      expect(row.state, LibraryState.completed.code);
      final saved = await (db.select(
        db.sourceObservations,
      )..where((o) => o.id.equals(observation.id))).getSingle();
      expect(saved.ratingOriginal, '7');
      expect(saved.ratingScale, '10');
    } finally {
      await db.close();
      await file.delete();
      await dir.delete();
    }
  });
}
