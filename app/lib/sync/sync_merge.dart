import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/backup_service.dart';
import '../data/db/database.dart';
import '../data/library_repository.dart';
import '../data/profile_repository.dart';
import '../imports/detect.dart';
import '../imports/import_service.dart';
import '../imports/records.dart';

/// How two copies of a library become one. Titles: the import merge adds
/// what is missing, then each title keeps its last edit. Lists, library
/// settings and mood learning travel as sections: the side that changed a
/// section last wins it (a device's first sync unions the lists instead).
class SyncMerge {
  SyncMerge({
    required this.db,
    required this.profiles,
    required this.imports,
    required this.library,
    required this.backup,
  });

  final CueDatabase db;
  final ProfileRepository profiles;
  final ImportService imports;
  final LibraryRepository library;
  final BackupService backup;

  Future<int> merge(String profileId, String json) async {
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
  Future<void> stampChangedSections(String profileId) async {
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

  Future<String> exportWithSections(String profileId) async {
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
  Future<bool> mergeSections(String profileId, String json) async {
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
}
