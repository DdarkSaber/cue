import 'dart:math';

import 'package:drift/drift.dart';

import '../domain/models/settings.dart';
import 'db/database.dart';

String randomId([int bytes = 16]) {
  final r = Random.secure();
  return List.generate(
    bytes,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Local profiles. No account: the first open creates one silently.
class ProfileRepository {
  ProfileRepository(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final DateTime Function() _now;

  static const _activeKey = '_active';

  /// The active profile, created on first run.
  Future<Profile> ensureActive() async {
    final all = await (db.select(
      db.profiles,
    )..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();
    if (all.isEmpty) return create();
    for (final p in all) {
      final flag = await _setting(p.id, _activeKey);
      if (flag == 'true') return p;
    }
    return all.first;
  }

  Future<List<Profile>> all() => (db.select(
    db.profiles,
  )..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();

  Future<Profile> create({String? displayName}) async {
    final p = Profile(
      id: randomId(),
      displayName: displayName,
      region: 'IN',
      showAdult: false,
      createdAt: _now(),
    );
    await db.into(db.profiles).insert(p);
    await activate(p.id);
    return p;
  }

  Future<void> activate(String profileId) async {
    await db.transaction(() async {
      await (db.delete(
        db.profileSettings,
      )..where((s) => s.key.equals(_activeKey))).go();
      await db
          .into(db.profileSettings)
          .insertOnConflictUpdate(
            ProfileSettingsCompanion.insert(
              profileId: profileId,
              key: _activeKey,
              value: 'true',
            ),
          );
    });
  }

  Future<String?> _setting(String profileId, String key) async {
    final row =
        await (db.select(db.profileSettings)
              ..where((s) => s.profileId.equals(profileId) & s.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  Future<AppSettings> loadSettings(String profileId) async {
    final profile = await (db.select(
      db.profiles,
    )..where((p) => p.id.equals(profileId))).getSingle();
    final rows = await (db.select(
      db.profileSettings,
    )..where((s) => s.profileId.equals(profileId))).get();
    return AppSettings.fromEntries(
      {for (final r in rows) r.key: r.value},
      showAdult: profile.showAdult,
      region: profile.region,
      displayName: profile.displayName,
    );
  }

  Future<void> saveSettings(String profileId, AppSettings s) async {
    await db.transaction(() async {
      await (db.update(
        db.profiles,
      )..where((p) => p.id.equals(profileId))).write(
        ProfilesCompanion(
          showAdult: Value(s.showAdult),
          region: Value(s.region),
          displayName: Value(s.displayName),
        ),
      );
      for (final e in s.toEntries().entries) {
        await db
            .into(db.profileSettings)
            .insertOnConflictUpdate(
              ProfileSettingsCompanion.insert(
                profileId: profileId,
                key: e.key,
                value: e.value,
              ),
            );
      }
    });
  }

  Future<String?> rawSetting(String profileId, String key) =>
      _setting(profileId, key);

  Future<void> setRawSetting(String profileId, String key, String? value) {
    if (value == null) {
      return (db.delete(
        db.profileSettings,
      )..where((s) => s.profileId.equals(profileId) & s.key.equals(key))).go();
    }
    return db
        .into(db.profileSettings)
        .insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            profileId: profileId,
            key: key,
            value: value,
          ),
        );
  }

  /// Deletes a library and everything derived from it, in one transaction.
  /// Shared catalog rows stay.
  Future<void> deleteProfile(String profileId) => db.transaction(() async {
    final batches = await (db.select(
      db.importBatches,
    )..where((b) => b.profileId.equals(profileId))).get();
    final ids = batches.map((b) => b.id).toList();
    await (db.delete(db.importChanges)..where((c) => c.batchId.isIn(ids))).go();
    await (db.delete(
      db.sourceObservations,
    )..where((o) => o.batchId.isIn(ids))).go();
    await (db.delete(
      db.importBatches,
    )..where((b) => b.profileId.equals(profileId))).go();
    await (db.delete(
      db.userTitles,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.decisionEvents,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.shortlist,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.deferrals,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.exclusions,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.tagWeights,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(
      db.profileSettings,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (db.delete(db.profiles)..where((p) => p.id.equals(profileId))).go();
  });
}
