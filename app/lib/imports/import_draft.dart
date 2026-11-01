import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/catalog_gateway.dart';
import '../data/db/database.dart';
import '../data/profile_repository.dart';
import 'import_service.dart';
import 'matcher.dart';
import 'records.dart';

/// Local-only batches with no observations or library changes. They are not
/// exported or synced; confirming a preview replaces this payload with counts.
class ImportDraft {
  ImportDraft({
    required this.id,
    required this.parsed,
    required this.offlineOnly,
    this.rawBytes,
    this.dayFirst = false,
    this.matched = const [],
    this.existing = const {},
    this.ready = false,
  });

  final String id;
  final ParsedImport parsed;
  final bool offlineOnly;
  final Uint8List? rawBytes;
  final bool dayFirst;
  List<MatchedRecord> matched;
  Set<String> existing;
  bool ready;

  StagedImport get staged => StagedImport(
    parsed: parsed,
    matched: matched,
    fingerprint: rawBytes == null
        ? null
        : ImportService.fingerprintOf(rawBytes!),
    existing: existing,
    draftId: id,
  );

  String encode() => jsonEncode({
    'version': 1,
    'parsed': {
      'sourceType': parsed.sourceType,
      'adapterVersion': parsed.adapterVersion,
      'records': [for (final r in parsed.records) r.toJson()],
      'warnings': parsed.warnings,
      'skipped': parsed.skipped,
      'needsDateOrder': parsed.needsDateOrder,
      'dateRange': parsed.dateRange == null
          ? null
          : [
              parsed.dateRange!.$1.toIso8601String(),
              parsed.dateRange!.$2.toIso8601String(),
            ],
      'extras': parsed.extras == null
          ? null
          : {
              'shortlist': parsed.extras!.shortlist,
              'notInterested': parsed.extras!.notInterested,
              'notNow': parsed.extras!.notNow.map(
                (k, v) => MapEntry(k, v.toIso8601String()),
              ),
              'catalog': parsed.extras!.catalog,
              'settings': parsed.extras!.settings,
              'showAdult': parsed.extras!.showAdult,
              'region': parsed.extras!.region,
              'displayName': parsed.extras!.displayName,
            },
    },
    'rawBytes': rawBytes == null ? null : base64Encode(rawBytes!),
    'offlineOnly': offlineOnly,
    'dayFirst': dayFirst,
    'existing': existing.toList(),
    'matched': [
      for (final m in matched)
        {
          'titleId': m.titleId,
          'matchClass': m.matchClass.name,
          'included': m.included,
          'candidate': m.candidate?.json,
          'unchecked': m.unchecked,
          'adultHidden': m.adultHidden,
        },
    ],
  });

  factory ImportDraft.decode(ImportBatch batch) {
    final j = jsonDecode(batch.countsJson) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Unsupported import checkpoint version');
    }
    final p = j['parsed'] as Map<String, dynamic>;
    final records = [
      for (final r in p['records'] as List)
        NormalizedRecord.fromJson(r as Map<String, dynamic>),
    ];
    final extras = p['extras'] as Map<String, dynamic>?;
    final dates = p['dateRange'] as List?;
    final matches = [
      for (final m in j['matched'] as List) m as Map<String, dynamic>,
    ];
    if (matches.length > records.length ||
        (batch.state == 'match_ready' && matches.length != records.length)) {
      throw const FormatException('Incomplete import checkpoint');
    }
    return ImportDraft(
      id: batch.id,
      parsed: ParsedImport(
        sourceType: p['sourceType'] as String,
        adapterVersion: p['adapterVersion'] as String,
        records: records,
        warnings: List<String>.from(p['warnings'] as List),
        skipped: p['skipped'] as int,
        needsDateOrder: p['needsDateOrder'] as bool,
        dateRange: dates == null
            ? null
            : (
                DateTime.parse(dates[0] as String),
                DateTime.parse(dates[1] as String),
              ),
        extras: extras == null
            ? null
            : BackupExtras(
                shortlist: List<String>.from(extras['shortlist'] as List),
                notInterested: List<String>.from(
                  extras['notInterested'] as List,
                ),
                notNow: (extras['notNow'] as Map<String, dynamic>).map(
                  (k, v) => MapEntry(k, DateTime.parse(v as String)),
                ),
                catalog: [
                  for (final c in extras['catalog'] as List)
                    Map<String, dynamic>.from(c as Map),
                ],
                settings: Map<String, String>.from(extras['settings'] as Map),
                showAdult: extras['showAdult'] as bool?,
                region: extras['region'] as String?,
                displayName: extras['displayName'] as String?,
              ),
      ),
      rawBytes: j['rawBytes'] == null
          ? null
          : base64Decode(j['rawBytes'] as String),
      offlineOnly: j['offlineOnly'] as bool,
      dayFirst: j['dayFirst'] as bool,
      existing: Set<String>.from(j['existing'] as List),
      ready: batch.state == 'match_ready',
      matched: [
        for (var i = 0; i < matches.length; i++)
          MatchedRecord(
            records[i],
            matches[i]['titleId'] as String?,
            MatchClass.values.byName(matches[i]['matchClass'] as String),
            included: matches[i]['included'] as bool,
            candidate: matches[i]['candidate'] == null
                ? null
                : CatalogItemDto(
                    Map<String, dynamic>.from(matches[i]['candidate'] as Map),
                  ),
            unchecked: matches[i]['unchecked'] as bool,
            adultHidden: matches[i]['adultHidden'] as bool,
          ),
      ],
    );
  }
}

class ImportDraftStore {
  ImportDraftStore(this.db);
  final CueDatabase db;
  static const states = ['matching', 'match_ready'];

  Future<ImportDraft?> load(String profileId) async {
    final row =
        await (db.select(db.importBatches)..where(
              (b) => b.profileId.equals(profileId) & b.state.isIn(states),
            ))
            .getSingleOrNull();
    return row == null ? null : ImportDraft.decode(row);
  }

  Future<ImportDraft> create(
    String profileId,
    ParsedImport parsed, {
    Uint8List? rawBytes,
    required bool offlineOnly,
    required bool dayFirst,
  }) async {
    final draft = ImportDraft(
      id: randomId(),
      parsed: parsed,
      offlineOnly: offlineOnly,
      rawBytes: rawBytes,
      dayFirst: dayFirst,
    );
    await db.transaction(() async {
      await discard(profileId);
      await db
          .into(db.importBatches)
          .insert(
            ImportBatchesCompanion.insert(
              id: draft.id,
              profileId: profileId,
              sourceType: parsed.sourceType,
              adapterVersion: parsed.adapterVersion,
              fileFingerprint: Value(draft.staged.fingerprint),
              state: 'matching',
              countsJson: Value(draft.encode()),
              createdAt: DateTime.now(),
            ),
          );
    });
    return draft;
  }

  Future<void> save(String profileId, ImportDraft draft) async {
    final changed =
        await (db.update(db.importBatches)..where(
              (b) =>
                  b.id.equals(draft.id) &
                  b.profileId.equals(profileId) &
                  b.state.isIn(states),
            ))
            .write(
              ImportBatchesCompanion(
                state: Value(draft.ready ? 'match_ready' : 'matching'),
                countsJson: Value(draft.encode()),
              ),
            );
    if (changed != 1) throw StateError('Import checkpoint no longer exists');
  }

  Future<void> discard(String profileId) async {
    await (db.delete(
      db.importBatches,
    )..where((b) => b.profileId.equals(profileId) & b.state.isIn(states))).go();
  }
}
