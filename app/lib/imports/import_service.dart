import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../data/catalog_repository.dart';
import '../data/db/database.dart';
import '../data/profile_repository.dart';
import '../domain/models/library.dart';
import 'matcher.dart';
import 'records.dart';

/// A parsed and matched import waiting for the person to confirm.
class StagedImport {
  StagedImport({
    required this.parsed,
    required this.matched,
    required this.fingerprint,
    required this.existing,
  });

  final ParsedImport parsed;
  final List<MatchedRecord> matched;
  final String? fingerprint;

  /// Title ids already in the library before this import.
  final Set<String> existing;

  Iterable<MatchedRecord> get included =>
      matched.where((m) => m.included && m.resolved);

  int get readyNew =>
      included.where((m) => !existing.contains(m.titleId)).length;
  int get readyUpdates =>
      included.where((m) => existing.contains(m.titleId)).length;
  int get needsReview => matched.where((m) => !m.resolved).length;
  int get byTitle =>
      matched.where((m) => m.matchClass == MatchClass.suggested).length;
  int get byId =>
      matched.where((m) => m.matchClass == MatchClass.exactId).length;

  Map<LibraryState, int> get byState {
    final out = <LibraryState, int>{};
    for (final m in included) {
      out[m.record.state] = (out[m.record.state] ?? 0) + 1;
    }
    return out;
  }
}

class ImportSummary {
  const ImportSummary({
    required this.batchId,
    required this.checked,
    required this.added,
    required this.updated,
    required this.unchanged,
    required this.review,
    this.alreadyImported = false,
  });

  final String? batchId;
  final int checked;
  final int added;
  final int updated;
  final int unchanged;
  final int review;
  final bool alreadyImported;
}

class UndoImportResult {
  const UndoImportResult(this.reverted, this.kept);
  final int reverted;

  /// Rows changed since the import; left alone and reported.
  final int kept;
}

/// Ordering used to merge statuses without downgrading evidence.
int _rank(LibraryState s) => switch (s) {
  LibraryState.completed || LibraryState.caughtUp => 8,
  LibraryState.seen => 7,
  LibraryState.watching || LibraryState.reading => 6,
  LibraryState.partial => 5,
  LibraryState.onHold => 4,
  LibraryState.dropped => 3,
  LibraryState.planned => 2,
  LibraryState.none => 0,
};

/// Stage, commit and undo imports. Commit is one transaction that records
/// before and after rows so "Undo this import" reverses only that batch.
class ImportService {
  ImportService(this.db, this.catalog, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final CatalogRepository catalog;
  final DateTime Function() _now;

  static String fingerprintOf(Uint8List bytes) =>
      sha256.convert(bytes).toString();

  Future<StagedImport> stage(
    String profileId,
    ParsedImport parsed, {
    Uint8List? rawBytes,
    bool offlineOnly = false,
    void Function(int, int)? onProgress,
  }) async {
    final snapshot = parsed.extras?.catalog ?? const [];
    if (snapshot.isNotEmpty) await catalog.restoreSnapshot(snapshot);
    final matched = await ImportMatcher(
      catalog,
    ).match(parsed.records, offlineOnly: offlineOnly, onProgress: onProgress);
    final rows = await (db.select(
      db.userTitles,
    )..where((u) => u.profileId.equals(profileId))).get();
    return StagedImport(
      parsed: parsed,
      matched: matched,
      fingerprint: rawBytes == null ? null : fingerprintOf(rawBytes),
      existing: {for (final r in rows) r.titleId},
    );
  }

  Future<ImportSummary> commit(String profileId, StagedImport s) async {
    if (s.fingerprint != null) {
      final prior =
          await (db.select(db.importBatches)..where(
                (b) =>
                    b.profileId.equals(profileId) &
                    b.fileFingerprint.equals(s.fingerprint!) &
                    b.state.equals('completed'),
              ))
              .get();
      if (prior.isNotEmpty) {
        return ImportSummary(
          batchId: prior.first.id,
          checked: s.matched.length,
          added: 0,
          updated: 0,
          unchanged: s.included.length,
          review: s.needsReview,
          alreadyImported: true,
        );
      }
    }

    final batchId = randomId();
    final now = _now();
    var added = 0, updated = 0, unchanged = 0;
    await db.transaction(() async {
      await db
          .into(db.importBatches)
          .insert(
            ImportBatchesCompanion.insert(
              id: batchId,
              profileId: profileId,
              sourceType: s.parsed.sourceType,
              adapterVersion: s.parsed.adapterVersion,
              fileFingerprint: Value(s.fingerprint),
              state: 'committing',
              createdAt: now,
            ),
          );
      // Several records can resolve to one title (e.g. seasons): merge them.
      final seenTitles = <String>{};
      for (final m in s.matched) {
        final r = m.record;
        await db
            .into(db.sourceObservations)
            .insert(
              SourceObservationsCompanion.insert(
                id: '$batchId:${r.sourceEntryKey}',
                batchId: batchId,
                sourceEntryKey: r.sourceEntryKey,
                rawTitle: r.title,
                titleId: Value(m.titleId),
                matchClass: m.matchClass.name,
                status: r.state.code,
                ratingOriginal: Value(r.ratingOriginal),
                ratingScale: Value(r.ratingScale),
                progress: Value(r.progressValue),
                activityDate: Value(r.activityDate),
                included: Value(m.included && m.resolved),
              ),
              mode: InsertMode.insertOrReplace,
            );
        if (!m.included || !m.resolved) continue;
        final result = await _merge(profileId, m.titleId!, r, batchId, now);
        if (seenTitles.add(m.titleId!)) {
          switch (result) {
            case _Merge.added:
              added++;
            case _Merge.updated:
              updated++;
            case _Merge.unchanged:
              unchanged++;
          }
        }
      }
      final extras = s.parsed.extras;
      if (extras != null) await _restoreExtras(profileId, extras, batchId, now);
      await (db.update(
        db.importBatches,
      )..where((b) => b.id.equals(batchId))).write(
        ImportBatchesCompanion(
          state: const Value('completed'),
          countsJson: Value(
            jsonEncode({
              'checked': s.matched.length,
              'added': added,
              'updated': updated,
              'unchanged': unchanged,
              'review': s.needsReview,
            }),
          ),
        ),
      );
    });
    return ImportSummary(
      batchId: batchId,
      checked: s.matched.length,
      added: added,
      updated: updated,
      unchanged: unchanged,
      review: s.needsReview,
    );
  }

  Future<_Merge> _merge(
    String profileId,
    String titleId,
    NormalizedRecord r,
    String batchId,
    DateTime now,
  ) async {
    final existing =
        await (db.select(db.userTitles)..where(
              (u) => u.profileId.equals(profileId) & u.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    // A manual correction in Cue always wins over imported evidence.
    if (existing != null && existing.source == 'user') return _Merge.unchanged;

    final oldState = LibraryState.parse(existing?.state);
    final state = _rank(r.state) > _rank(oldState) ? r.state : oldState;
    final merged = UserTitle(
      profileId: profileId,
      titleId: titleId,
      state: state.code,
      rating: existing?.rating ?? r.rating?.code,
      rewatchMood: existing?.rewatchMood ?? r.rewatchMood?.code,
      progressUnit: existing?.progressUnit ?? r.progressUnit,
      progressValue: existing?.progressValue ?? r.progressValue,
      latestKnown: existing?.latestKnown ?? r.latestKnown,
      actualWatchedAt: existing?.actualWatchedAt ?? r.actualWatchedAt,
      note: existing?.note ?? r.note,
      source: existing?.source ?? 'import:$batchId',
      updatedAt: existing?.updatedAt ?? now,
    );
    if (existing != null && _same(existing, merged)) return _Merge.unchanged;
    final written = merged.copyWith(updatedAt: now);
    await db.into(db.userTitles).insertOnConflictUpdate(written);
    await db
        .into(db.importChanges)
        .insert(
          ImportChangesCompanion.insert(
            batchId: batchId,
            tableName_: 'user_titles',
            rowKey: titleId,
            beforeJson: Value(
              existing == null ? null : jsonEncode(existing.toJson()),
            ),
            afterJson: Value(jsonEncode(written.toJson())),
          ),
        );
    return existing == null ? _Merge.added : _Merge.updated;
  }

  /// Will try, Not interested, Not now and preferences from a Cue backup.
  /// Only adds what is missing, and records it so undo can remove it.
  Future<void> _restoreExtras(
    String profileId,
    BackupExtras x,
    String batchId,
    DateTime now,
  ) async {
    Future<bool> known(String id) async =>
        await (db.select(
          db.catalogTitles,
        )..where((t) => t.id.equals(id))).getSingleOrNull() !=
        null;
    Future<void> note(String table, String key) => db
        .into(db.importChanges)
        .insert(
          ImportChangesCompanion.insert(
            batchId: batchId,
            tableName_: table,
            rowKey: key,
            afterJson: const Value('{}'),
          ),
        );
    for (final id in x.shortlist) {
      if (!await known(id)) continue;
      final n = await db
          .into(db.shortlist)
          .insert(
            ShortlistCompanion.insert(
              profileId: profileId,
              titleId: id,
              addedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (n > 0) await note('shortlist', id);
    }
    for (final id in x.notInterested) {
      if (!await known(id)) continue;
      final existing =
          await (db.select(db.exclusions)..where(
                (e) => e.profileId.equals(profileId) & e.titleId.equals(id),
              ))
              .getSingleOrNull();
      if (existing != null) continue;
      await db
          .into(db.exclusions)
          .insert(
            ExclusionsCompanion.insert(
              profileId: profileId,
              titleId: id,
              createdAt: now,
            ),
          );
      await note('exclusions', id);
    }
    for (final e in x.notNow.entries) {
      if (!await known(e.key) || !e.value.isAfter(now)) continue;
      final n = await db
          .into(db.deferrals)
          .insert(
            DeferralsCompanion.insert(
              profileId: profileId,
              titleId: e.key,
              eligibleAfter: e.value,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (n > 0) await note('deferrals', e.key);
    }
    // Preferences only fill in what this library has not set yet.
    final have = {
      for (final r in await (db.select(
        db.profileSettings,
      )..where((p) => p.profileId.equals(profileId))).get())
        r.key,
    }..remove('_active');
    for (final e in x.settings.entries) {
      if (have.contains(e.key)) continue;
      await db
          .into(db.profileSettings)
          .insert(
            ProfileSettingsCompanion.insert(
              profileId: profileId,
              key: e.key,
              value: e.value,
            ),
          );
    }
    final p = await (db.select(
      db.profiles,
    )..where((p) => p.id.equals(profileId))).getSingle();
    final fresh = have.isEmpty;
    await (db.update(db.profiles)..where((p) => p.id.equals(profileId))).write(
      ProfilesCompanion(
        showAdult: Value(fresh ? (x.showAdult ?? p.showAdult) : p.showAdult),
        region: Value(fresh ? (x.region ?? p.region) : p.region),
        displayName: Value(p.displayName ?? x.displayName),
      ),
    );
  }

  static bool _same(UserTitle a, UserTitle b) =>
      a.state == b.state &&
      a.rating == b.rating &&
      a.rewatchMood == b.rewatchMood &&
      a.progressUnit == b.progressUnit &&
      a.progressValue == b.progressValue &&
      a.latestKnown == b.latestKnown &&
      a.actualWatchedAt == b.actualWatchedAt &&
      a.note == b.note;

  /// Reverses only this batch. Rows edited since are left alone.
  Future<UndoImportResult> undo(String profileId, String batchId) async {
    var reverted = 0, kept = 0;
    await db.transaction(() async {
      final changes =
          await (db.select(db.importChanges)
                ..where((c) => c.batchId.equals(batchId))
                ..orderBy([(c) => OrderingTerm.desc(c.seq)]))
              .get();
      for (final c in changes) {
        if (c.tableName_ != 'user_titles') {
          reverted += await _undoExtra(profileId, c);
          continue;
        }
        final current =
            await (db.select(db.userTitles)..where(
                  (u) =>
                      u.profileId.equals(profileId) &
                      u.titleId.equals(c.rowKey),
                ))
                .getSingleOrNull();
        final after = c.afterJson == null
            ? null
            : UserTitle.fromJson(
                jsonDecode(c.afterJson!) as Map<String, dynamic>,
              );
        if (current == null ||
            after == null ||
            !_same(current, after) ||
            current.source != after.source) {
          kept++;
          continue;
        }
        await (db.delete(db.userTitles)..where(
              (u) => u.profileId.equals(profileId) & u.titleId.equals(c.rowKey),
            ))
            .go();
        if (c.beforeJson != null) {
          await db
              .into(db.userTitles)
              .insert(
                UserTitle.fromJson(
                  jsonDecode(c.beforeJson!) as Map<String, dynamic>,
                ),
              );
        }
        reverted++;
      }
      await (db.update(db.importBatches)..where((b) => b.id.equals(batchId)))
          .write(const ImportBatchesCompanion(state: Value('undone')));
    });
    return UndoImportResult(reverted, kept);
  }

  Future<int> _undoExtra(String profileId, ImportChange c) async {
    Expression<bool> mine(
      GeneratedColumn<String> p,
      GeneratedColumn<String> t,
    ) => p.equals(profileId) & t.equals(c.rowKey);
    final n = switch (c.tableName_) {
      'shortlist' => await (db.delete(
        db.shortlist,
      )..where((x) => mine(x.profileId, x.titleId))).go(),
      'exclusions' => await (db.delete(
        db.exclusions,
      )..where((x) => mine(x.profileId, x.titleId))).go(),
      'deferrals' => await (db.delete(
        db.deferrals,
      )..where((x) => mine(x.profileId, x.titleId))).go(),
      _ => 0,
    };
    return n > 0 ? 1 : 0;
  }

  Future<List<ImportBatch>> batches(String profileId) =>
      (db.select(db.importBatches)
            ..where((b) => b.profileId.equals(profileId))
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .get();

  /// Observations that could not be matched, for the review queue.
  Future<List<SourceObservation>> reviewQueue(String profileId) async {
    final ids = (await batches(profileId))
        .where((b) => b.state == 'completed')
        .map((b) => b.id)
        .toList();
    if (ids.isEmpty) return const [];
    return (db.select(db.sourceObservations)
          ..where((o) => o.batchId.isIn(ids) & o.titleId.isNull())
          ..orderBy([(o) => OrderingTerm.asc(o.rawTitle)]))
        .get();
  }

  /// Resolves a queued observation to a catalog title the person picked.
  Future<void> resolve(
    String profileId,
    SourceObservation o,
    String titleId,
  ) async {
    await db.transaction(() async {
      await (db.update(
        db.sourceObservations,
      )..where((x) => x.id.equals(o.id))).write(
        SourceObservationsCompanion(
          titleId: Value(titleId),
          matchClass: const Value('confirmed'),
          included: const Value(true),
        ),
      );
      final state = LibraryState.values.firstWhere(
        (s) => s.code == o.status,
        orElse: () => LibraryState.seen,
      );
      await _merge(
        profileId,
        titleId,
        NormalizedRecord(
          sourceEntryKey: o.sourceEntryKey,
          title: o.rawTitle,
          state: state == LibraryState.none ? LibraryState.seen : state,
          progressValue: o.progress,
          activityDate: o.activityDate,
        ),
        o.batchId,
        _now(),
      );
    });
  }
}

enum _Merge { added, updated, unchanged }
