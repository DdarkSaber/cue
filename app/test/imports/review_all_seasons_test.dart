import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'one review row can link every season; only the first keeps the rating',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final profile = (await ProfileRepository(db).create()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      final ids = await catalog.upsert([
        CatalogItemDto(item(11)),
        CatalogItemDto(item(12)),
        CatalogItemDto(item(13)),
      ]);
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
                sourceEntryKey: 'whole-show',
                title: 'Invented long show',
                state: LibraryState.completed,
                rating: Rating.favourite,
              ),
            ],
          ),
          offlineOnly: true,
        ),
      );
      await service.resolve(
        profile,
        (await service.reviewQueue(profile)).single,
        ids[0],
        alsoSeen: ids.skip(1),
      );
      final repo = LibraryRepository(db);
      final first = await repo.entry(profile, ids[0]);
      expect(first!.rating, Rating.favourite);
      for (final id in ids.skip(1)) {
        final e = await repo.entry(profile, id);
        expect(e!.state, LibraryState.completed);
        expect(e.rating, isNull);
      }
      expect(await service.reviewQueue(profile), isEmpty);
      // The same name in a later run (say, after a cancelled import) is
      // matched from memory, even offline.
      final again = await service.stage(
        profile,
        const ParsedImport(
          sourceType: 'generic_csv',
          adapterVersion: '1',
          records: [
            NormalizedRecord(
              sourceEntryKey: 'whole-show-again',
              title: 'Invented  Long show',
              state: LibraryState.completed,
            ),
          ],
        ),
        offlineOnly: true,
      );
      expect(again.matched.single.titleId, ids[0]);
      await service.undo(profile, result.batchId!);
      for (final id in ids) {
        expect(await repo.entry(profile, id), isNull);
      }
    },
  );
}
