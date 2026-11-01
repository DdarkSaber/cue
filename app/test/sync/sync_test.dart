import 'package:drift/drift.dart' show Value;

import 'dart:convert';

import 'package:cue/data/backup_service.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:cue/sync/sync_crypto.dart';
import 'package:cue/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// The Worker's /sync routes in memory, with the same version rules.
class FakeRemote implements SyncRemote {
  final blobs = <String, ({String token, int version, String data})>{};
  int puts = 0;

  @override
  Future<({int version, String data})?> get(String id, String token) async {
    final b = blobs[id];
    if (b == null) return null;
    if (b.token != token) throw const SyncFailed('http_403');
    return (version: b.version, data: b.data);
  }

  @override
  Future<int> put(String id, String token, int expected, String data) async {
    puts++;
    final b = blobs[id];
    if ((b?.version ?? 0) != expected) throw SyncConflict(b!.version);
    if (b != null && b.token != token) throw const SyncFailed('http_403');
    blobs[id] = (token: token, version: expected + 1, data: data);
    return expected + 1;
  }

  @override
  Future<void> delete(String id, String token) async => blobs.remove(id);
}

class Device {
  Device(this.remote);
  final SyncRemote remote;
  late final CueDatabase db = memoryDb();
  late final profiles = ProfileRepository(db);
  late final catalog = CatalogRepository(db, FakeGateway(offline: true));
  late final library = LibraryRepository(db);
  late final decisions = DecisionService(db);
  late final codes = MemoryCodeStore();
  late final sync = SyncService(
    remote: remote,
    codes: codes,
    backup: BackupService(db),
    imports: ImportService(db, catalog),
    profiles: profiles,
    library: library,
    db: db,
  );
  late String id;

  Future<void> init() async {
    id = (await profiles.ensureActive()).id;
    await catalog.upsert([
      for (var i = 1; i <= 4; i++) CatalogItemDto(item(i)),
    ]);
  }
}

void main() {
  group('crypto', () {
    test('codes are 32 base32 characters and normalise look-alikes', () {
      final code = newSyncCode();
      expect(
        code,
        matches(RegExp(r'^([0-9A-HJKMNP-TV-Z]{4}-){7}[0-9A-HJKMNP-TV-Z]{4}$')),
      );
      expect(normalizeSyncCode(code.toLowerCase()), code.replaceAll('-', ''));
      expect(normalizeSyncCode('O' * 32), '0' * 32);
      expect(normalizeSyncCode('too short'), isNull);
      expect(normalizeSyncCode('U' * 32), isNull);
    });

    test('derived id, token and key are separate and stable', () async {
      final c = normalizeSyncCode(newSyncCode())!;
      final a = await deriveSyncKeys(c);
      final b = await deriveSyncKeys(c);
      expect(a.id, b.id);
      expect(a.id, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(a.token, isNot(contains(a.id)));
      expect(await a.key.extractBytes(), await b.key.extractBytes());
    });

    test('seal and open round-trip; a wrong code or tampering fails', () async {
      final k = await deriveSyncKeys(normalizeSyncCode(newSyncCode())!);
      final other = await deriveSyncKeys(normalizeSyncCode(newSyncCode())!);
      final blob = await sealBlob('{"cue":"backup"}', k.key);
      expect(blob, isNot(contains('backup')));
      expect(await openBlob(blob, k.key), '{"cue":"backup"}');
      await expectLater(
        openBlob(blob, other.key),
        throwsA(isA<SyncDecryptFailed>()),
      );
      final bytes = base64.decode(blob)..[20] ^= 1;
      await expectLater(
        openBlob(base64.encode(bytes), k.key),
        throwsA(isA<SyncDecryptFailed>()),
      );
    });

    test('a fresh nonce every time', () async {
      final k = await deriveSyncKeys(normalizeSyncCode(newSyncCode())!);
      expect(
        await sealBlob('same', k.key),
        isNot(await sealBlob('same', k.key)),
      );
    });
  });

  group('two devices', () {
    late FakeRemote remote;
    late Device phone;
    late Device laptop;

    setUp(() async {
      remote = FakeRemote();
      phone = Device(remote);
      laptop = Device(remote);
      await phone.init();
      await laptop.init();
    });

    tearDown(() async {
      await phone.db.close();
      await laptop.db.close();
    });

    test('the last edit wins, in both directions', () async {
      final code = await phone.sync.enable(phone.id);
      await laptop.sync.join(laptop.id, code);
      // Both know the title; the laptop rated it first.
      await laptop.library.saveEntry(
        laptop.id,
        'anilist:1',
        state: LibraryState.completed,
        rating: Rating.okay,
      );
      await laptop.sync.syncNow(laptop.id);
      await phone.sync.syncNow(phone.id);
      // Later the phone changes its mind: dropped, no rating.
      // Stored times have one-second precision.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await phone.library.saveEntry(
        phone.id,
        'anilist:1',
        state: LibraryState.dropped,
      );
      await phone.sync.syncNow(phone.id);
      await laptop.sync.syncNow(laptop.id);
      final onLaptop = (await laptop.library.entry(laptop.id, 'anilist:1'))!;
      expect(onLaptop.state, LibraryState.dropped);
      expect(onLaptop.rating, isNull);
      // And the phone keeps its newer edit when it pulls again.
      await phone.sync.syncNow(phone.id);
      expect(
        (await phone.library.entry(phone.id, 'anilist:1'))!.state,
        LibraryState.dropped,
      );
    });

    test(
      'title removals travel and an explicit same-second re-add wins',
      () async {
        await phone.library.saveEntry(
          phone.id,
          'anilist:1',
          state: LibraryState.completed,
          rating: Rating.favourite,
        );
        final at =
            (await phone.db.select(phone.db.userTitles).getSingle()).updatedAt;
        final code = await phone.sync.enable(phone.id);
        await laptop.sync.join(laptop.id, code);
        await LibraryRepository(
          phone.db,
          clock: () => at,
        ).removeEntry(phone.id, 'anilist:1');
        await phone.sync.syncNow(phone.id);
        await laptop.sync.syncNow(laptop.id);
        expect(await laptop.library.entry(laptop.id, 'anilist:1'), isNull);
        expect(await phone.library.entry(phone.id, 'anilist:1'), isNull);

        await LibraryRepository(laptop.db, clock: () => at).saveEntry(
          laptop.id,
          'anilist:1',
          state: LibraryState.reading,
          rating: Rating.okay,
        );
        await laptop.sync.syncNow(laptop.id);
        await phone.sync.syncNow(phone.id);
        expect(
          (await phone.library.entry(phone.id, 'anilist:1'))!.state,
          LibraryState.reading,
        );
        expect(
          (await laptop.library.entry(laptop.id, 'anilist:1'))!.rating,
          Rating.okay,
        );
        final exported =
            jsonDecode(await BackupService(phone.db).export(phone.id)) as Map;
        expect(
          (exported['settings'] as Map).keys.where(
            (k) => '$k'.startsWith(LibraryRepository.removalPrefix),
          ),
          isEmpty,
        );
      },
    );

    test(
      'undo-import removals sync, preserve edits and allow explicit reimport',
      () async {
        final imports = ImportService(phone.db, phone.catalog);
        final parsed = ParsedImport(
          sourceType: 'mal',
          adapterVersion: 'synthetic',
          records: [
            for (var i = 1; i <= 2; i++)
              NormalizedRecord(
                sourceEntryKey: '$i',
                title: 'Synthetic $i',
                cueId: 'anilist:$i',
                state: LibraryState.completed,
              ),
          ],
        );
        final first = await imports.commit(
          phone.id,
          await imports.stage(phone.id, parsed, offlineOnly: true),
        );
        final code = await phone.sync.enable(phone.id);
        await laptop.sync.join(laptop.id, code);
        await phone.library.saveEntry(
          phone.id,
          'anilist:2',
          state: LibraryState.dropped,
          rating: Rating.dropped,
        );
        final undo = await imports.undo(phone.id, first.batchId!);
        expect(undo.reverted, 1);
        expect(undo.kept, 1);
        await phone.sync.syncNow(phone.id);
        await laptop.sync.syncNow(laptop.id);
        expect(await laptop.library.entry(laptop.id, 'anilist:1'), isNull);
        expect(
          (await laptop.library.entry(laptop.id, 'anilist:2'))!.state,
          LibraryState.dropped,
        );
        await imports.commit(
          phone.id,
          await imports.stage(phone.id, parsed, offlineOnly: true),
        );
        await phone.sync.syncNow(phone.id);
        await laptop.sync.syncNow(laptop.id);
        expect(await laptop.library.entry(laptop.id, 'anilist:1'), isNotNull);
        expect(
          (await laptop.library.entry(laptop.id, 'anilist:2'))!.rating,
          Rating.dropped,
        );
      },
    );

    test(
      'reset swipes propagates history removal but keeps imports and ratings',
      () async {
        await phone.decisions.decide(
          phone.id,
          (await phone.catalog.titleById('anilist:1'))!,
          Decision.watched,
        );
        await phone.library.saveEntry(
          phone.id,
          'anilist:2',
          state: LibraryState.completed,
          rating: Rating.rewatched,
        );
        final imports = ImportService(phone.db, phone.catalog);
        const parsed = ParsedImport(
          sourceType: 'mal',
          adapterVersion: 'synthetic',
          records: [
            NormalizedRecord(
              sourceEntryKey: '3',
              title: 'Synthetic 3',
              cueId: 'anilist:3',
              state: LibraryState.completed,
            ),
          ],
        );
        await imports.commit(
          phone.id,
          await imports.stage(phone.id, parsed, offlineOnly: true),
        );
        final code = await phone.sync.enable(phone.id);
        await laptop.sync.join(laptop.id, code);
        await phone.library.resetSwipes(phone.id);
        await phone.sync.syncNow(phone.id);
        await laptop.sync.syncNow(laptop.id);
        expect(await laptop.library.entry(laptop.id, 'anilist:1'), isNull);
        expect(
          (await laptop.library.entry(laptop.id, 'anilist:2'))!.rating,
          Rating.rewatched,
        );
        expect(await laptop.library.entry(laptop.id, 'anilist:3'), isNotNull);
      },
    );

    test('removals, library settings and mood learning travel', () async {
      await phone.decisions.decide(
        phone.id,
        (await phone.catalog.titleById('anilist:2'))!,
        Decision.willTry,
      );
      final code = await phone.sync.enable(phone.id);
      await laptop.sync.join(laptop.id, code);
      expect((await laptop.library.signals(laptop.id)).shortlisted, {
        'anilist:2',
      });

      // The phone removes it from Will try, turns rewatches on, and learns.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await phone.library.removeFromShortlist(phone.id, 'anilist:2');
      await phone.profiles.setRawSetting(phone.id, 'includeRewatches', 'true');
      await phone.db
          .into(phone.db.moodStates)
          .insertOnConflictUpdate(
            MoodStatesCompanion.insert(
              profileId: phone.id,
              modesJson: const Value('[{"id":"m1","label":"Isekai"}]'),
              updatedAt: DateTime.now(),
            ),
          );
      await phone.sync.syncNow(phone.id);
      final r = await laptop.sync.syncNow(laptop.id);

      expect((await laptop.library.signals(laptop.id)).shortlisted, isEmpty);
      expect(
        await laptop.profiles.rawSetting(laptop.id, 'includeRewatches'),
        'true',
      );
      expect(r.moodChanged, isTrue);
      final mood = await laptop.db.select(laptop.db.moodStates).getSingle();
      expect(mood.modesJson, contains('Isekai'));

      // And the removal does not come back from the phone's next pull.
      await phone.sync.syncNow(phone.id);
      expect((await phone.library.signals(phone.id)).shortlisted, isEmpty);
    });

    test('edits in the same second still end up the same', () async {
      final code = await phone.sync.enable(phone.id);
      await laptop.sync.join(laptop.id, code);
      await phone.library.saveEntry(
        phone.id,
        'anilist:1',
        state: LibraryState.completed,
        rating: Rating.favourite,
      );
      await laptop.library.saveEntry(
        laptop.id,
        'anilist:1',
        state: LibraryState.completed,
        rating: Rating.okay,
      );
      await phone.sync.syncNow(phone.id);
      await laptop.sync.syncNow(laptop.id);
      await phone.sync.syncNow(phone.id);
      final a = (await phone.library.entry(phone.id, 'anilist:1'))!.rating;
      final b = (await laptop.library.entry(laptop.id, 'anilist:1'))!.rating;
      expect(a, b);
    });

    test('the Worker only ever sees ciphertext', () async {
      await phone.library.saveEntry(
        phone.id,
        'anilist:1',
        state: LibraryState.completed,
        rating: Rating.favourite,
      );
      await phone.sync.enable(phone.id);
      final stored = remote.blobs.values.single.data;
      expect(stored, isNot(contains('anilist')));
      expect(stored, isNot(contains('favourite')));
    });

    test('join merges both libraries and both end up the same', () async {
      await phone.library.saveEntry(
        phone.id,
        'anilist:1',
        state: LibraryState.completed,
        rating: Rating.rewatched,
      );
      await phone.decisions.decide(
        phone.id,
        (await phone.catalog.titleById('anilist:2'))!,
        Decision.willTry,
      );
      final code = await phone.sync.enable(phone.id);

      await laptop.decisions.decide(
        laptop.id,
        (await laptop.catalog.titleById('anilist:3'))!,
        Decision.notInterested,
      );
      final joined = await laptop.sync.join(laptop.id, code);
      expect(joined.pulled, greaterThan(0));
      expect(
        (await laptop.library.entry(laptop.id, 'anilist:1'))!.rating,
        Rating.rewatched,
      );
      expect((await laptop.library.signals(laptop.id)).shortlisted, {
        'anilist:2',
      });

      await phone.sync.syncNow(phone.id);
      expect((await phone.library.signals(phone.id)).excluded, {'anilist:3'});
    });

    test('a write in between is a conflict that is merged, not lost', () async {
      final code = await phone.sync.enable(phone.id);
      await laptop.sync.join(laptop.id, code);
      // Laptop writes; phone has not pulled since.
      await laptop.library.saveEntry(
        laptop.id,
        'anilist:4',
        state: LibraryState.seen,
      );
      await laptop.sync.syncNow(laptop.id);
      await phone.library.saveEntry(
        phone.id,
        'anilist:2',
        state: LibraryState.watching,
      );
      await phone.sync.syncNow(phone.id);
      expect(await phone.library.entry(phone.id, 'anilist:4'), isNotNull);
      await laptop.sync.syncNow(laptop.id);
      expect(await laptop.library.entry(laptop.id, 'anilist:2'), isNotNull);
    });

    test('a wrong code is refused before anything is saved', () async {
      await phone.sync.enable(phone.id);
      await expectLater(
        laptop.sync.join(laptop.id, newSyncCode()),
        throwsA(isA<SyncFailed>()),
      );
      expect(await laptop.sync.code(laptop.id), isNull);
    });

    test('syncing twice with no changes changes nothing', () async {
      await phone.library.saveEntry(
        phone.id,
        'anilist:1',
        state: LibraryState.completed,
      );
      await phone.sync.enable(phone.id);
      final r = await phone.sync.syncNow(phone.id);
      expect(r.pulled, 0);
      expect((await phone.db.select(phone.db.userTitles).get()).length, 1);
    });

    test('turning off forgets the code; deleting removes the copy', () async {
      await phone.sync.enable(phone.id);
      await phone.sync.deleteRemote(phone.id);
      expect(remote.blobs, isEmpty);
      expect(await phone.sync.code(phone.id), isNull);
    });
  });
}
