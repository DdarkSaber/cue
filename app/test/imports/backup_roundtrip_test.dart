import 'dart:convert';
import 'dart:typed_data';

import 'package:cue/data/backup_service.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/settings.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/import_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'export, delete, import on a fresh device restores everything',
    () async {
      final now = DateTime(2026, 10, 31);
      final db = memoryDb();
      addTearDown(db.close);
      final profiles = ProfileRepository(db, clock: () => now);
      final catalog = CatalogRepository(db, FakeGateway(), clock: () => now);
      final library = LibraryRepository(db, clock: () => now);
      final decisions = DecisionService(db, clock: () => now);
      final id = (await profiles.ensureActive()).id;

      await catalog.upsert([
        for (var i = 1; i <= 5; i++)
          CatalogItemDto({...item(i), 'idMal': 100 + i}),
      ]);
      Future<dynamic> t(int i) async =>
          (await catalog.titleById('anilist:$i'))!;
      await library.saveEntry(
        id,
        'anilist:1',
        state: LibraryState.completed,
        rating: Rating.rewatched,
        rewatchMood: RewatchMood.comfort,
        actualWatchedAt: DateTime.utc(2019, 4, 1),
      );
      await decisions.decide(id, await t(2), Decision.willTry);
      await decisions.decide(id, await t(3), Decision.notInterested);
      await decisions.decide(id, await t(4), Decision.notNow);
      await profiles.saveSettings(
        id,
        const AppSettings().copyWith(
          swipeMap: SwipeMap.standard.mirrored,
          reduceMotion: true,
        ),
      );

      final json = await BackupService(db, clock: () => now).export(id);
      expect(json, isNot(contains('token')));

      // Delete the library, then restore on a device whose catalog is empty
      // and offline: the backup carries what it needs.
      await profiles.deleteProfile(id);
      final db2 = memoryDb();
      addTearDown(db2.close);
      final profiles2 = ProfileRepository(db2, clock: () => now);
      final id2 = (await profiles2.ensureActive()).id;
      final catalog2 = CatalogRepository(
        db2,
        FakeGateway(offline: true),
        clock: () => now,
      );
      final service = ImportService(db2, catalog2, clock: () => now);
      final bytes = Uint8List.fromList(utf8.encode(json));
      final staged = await service.stage(
        id2,
        parseDetected(detect(bytes, 'cue-backup.json')),
        rawBytes: bytes,
        offlineOnly: true,
      );
      expect(staged.needsReview, 0);
      await service.commit(id2, staged);

      final lib2 = LibraryRepository(db2, clock: () => now);
      final e = await lib2.entry(id2, 'anilist:1');
      expect(e!.state, LibraryState.completed);
      expect(e.rating, Rating.rewatched);
      expect(e.rewatchMood, RewatchMood.comfort);
      expect(
        e.actualWatchedAt!.isAtSameMomentAs(DateTime.utc(2019, 4, 1)),
        isTrue,
      );
      final s = await lib2.signals(id2);
      expect(s.shortlisted, {'anilist:2'});
      expect(s.excluded, {'anilist:3'});
      expect(s.deferred, {'anilist:4'});
      final settings = await profiles2.loadSettings(id2);
      expect(settings.swipeMap, SwipeMap.standard.mirrored);
      expect(settings.reduceMotion, isTrue);
      // Identities came along, so a later MAL import matches exactly.
      expect(await catalog2.findByIdentity('mal', '101', 'anime'), 'anilist:1');
    },
  );
}
