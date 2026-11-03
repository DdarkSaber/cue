import 'dart:io';

import 'package:cue/data/db/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/data/recommendation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'version 3 upgrade preserves profiles and adds device-only measures',
    () async {
      final dir = await Directory.systemTemp.createTemp('cue_v3_upgrade_');
      final file = File('${dir.path}${Platform.pathSeparator}cue.sqlite');
      var db = CueDatabase(NativeDatabase(file));
      final profile = await ProfileRepository(db).ensureActive();
      await db.customStatement('DROP TABLE recommendation_states');
      await db.customStatement(
        'ALTER TABLE source_observations DROP COLUMN record_json',
      );
      await db.customStatement('PRAGMA user_version = 3');
      await db.close();
      db = CueDatabase(NativeDatabase(file));
      try {
        expect((await ProfileRepository(db).ensureActive()).id, profile.id);
        expect(await RecommendationRepository(db).read(profile.id), isEmpty);
        await RecommendationRepository(db)
            .decision(profile.id, picked: true, eventId: 'synthetic-upgrade');
        expect(
          (await RecommendationRepository(db).read(profile.id))['picks'],
          1,
        );
        await db.close();
        db = CueDatabase(NativeDatabase(file));
        expect(
          (await RecommendationRepository(db).read(profile.id))['picks'],
          1,
        );
      } finally {
        await db.close();
        await file.delete();
        await dir.delete();
      }
    },
  );
  test('a version 1 database gains the mood tables and candidate column on upgrade', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('cue_mig');
    final file = File('${dir.path}/cue.sqlite');
    // Build today's schema, then turn it back into version 1.
    final v2 = CueDatabase(NativeDatabase(file));
    await v2.customSelect('SELECT 1').get();
    await v2.customStatement('DROP TABLE mood_states');
    await v2.customStatement('DROP TABLE mood_sessions');
    await v2.customStatement('DROP TABLE catalog_recommendations');
    await v2.customStatement(
      'ALTER TABLE source_observations DROP COLUMN candidate_json',
    );
    await v2.customStatement(
      'ALTER TABLE source_observations DROP COLUMN record_json',
    );
    await v2.customStatement('PRAGMA user_version = 1');
    await v2.close();

    final upgraded = CueDatabase(NativeDatabase(file));
    final tables = await upgraded
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((r) => r.read<String>('name'))
        .get();
    expect(
      tables,
      containsAll(['mood_states', 'mood_sessions', 'catalog_recommendations']),
    );
    final cols = await upgraded
        .customSelect('PRAGMA table_info(source_observations)')
        .map((r) => r.read<String>('name'))
        .get();
    expect(cols, contains('candidate_json'));
    expect(cols, contains('record_json'));
    await upgraded.close();
    await dir.delete(recursive: true);
  });
}
