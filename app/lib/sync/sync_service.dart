import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../data/backup_service.dart';
import '../data/db/database.dart';
import '../data/library_repository.dart';
import '../data/profile_repository.dart';
import '../imports/detect.dart';
import '../imports/import_service.dart';
import '../imports/records.dart';
import 'sync_crypto.dart';

/// Where the sync code is kept: platform secure storage (Keystore,
/// Keychain; WebCrypto-wrapped storage on the web).
abstract class CodeStore {
  Future<String?> read(String profileId);
  Future<void> write(String profileId, String code);
  Future<void> delete(String profileId);
}

class SecureCodeStore implements CodeStore {
  const SecureCodeStore();
  static const _storage = FlutterSecureStorage();
  String _key(String p) => 'cue_sync_code_$p';

  @override
  Future<String?> read(String profileId) => _storage.read(key: _key(profileId));
  @override
  Future<void> write(String profileId, String code) =>
      _storage.write(key: _key(profileId), value: code);
  @override
  Future<void> delete(String profileId) =>
      _storage.delete(key: _key(profileId));
}

class MemoryCodeStore implements CodeStore {
  final _codes = <String, String>{};
  @override
  Future<String?> read(String profileId) async => _codes[profileId];
  @override
  Future<void> write(String profileId, String code) async =>
      _codes[profileId] = code;
  @override
  Future<void> delete(String profileId) async => _codes.remove(profileId);
}

/// Talks to the Worker's /sync routes. Only ids, tokens and ciphertext.
abstract class SyncRemote {
  Future<({int version, String data})?> get(String id, String token);

  /// Returns the new version, or throws [SyncConflict].
  Future<int> put(String id, String token, int expected, String data);
  Future<void> delete(String id, String token);
}

class SyncConflict implements Exception {
  const SyncConflict(this.version);
  final int version;
}

class SyncFailed implements Exception {
  const SyncFailed(this.code);
  final String code;
}

class HttpSyncRemote implements SyncRemote {
  HttpSyncRemote(this.base, {http.Client? client})
    : _client = client ?? http.Client();
  final String base;
  final http.Client _client;

  Future<http.Response> _send(
    String method,
    String id,
    String token, [
    Object? body,
  ]) async {
    final req = http.Request(method, Uri.parse('$base/sync/$id'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      return await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 30)),
      );
    } on Object {
      throw const SyncFailed('offline');
    }
  }

  Map<String, dynamic> _json(http.Response r) =>
      Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);

  @override
  Future<({int version, String data})?> get(String id, String token) async {
    final r = await _send('GET', id, token);
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw SyncFailed('http_${r.statusCode}');
    final j = _json(r);
    return (version: (j['version'] as num).toInt(), data: j['data'] as String);
  }

  @override
  Future<int> put(String id, String token, int expected, String data) async {
    final r = await _send('PUT', id, token, {
      'version': expected,
      'data': data,
    });
    if (r.statusCode == 409) {
      throw SyncConflict((_json(r)['version'] as num).toInt());
    }
    if (r.statusCode != 200) throw SyncFailed('http_${r.statusCode}');
    return (_json(r)['version'] as num).toInt();
  }

  @override
  Future<void> delete(String id, String token) async {
    final r = await _send('DELETE', id, token);
    if (r.statusCode != 200 && r.statusCode != 404) {
      throw SyncFailed('http_${r.statusCode}');
    }
  }
}

class SyncResult {
  const SyncResult({
    required this.version,
    required this.pulled,
    required this.pushed,
    this.moodChanged = false,
  });
  final int version;

  /// Titles added or changed here from the other devices.
  final int pulled;
  final bool pushed;

  /// The other device's mood learning replaced this one's.
  final bool moodChanged;
}

/// End-to-end encrypted sync of one library. A merge imports the other
/// copy, then settles each title by its last edit, and each list, the
/// library settings and mood learning by when that part last changed
/// (so removals travel too).
class SyncService {
  SyncService({
    required this.remote,
    required this.codes,
    required this.backup,
    required this.imports,
    required this.profiles,
    required this.library,
    required this.db,
  });

  final SyncRemote remote;
  final CodeStore codes;
  final BackupService backup;
  final ImportService imports;
  final ProfileRepository profiles;
  final LibraryRepository library;
  final CueDatabase db;

  static const _versionKey = 'syncVersion';
  static const _lastKey = 'syncLast';

  Future<String?> code(String profileId) => codes.read(profileId);

  Future<DateTime?> lastSynced(String profileId) async {
    final raw = await profiles.rawSetting(profileId, _lastKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Turns sync on with a new code and uploads this library.
  Future<String> enable(String profileId) async {
    final code = newSyncCode();
    await codes.write(profileId, normalizeSyncCode(code)!);
    await profiles.setRawSetting(profileId, _versionKey, '0');
    await syncNow(profileId);
    return code;
  }

  /// Joins an existing sync from another device; merges both ways.
  Future<SyncResult> join(String profileId, String input) async {
    final code = normalizeSyncCode(input);
    if (code == null) throw const SyncFailed('bad_code');
    final keys = await deriveSyncKeys(code);
    final existing = await remote.get(keys.id, keys.token);
    if (existing == null) throw const SyncFailed('no_copy');
    // Opening proves the code is right before anything is saved.
    await openBlob(existing.data, keys.key);
    await codes.write(profileId, code);
    await profiles.setRawSetting(profileId, _versionKey, '0');
    return syncNow(profileId);
  }

  /// Pull, merge, push. Retries once if another device wrote in between.
  Future<SyncResult> syncNow(String profileId) async {
    final code = await codes.read(profileId);
    if (code == null) throw const SyncFailed('off');
    final keys = await deriveSyncKeys(code);
    var pulled = 0;
    var moodChanged = false;
    for (var attempt = 0; attempt < 3; attempt++) {
      await _stampChangedSections(profileId);
      final current = await remote.get(keys.id, keys.token);
      var base = 0;
      if (current != null) {
        base = current.version;
        final known =
            int.tryParse(
              await profiles.rawSetting(profileId, _versionKey) ?? '',
            ) ??
            0;
        if (current.version != known) {
          final remoteJson = await openBlob(current.data, keys.key);
          pulled += await _merge(profileId, remoteJson);
          moodChanged |= await _mergeSections(profileId, remoteJson);
        }
      }
      final json = await _exportWithSections(profileId);
      final sealed = await sealBlob(json, keys.key);
      try {
        final v = await remote.put(keys.id, keys.token, base, sealed);
        await profiles.setRawSetting(profileId, _versionKey, '$v');
        await profiles.setRawSetting(
          profileId,
          _lastKey,
          DateTime.now().toUtc().toIso8601String(),
        );
        return SyncResult(
          version: v,
          pulled: pulled,
          pushed: true,
          moodChanged: moodChanged,
        );
      } on SyncConflict {
        continue;
      }
    }
    throw const SyncFailed('busy');
  }

  Future<int> _merge(String profileId, String json) async {
    // The import merge only adds and never lowers a status, so remember
    // this device's rows first and settle each title by its last edit.
    final before = {
      for (final u in await (db.select(
        db.userTitles,
      )..where((u) => u.profileId.equals(profileId))).get())
        u.titleId: u,
    };
    await _snapshotLists(profileId);
    final bytes = Uint8List.fromList(utf8.encode(json));
    final parsed = parseDetected(detect(bytes, 'sync.json'));
    final staged = await imports.stage(
      profileId,
      ParsedImport(
        sourceType: 'sync',
        adapterVersion: parsed.adapterVersion,
        records: parsed.records,
        skipped: parsed.skipped,
        extras: parsed.extras,
      ),
      rawBytes: bytes,
      offlineOnly: true,
    );
    final summary = await imports.commit(profileId, staged);
    await _lastEditWins(profileId, json, before);
    await library.recomputeWeights(profileId);
    return summary.added + summary.updated;
  }

  /// For every title both sides know, keeps the version edited last: the
  /// local row as it was before the merge, or the remote item. Items from
  /// older blobs without `updated_at` keep the import result.
  Future<void> _lastEditWins(
    String profileId,
    String json,
    Map<String, UserTitle> before,
  ) async {
    final items = (jsonDecode(json) as Map)['items'];
    if (items is! List) return;
    await db.transaction(() async {
      for (final it in items) {
        if (it is! Map) continue;
        final id = it['cue_id'];
        final at = DateTime.tryParse('${it['updated_at']}');
        if (id is! String || at == null) continue;
        final local = before[id];
        if (local != null) {
          // Stored times have one-second precision. On a tie both devices
          // pick the same side by comparing the content, so they converge.
          final tie = at.isAtSameMomentAs(local.updatedAt);
          final localWins = tie
              ? _content(local).compareTo(_remoteContent(it)) >= 0
              : !at.isAfter(local.updatedAt);
          if (localWins) {
            await db.into(db.userTitles).insertOnConflictUpdate(local);
            continue;
          }
        }
        final progress = it['progress'] is Map ? it['progress'] as Map : null;
        final watched = DateTime.tryParse('${it['watched_at']}');
        await (db.update(db.userTitles)..where(
              (u) => u.profileId.equals(profileId) & u.titleId.equals(id),
            ))
            .write(
              UserTitlesCompanion(
                state: Value('${it['status'] ?? 'none'}'),
                rating: Value(it['rating'] as String?),
                rewatchMood: Value(it['rewatch_mood'] as String?),
                progressUnit: Value(progress?['unit'] as String?),
                progressValue: Value(
                  (progress?['read_to'] as num?)?.toDouble(),
                ),
                latestKnown: Value(
                  (progress?['latest_known'] as num?)?.toDouble(),
                ),
                actualWatchedAt: Value(watched),
                note: Value(it['note'] as String?),
                updatedAt: Value(at),
              ),
            );
      }
    });
  }

  // ---------------------------------------------------------------------
  // Sections: lists, library settings and mood learning travel as wholes,
  // and the side that changed a section last wins it.
  // ---------------------------------------------------------------------

  static const _snapKey = 'syncSnap';
  bool _firstRound = false;
  static const _lists = ['shortlist', 'not_interested', 'not_now'];

  /// Settings that describe the library rather than this device.
  static const librarySettings = [
    'defaultKinds',
    'includeRewatches',
    'smartMoodText',
  ];

  Future<Map<String, String>> _fingerprints(String profileId) async {
    final sl = await (db.select(
      db.shortlist,
    )..where((s) => s.profileId.equals(profileId))).get();
    final ex =
        await (db.select(db.exclusions)..where(
              (x) => x.profileId.equals(profileId) & x.active.equals(true),
            ))
            .get();
    final de = await (db.select(
      db.deferrals,
    )..where((d) => d.profileId.equals(profileId))).get();
    String sorted(Iterable<String> ids) => (ids.toList()..sort()).join('|');
    final settings = <String>[];
    for (final k in librarySettings) {
      settings.add('$k=${await profiles.rawSetting(profileId, k) ?? ''}');
    }
    return {
      'shortlist': sorted(sl.map((s) => s.titleId)),
      'not_interested': sorted(ex.map((x) => x.titleId)),
      'not_now': sorted(
        de.map((d) => '${d.titleId}@${d.eligibleAfter.toIso8601String()}'),
      ),
      'settings': settings.join('|'),
    };
  }

  Future<DateTime> _sectionAt(String profileId, String section) async =>
      DateTime.tryParse(
        await profiles.rawSetting(profileId, 'syncAt_$section') ?? '',
      ) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Future<void> _setSectionAt(String profileId, String section, DateTime at) =>
      profiles.setRawSetting(
        profileId,
        'syncAt_$section',
        at.toUtc().toIso8601String(),
      );

  /// Marks the sections that changed here since the last round.
  Future<void> _stampChangedSections(String profileId) async {
    final now = await _fingerprints(profileId);
    final raw = await profiles.rawSetting(profileId, _snapKey);
    // A device's first round merges lists (union) instead of replacing.
    _firstRound = raw == null;
    final before = raw == null
        ? const <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final stamp = DateTime.now().toUtc();
    for (final e in now.entries) {
      if (before[e.key] != e.value) {
        await _setSectionAt(profileId, e.key, stamp);
      }
    }
    await profiles.setRawSetting(profileId, _snapKey, jsonEncode(now));
  }

  Future<String> _exportWithSections(String profileId) async {
    final doc =
        jsonDecode(await backup.export(profileId)) as Map<String, dynamic>;
    final mood = await (db.select(
      db.moodStates,
    )..where((m) => m.profileId.equals(profileId))).getSingleOrNull();
    doc['sync'] = {
      'at': {
        for (final s in [..._lists, 'settings'])
          s: (await _sectionAt(profileId, s)).toIso8601String(),
        if (mood != null) 'mood': mood.updatedAt.toUtc().toIso8601String(),
      },
      'library_settings': {
        for (final k in librarySettings)
          k: await profiles.rawSetting(profileId, k),
      },
      if (mood != null)
        'mood': {'modes': mood.modesJson, 'words': mood.wordsJson},
    };
    return jsonEncode(doc);
  }

  /// Applies the other copy's sections that changed after this device's.
  /// Returns whether mood learning was replaced.
  Future<bool> _mergeSections(String profileId, String json) async {
    final doc = jsonDecode(json) as Map<String, dynamic>;
    final sync = doc['sync'];
    if (sync is! Map) return false;
    final at = (sync['at'] as Map?) ?? const {};
    DateTime? remoteAt(String s) => DateTime.tryParse('${at[s]}');
    final ids = await _knownTitles();
    String? idOf(Object? r) =>
        r is Map && ids.contains(r['cue_id']) ? r['cue_id'] as String : null;

    for (final section in _lists) {
      final theirs = remoteAt(section);
      final mine = await _sectionAt(profileId, section);
      final rows = (doc[section] as List?) ?? const [];
      if (_firstRound) {
        // Keep the union the import made, and make it the newest version
        // so the other devices take it too.
        await _setSectionAt(profileId, section, DateTime.now().toUtc());
        continue;
      }
      if (theirs == null || !theirs.isAfter(mine)) {
        await _restoreList(profileId, section);
        continue;
      }
      await db.transaction(() async {
        final now = DateTime.now();
        switch (section) {
          case 'shortlist':
            await (db.delete(
              db.shortlist,
            )..where((s) => s.profileId.equals(profileId))).go();
            for (final r in rows) {
              final id = idOf(r);
              if (id == null) continue;
              await db
                  .into(db.shortlist)
                  .insertOnConflictUpdate(
                    ShortlistCompanion.insert(
                      profileId: profileId,
                      titleId: id,
                      addedAt: now,
                    ),
                  );
            }
          case 'not_interested':
            await (db.update(db.exclusions)
                  ..where((x) => x.profileId.equals(profileId)))
                .write(const ExclusionsCompanion(active: Value(false)));
            for (final r in rows) {
              final id = idOf(r);
              if (id == null) continue;
              await db
                  .into(db.exclusions)
                  .insertOnConflictUpdate(
                    ExclusionsCompanion.insert(
                      profileId: profileId,
                      titleId: id,
                      active: const Value(true),
                      createdAt: now,
                    ),
                  );
            }
          case 'not_now':
            await (db.delete(
              db.deferrals,
            )..where((d) => d.profileId.equals(profileId))).go();
            for (final r in rows) {
              final id = idOf(r);
              final until = r is Map
                  ? DateTime.tryParse('${r['until']}')
                  : null;
              if (id == null || until == null) continue;
              await db
                  .into(db.deferrals)
                  .insertOnConflictUpdate(
                    DeferralsCompanion.insert(
                      profileId: profileId,
                      titleId: id,
                      eligibleAfter: until,
                    ),
                  );
            }
        }
      });
      await _setSectionAt(profileId, section, theirs);
    }

    final settingsAt = remoteAt('settings');
    final remoteSettings = sync['library_settings'];
    if (settingsAt != null &&
        remoteSettings is Map &&
        settingsAt.isAfter(await _sectionAt(profileId, 'settings'))) {
      for (final k in librarySettings) {
        final v = remoteSettings[k];
        await profiles.setRawSetting(profileId, k, v is String ? v : null);
      }
      await _setSectionAt(profileId, 'settings', settingsAt);
    }

    var moodChanged = false;
    final moodAt = remoteAt('mood');
    final mood = sync['mood'];
    if (moodAt != null && mood is Map) {
      final local = await (db.select(
        db.moodStates,
      )..where((m) => m.profileId.equals(profileId))).getSingleOrNull();
      if (local == null || moodAt.isAfter(local.updatedAt)) {
        await db
            .into(db.moodStates)
            .insertOnConflictUpdate(
              MoodStatesCompanion.insert(
                profileId: profileId,
                modesJson: Value('${mood['modes'] ?? '[]'}'),
                wordsJson: Value('${mood['words'] ?? '{}'}'),
                updatedAt: moodAt,
              ),
            );
        moodChanged = true;
      }
    }
    // Remember what the lists look like now, so only later edits count.
    await profiles.setRawSetting(
      profileId,
      _snapKey,
      jsonEncode(await _fingerprints(profileId)),
    );
    return moodChanged;
  }

  Future<Set<String>> _knownTitles() async => {
    for (final t in await db.select(db.catalogTitles).get()) t.id,
  };

  // The list rows as they were before the import merge unioned them.
  final _listSnapshot = <String, List<Object>>{};

  Future<void> _snapshotLists(String profileId) async {
    _listSnapshot
      ..['shortlist'] = await (db.select(
        db.shortlist,
      )..where((s) => s.profileId.equals(profileId))).get()
      ..['not_interested'] = await (db.select(
        db.exclusions,
      )..where((x) => x.profileId.equals(profileId))).get()
      ..['not_now'] = await (db.select(
        db.deferrals,
      )..where((d) => d.profileId.equals(profileId))).get();
  }

  /// This device's list won: undo what the import merge added to it.
  Future<void> _restoreList(String profileId, String section) async {
    final rows = _listSnapshot[section];
    if (rows == null) return;
    await db.transaction(() async {
      switch (section) {
        case 'shortlist':
          await (db.delete(
            db.shortlist,
          )..where((s) => s.profileId.equals(profileId))).go();
          for (final r in rows.cast<ShortlistEntry>()) {
            await db.into(db.shortlist).insertOnConflictUpdate(r);
          }
        case 'not_interested':
          await (db.delete(
            db.exclusions,
          )..where((x) => x.profileId.equals(profileId))).go();
          for (final r in rows.cast<Exclusion>()) {
            await db.into(db.exclusions).insertOnConflictUpdate(r);
          }
        case 'not_now':
          await (db.delete(
            db.deferrals,
          )..where((d) => d.profileId.equals(profileId))).go();
          for (final r in rows.cast<Deferral>()) {
            await db.into(db.deferrals).insertOnConflictUpdate(r);
          }
      }
    });
  }

  /// The fields a title's last edit decides, in a fixed order, for ties.
  static String _content(UserTitle u) =>
      [u.state, u.rating, u.rewatchMood, u.progressValue, u.note].join('|');

  static String _remoteContent(Map<dynamic, dynamic> it) => [
    it['status'] ?? 'none',
    it['rating'],
    it['rewatch_mood'],
    ((it['progress'] as Map?)?['read_to'] as num?)?.toDouble(),
    it['note'],
  ].join('|');

  /// Stops syncing on this device. The encrypted copy stays for others.
  Future<void> disable(String profileId) async {
    await codes.delete(profileId);
    await profiles.setRawSetting(profileId, _versionKey, null);
  }

  /// Deletes the encrypted copy from the Worker, then turns sync off here.
  Future<void> deleteRemote(String profileId) async {
    final code = await codes.read(profileId);
    if (code != null) {
      final keys = await deriveSyncKeys(code);
      await remote.delete(keys.id, keys.token);
    }
    await disable(profileId);
  }
}
