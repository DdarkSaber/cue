import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cue/data/db/database.dart';

import '../support/fakes.dart';

void main() {
  test(
    'weak imported history contributes gradually; ratings replace weak status',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final id = (await ProfileRepository(db).ensureActive()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      await catalog.upsert([
        for (var i = 1; i <= 7; i++)
          CatalogItemDto(item(i, genres: ['Comedy'])),
      ]);
      final lib = LibraryRepository(db);
      final service = ImportService(db, catalog);
      final parsed = ParsedImport(
        sourceType: 'synthetic_csv',
        adapterVersion: '1',
        records: [
          for (var i = 1; i <= 6; i++)
            NormalizedRecord(
              sourceEntryKey: '$i',
              title: 'Invented $i',
              cueId: 'anilist:$i',
              state: [
                LibraryState.watching,
                LibraryState.reading,
                LibraryState.completed,
                LibraryState.planned,
                LibraryState.onHold,
                LibraryState.dropped,
              ][i - 1],
            ),
        ],
      );
      await service.commit(
        id,
        await service.stage(id, parsed, offlineOnly: true),
      );
      final signals = await lib.signals(id);
      // Watching and reading count a quarter more than completed: they are
      // what the person is into now (0.2 x 1.25 twice, plus 0.15).
      expect(signals.weights['comedy'], closeTo(0.65, 0.0001));
      expect(signals.evidenceTitles, 3);
      expect(signals.evidenceStrength, closeTo(0.65, 0.0001));
      expect(signals.tasteConfidence, closeTo(0.0325, 0.0001));
      final ranker = Ranker();
      const candidate = Title(
        id: 'fresh',
        kind: MediaKind.anime,
        genres: ['Comedy'],
      );
      final neutral = ranker.score(
        candidate,
        const ProfileSignals(),
        const DeckFilters(),
      );
      expect(
        ranker.score(candidate, signals, const DeckFilters()),
        greaterThan(neutral),
      );
      await service.commit(
        id,
        await service.stage(id, parsed, offlineOnly: true),
      );
      expect((await lib.signals(id)).weights['comedy'], closeTo(0.65, 0.0001));
      await lib.saveEntry(
        id,
        'anilist:1',
        state: LibraryState.watching,
        rating: Rating.disliked,
      );
      await lib.recomputeWeights(id);
      final negative = await lib.signals(id);
      expect(negative.weights['comedy'], closeTo(-0.6, 0.0001));
      expect(negative.weakHistoryIds, isNot(contains('anilist:1')));
      await lib.saveEntry(
        id,
        'anilist:1',
        state: LibraryState.watching,
        rating: Rating.favourite,
      );
      await lib.recomputeWeights(id);
      final positive = await lib.signals(id);
      expect(positive.weights['comedy'], closeTo(3.4, 0.0001));
      expect(positive.tasteConfidence, greaterThan(signals.tasteConfidence));
    },
  );

  test('explicit ratings override prior shortlist interest instead of cancelling dislikes', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final id = (await ProfileRepository(db).ensureActive()).id;
    final catalog = CatalogRepository(db, FakeGateway());
    await catalog.upsert([
      CatalogItemDto(item(1, genres: ['Comedy'])),
    ]);
    await db
        .into(db.shortlist)
        .insert(
          ShortlistCompanion.insert(
            profileId: id,
            titleId: 'anilist:1',
            addedAt: DateTime.now(),
          ),
        );
    final lib = LibraryRepository(db);
    await lib.saveEntry(
      id,
      'anilist:1',
      state: LibraryState.seen,
      rating: Rating.disliked,
    );
    await lib.recomputeWeights(id);
    expect((await lib.signals(id)).weights['comedy'], -1);
    await lib.saveEntry(
      id,
      'anilist:1',
      state: LibraryState.seen,
      rating: Rating.favourite,
    );
    await lib.recomputeWeights(id);
    expect((await lib.signals(id)).weights['comedy'], 3);
  });
  test(
    'unknown metadata is neutral and legacy weight cache refreshes',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final id = (await ProfileRepository(db).ensureActive()).id;
      final lib = LibraryRepository(db);
      await lib.saveEntry(
        id,
        'missing:1',
        state: LibraryState.completed,
        rating: Rating.favourite,
      );
      final signals = await lib.signals(id);
      expect(signals.weights, isEmpty);
      expect(signals.evidenceStrength, 0);
      expect(signals.tasteConfidence, 0);
    },
  );
}
