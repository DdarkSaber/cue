import 'dart:io';

import 'package:cue/data/card_signal_repository.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('upgrading from schema 7 adds card_signals and keeps data', () async {
    final dir = await Directory.systemTemp.createTemp('cue-schema8-');
    final file = File('${dir.path}${Platform.pathSeparator}cue.sqlite');
    var db = CueDatabase(NativeDatabase(file));
    try {
      await CatalogRepository(
        db,
        FakeGateway(),
      ).upsert([CatalogItemDto(item(1)), CatalogItemDto(item(2))]);
      final profileId = (await ProfileRepository(db).ensureActive()).id;
      await db.customStatement('DROP INDEX idx_card_signals_profile_time');
      await db.customStatement('DROP TABLE card_signals');
      await db.customStatement('PRAGMA user_version = 7');
      await db.close();

      db = CueDatabase(NativeDatabase(file));
      expect(await db.select(db.catalogTitles).get(), hasLength(2));
      expect((await db.select(db.profiles).get()).single.id, profileId);
      final repo = CardSignalRepository(db);
      await repo.record(
        CardSignal(
          profileId: profileId,
          titleId: 't1',
          shownAt: DateTime.utc(2026, 1, 1),
          dwellMs: 1200,
        ),
      );
      final row = (await db.select(db.cardSignals).get()).single;
      // Column defaults come from the table definition.
      expect(row.openedDetails, isFalse);
      expect(row.heldPoster, isFalse);
      expect(row.slot, '');
      expect(row.decision, isNull);
      final indexes = await db
          .customSelect("PRAGMA index_list('card_signals')")
          .get();
      expect(
        indexes.map((i) => i.read<String>('name')),
        contains('idx_card_signals_profile_time'),
      );
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 8);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
