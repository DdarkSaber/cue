import 'dart:convert';

import 'package:drift/drift.dart';

import 'db/database.dart';
import 'profile_repository.dart';

/// The durable, profile-local shortlist priority marker.
///
/// This is deliberately separate from ratings and library state. The metadata
/// is included in Cue backups and the encrypted sync section, but never
/// contributes more taste evidence than an ordinary shortlist entry.
class TryNowIntent {
  const TryNowIntent({
    required this.titleId,
    required this.active,
    required this.updatedAt,
  });

  final String titleId;
  final bool active;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'active': active,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static TryNowIntent? fromJson(String titleId, Object? value) {
    if (value is! Map) return null;
    final active = value['active'];
    final updatedAt = DateTime.tryParse('${value['updatedAt']}');
    if (active is! bool || updatedAt == null) return null;
    return TryNowIntent(
      titleId: titleId,
      active: active,
      updatedAt: updatedAt.toUtc(),
    );
  }
}

class TryNowRepository {
  TryNowRepository(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const metadataKey = 'tryNowIntentsV1';

  final CueDatabase db;
  final DateTime Function() _now;

  Future<Map<String, TryNowIntent>> all(String profileId) async {
    final raw = await ProfileRepository(db).rawSetting(profileId, metadataKey);
    if (raw == null) return {};
    return decodeSync(jsonDecode(raw));
  }

  Future<bool> isActive(String profileId, String titleId) async =>
      (await all(profileId))[titleId]?.active ?? false;

  Future<void> clear(String profileId, String titleId) =>
      db.transaction(() async {
        await setInTransaction(profileId, titleId, false, now: _now());
      });

  /// Alias for library removal callers; a durable tombstone prevents sync
  /// from restoring this title's previous priority marker.
  Future<void> clearTitle(String profileId, String titleId) =>
      clear(profileId, titleId);

  /// Tombstones every active marker when deck decisions are reset.
  Future<void> clearAll(String profileId) => db.transaction(() async {
    if (!await _profileExists(profileId)) return;
    final active = (await allInTransaction(profileId)).values
        .where((intent) => intent.active)
        .map((intent) => intent.titleId)
        .toList();
    for (final titleId in active) {
      await setInTransaction(profileId, titleId, false, now: _now());
    }
  });

  /// Reads current metadata inside the caller's Drift transaction.
  Future<Map<String, TryNowIntent>> allInTransaction(String profileId) async {
    final row =
        await (db.select(db.profileSettings)..where(
              (s) => s.profileId.equals(profileId) & s.key.equals(metadataKey),
            ))
            .getSingleOrNull();
    if (row == null) return {};
    return decodeSync(jsonDecode(row.value));
  }

  /// Stores a timestamped marker or tombstone. Must run inside a transaction.
  ///
  /// Repeating the current value is a no-op, preserving the original shortlist
  /// date and intent timestamp.
  Future<TryNowIntent> setInTransaction(
    String profileId,
    String titleId,
    bool active, {
    DateTime? now,
  }) async {
    if (!await _profileExists(profileId)) {
      throw StateError('profile_not_found');
    }
    final records = await allInTransaction(profileId);
    final current = records[titleId];
    if (current?.active == active) return current!;
    final requestedAt = (now ?? _now()).toUtc();
    final stamp = current != null && !requestedAt.isAfter(current.updatedAt)
        ? current.updatedAt.add(const Duration(milliseconds: 1))
        : requestedAt;
    final updated = TryNowIntent(
      titleId: titleId,
      active: active,
      updatedAt: stamp,
    );
    records[titleId] = updated;
    await db
        .into(db.profileSettings)
        .insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            profileId: profileId,
            key: metadataKey,
            value: jsonEncode({
              for (final entry in records.entries)
                entry.key: entry.value.toJson(),
            }),
          ),
        );
    return updated;
  }

  /// Merges timestamped metadata records independently by title.
  ///
  /// Equal timestamps choose the lower interest value, so a tombstone wins a
  /// conflict deterministically and an old device cannot revive a cleared
  /// marker.
  Future<void> mergeInTransaction(
    String profileId,
    Map<String, TryNowIntent> remote,
  ) async {
    if (!await _profileExists(profileId)) return;
    final local = await allInTransaction(profileId);
    for (final entry in remote.entries) {
      final current = local[entry.key];
      final incoming = entry.value;
      if (current == null ||
          incoming.updatedAt.isAfter(current.updatedAt) ||
          (incoming.updatedAt.isAtSameMomentAs(current.updatedAt) &&
              !incoming.active &&
              current.active)) {
        local[entry.key] = incoming;
      }
    }
    await db
        .into(db.profileSettings)
        .insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            profileId: profileId,
            key: metadataKey,
            value: jsonEncode({
              for (final entry in local.entries)
                entry.key: entry.value.toJson(),
            }),
          ),
        );
  }

  Future<void> replaceInTransaction(
    String profileId,
    Iterable<TryNowIntent> records,
  ) async {
    if (!await _profileExists(profileId)) return;
    final map = {for (final record in records) record.titleId: record};
    await db
        .into(db.profileSettings)
        .insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            profileId: profileId,
            key: metadataKey,
            value: jsonEncode({
              for (final entry in map.entries) entry.key: entry.value.toJson(),
            }),
          ),
        );
  }

  Future<bool> _profileExists(String profileId) async =>
      await (db.select(
        db.profiles,
      )..where((p) => p.id.equals(profileId))).getSingleOrNull() !=
      null;

  static Map<String, TryNowIntent> decodeSync(Object? value) {
    if (value == null) return {};
    if (value is! Map) throw const FormatException('invalid_try_now_metadata');
    return _decodeRecords(value);
  }

  static Map<String, TryNowIntent> _decodeRecords(Map<Object?, Object?> value) {
    final records = <String, TryNowIntent>{};
    for (final entry in value.entries) {
      if (entry.key is! String || (entry.key as String).isEmpty) {
        throw const FormatException('invalid_try_now_metadata');
      }
      final record = TryNowIntent.fromJson(entry.key as String, entry.value);
      if (record == null) {
        throw const FormatException('invalid_try_now_metadata');
      }
      records[entry.key as String] = record;
    }
    return records;
  }

  static Map<String, Object> encodeSync(Map<String, TryNowIntent> records) => {
    for (final entry in records.entries) entry.key: entry.value.toJson(),
  };
}
