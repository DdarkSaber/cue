import 'dart:convert';
import 'dart:typed_data';

import 'package:cue/app/router.dart';
import 'package:cue/data/backup_service.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

/// The Worker's /sync routes in memory, with the same version rules.
class _Remote implements SyncRemote {
  final blobs = <String, ({String token, int version, String data})>{};

  @override
  Future<({int version, String data})?> get(String id, String token) async {
    final b = blobs[id];
    if (b == null) return null;
    if (b.token != token) throw const SyncFailed('http_403');
    return (version: b.version, data: b.data);
  }

  @override
  Future<int> put(String id, String token, int expected, String data) async {
    final b = blobs[id];
    if ((b?.version ?? 0) != expected) throw SyncConflict(b!.version);
    blobs[id] = (token: token, version: expected + 1, data: data);
    return expected + 1;
  }

  @override
  Future<void> delete(String id, String token) async => blobs.remove(id);
}

/// One device: its own database and services, sharing the fake catalog.
class _Device {
  _Device(this.remote, this.gateway);
  final SyncRemote remote;
  final FakeGateway gateway;
  late final CueDatabase db = memoryDb();
  late final profiles = ProfileRepository(db);
  late final catalog = CatalogRepository(db, gateway);
  late final library = LibraryRepository(db);
  late final decisions = DecisionService(db);
  late final imports = ImportService(db, catalog);
  late final sync = SyncService(
    remote: remote,
    codes: MemoryCodeStore(),
    backup: BackupService(db),
    imports: imports,
    profiles: profiles,
    library: library,
    db: db,
  );
  late String id;

  Future<void> init() async => id = (await profiles.ensureActive()).id;
}

Uint8List _file(List<Map<String, Object?>> items) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({'cue': 'backup', 'schema_version': 1, 'items': items}),
  ),
);

void main() {
  test(
    'import a file, decide in the deck, then a second device gets it all',
    () async {
      final gateway = FakeGateway();
      gateway.matchCatalog['synthetic one'] = [
        {...item(1), 'titleEn': 'Synthetic One'},
      ];
      gateway.matchCatalog['synthetic two'] = [
        {...item(2, kind: 'manhwa'), 'titleEn': 'Synthetic Two'},
      ];
      final remote = _Remote();
      final phone = _Device(remote, gateway);
      final laptop = _Device(remote, gateway);
      await phone.init();
      await laptop.init();

      // 1. Import a list on the phone.
      final bytes = _file([
        {'title': 'Synthetic One', 'media': 'anime', 'status': 'completed'},
        {'title': 'Synthetic Two', 'media': 'manhwa', 'status': 'reading'},
      ]);
      final summary = await phone.imports.commit(
        phone.id,
        await phone.imports.stage(
          phone.id,
          parseDetected(detect(bytes, 'list.json')),
          rawBytes: bytes,
        ),
      );
      expect(summary.added, 2);

      // 2. Decide on a card: Will try on a title from the catalog.
      await phone.catalog.upsert([CatalogItemDto(item(3))]);
      await phone.decisions.decide(
        phone.id,
        (await phone.catalog.titleById('anilist:3'))!,
        Decision.willTry,
      );

      // 3. Turn on sync and join from the laptop.
      final code = await phone.sync.enable(phone.id);
      await laptop.sync.join(laptop.id, code);

      expect(await laptop.library.entry(laptop.id, 'anilist:1'), isNotNull);
      expect(await laptop.library.entry(laptop.id, 'anilist:2'), isNotNull);
      expect((await laptop.library.signals(laptop.id)).shortlisted, {
        'anilist:3',
      });

      // 4. A removal on the laptop reaches the phone.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await laptop.library.removeFromShortlist(laptop.id, 'anilist:3');
      await laptop.sync.syncNow(laptop.id);
      await phone.sync.syncNow(phone.id);
      expect((await phone.library.signals(phone.id)).shortlisted, isEmpty);
    },
  );

  testWidgets('the synced library shows on the second device', (t) async {
    final gateway = sampleGateway();
    final remote = _Remote();
    final phone = _Device(remote, gateway);
    await t.runAsync(() async {
      await phone.init();
      await phone.catalog.upsert([CatalogItemDto(item(1))]);
      await phone.decisions.decide(
        phone.id,
        (await phone.catalog.titleById('anilist:1'))!,
        Decision.watched,
      );
    });
    // The second device opens the app on the same database the sync wrote.
    await pumpCue(t, db: phone.db, location: CueRoutes.library);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpAndSettle();
    expect(find.textContaining('Synthetic 1'), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
