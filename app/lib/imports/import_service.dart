import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../data/catalog_gateway.dart' show CatalogItemDto, CatalogUnavailable;
import '../data/catalog_repository.dart';
import '../data/db/database.dart';
import '../data/profile_repository.dart';
import '../data/library_repository.dart';
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
    this.draftId,
  });

  final ParsedImport parsed;
  final List<MatchedRecord> matched;
  final String? fingerprint;

  /// Local matching checkpoint, consumed only when this preview is committed.
  final String? draftId;

  /// Title ids already in the library before this import.
  final Set<String> existing;

  Iterable<MatchedRecord> get included =>
      matched.where((m) => m.included && m.resolved);

  int get readyNew =>
      included.where((m) => !existing.contains(m.titleId)).length;
  int get readyUpdates =>
      included.where((m) => existing.contains(m.titleId)).length;

  /// Not matched, or offered as similar and not ticked: these wait in Library.
  /// Adult-rated titles are kept out on purpose and are not "to review".
  int get needsReview => matched
      .where(
        (m) =>
            (!m.resolved && !m.adultHidden) ||
            (m.matchClass == MatchClass.similar && !m.included),
      )
      .length;

  /// Netflix "played" rows: activity, not proof of watching. Unticked.
  int get unconfirmed =>
      matched.where((m) => m.resolved && !m.record.confirmed).length;
  int get adultHidden => matched.where((m) => m.adultHidden).length;
  int get similar =>
      matched.where((m) => m.matchClass == MatchClass.similar).length;

  /// Titles whose lookup failed (offline, busy), not "no match".
  int get unchecked => matched.where((m) => m.unchecked).length;
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
/// What a second look at the review queue achieved.
class RecheckSummary {
  const RecheckSummary({
    this.checked = 0,
    this.matched = 0,
    this.suggested = 0,
    this.unchecked = 0,
    this.remaining = 0,
  });

  /// Entries looked at before finishing or being stopped.
  final int checked;

  /// Linked on their own (one unambiguous exact title).
  final int matched;

  /// Have a close title waiting for a yes or no.
  final int suggested;

  /// The lookup could not finish (offline, busy); worth trying again.
  final int unchecked;

  /// Entries still in the queue afterwards, suggestions included.
  final int remaining;
}

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
    List<MatchedRecord> checkpoint = const [],
    Future<void> Function(List<MatchedRecord>)? onCheckpoint,
  }) async {
    final snapshot = parsed.extras?.catalog ?? const [];
    if (snapshot.isNotEmpty) await catalog.restoreSnapshot(snapshot);
    final List<MatchedRecord> matched;
    if (onCheckpoint == null) {
      matched = await ImportMatcher(
        catalog,
      ).match(parsed.records, offlineOnly: offlineOnly, onProgress: onProgress);
    } else {
      matched = [...checkpoint];
      for (
        var i = matched.length;
        i < parsed.records.length;
        i += ImportMatcher.batchSize
      ) {
        final chunk = parsed.records
            .skip(i)
            .take(ImportMatcher.batchSize)
            .toList();
        matched.addAll(
          await ImportMatcher(catalog).match(chunk, offlineOnly: offlineOnly),
        );
        await onCheckpoint(List.of(matched));
        onProgress?.call(matched.length, parsed.records.length);
      }
    }
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

  Future<ImportSummary> commit(String profileId, StagedImport s) =>
      db.transaction(() async {
        final result = await _commit(profileId, s);
        await LibraryRepository(db, clock: _now).recomputeWeights(profileId);
        return result;
      });

  Future<ImportSummary> _commit(String profileId, StagedImport s) async {
    if (s.draftId != null) {
      final draft =
          await (db.select(db.importBatches)..where(
                (b) => b.id.equals(s.draftId!) & b.profileId.equals(profileId),
              ))
              .getSingleOrNull();
      if (draft == null ||
          (draft.state != 'match_ready' && draft.state != 'completed')) {
        throw StateError('This import preview is no longer available');
      }
      if (draft.state == 'completed') {
        return ImportSummary(
          batchId: draft.id,
          checked: s.matched.length,
          added: 0,
          updated: 0,
          unchanged: s.included.length,
          review: s.needsReview,
          alreadyImported: true,
        );
      }
    }
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
        if (s.draftId != null) {
          await (db.delete(db.importBatches)..where(
                (b) => b.id.equals(s.draftId!) & b.profileId.equals(profileId),
              ))
              .go();
        }
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

    final batchId = s.draftId ?? randomId();
    final now = _now();
    var added = 0, updated = 0, unchanged = 0;
    await db.transaction(() async {
      if (s.draftId == null) {
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
      } else {
        await (db.update(db.importBatches)..where((b) => b.id.equals(batchId)))
            .write(const ImportBatchesCompanion(state: Value('committing')));
      }
      // Several records can resolve to one title (e.g. seasons): merge them.
      final seenTitles = <String>{};
      for (final m in s.matched) {
        final r = m.record;
        // A similar title is linked, and its catalog row added, only when the
        // person ticked it; otherwise the entry waits in the review queue.
        String? tid = m.titleId;
        if (m.matchClass == MatchClass.similar) {
          tid = m.included
              ? (await catalog.upsert([m.candidate!])).first
              : null;
        }
        await db
            .into(db.sourceObservations)
            .insert(
              SourceObservationsCompanion.insert(
                id: '$batchId:${r.sourceEntryKey}',
                batchId: batchId,
                sourceEntryKey: r.sourceEntryKey,
                rawTitle: r.title,
                titleId: Value(tid),
                matchClass: m.adultHidden ? 'adult_hidden' : m.matchClass.name,
                status: r.state.code,
                ratingOriginal: Value(r.ratingOriginal),
                ratingScale: Value(r.ratingScale),
                progress: Value(r.progressValue),
                activityDate: Value(r.activityDate),
                included: Value(m.included && tid != null),
                recordJson: Value(tid == null ? jsonEncode(r.toJson()) : null),
                candidateJson: Value(
                  tid == null && m.candidate != null
                      ? jsonEncode(m.candidate!.json)
                      : null,
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
        if (!m.included || tid == null) continue;
        final result = await _merge(
          profileId,
          tid,
          r,
          batchId,
          now,
          syncing: s.parsed.sourceType == 'sync',
        );
        if (seenTitles.add(tid)) {
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
    DateTime now, {
    bool syncing = false,
  }) async {
    final existing =
        await (db.select(db.userTitles)..where(
              (u) => u.profileId.equals(profileId) & u.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    // A manual correction in Cue always wins over imported evidence.
    if (existing != null && existing.source == 'user') return _Merge.unchanged;
    final library = LibraryRepository(db);
    final removed = await library.removedAt(profileId, titleId);
    if (syncing &&
        removed != null &&
        (existing == null || !existing.updatedAt.isAfter(removed))) {
      return _Merge.unchanged;
    }

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
    final written = merged.copyWith(
      updatedAt: syncing
          ? now
          : LibraryRepository.editAfterRemoval(now, removed),
    );
    if (!syncing) await library.clearRemoval(profileId, titleId);
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
        final library = LibraryRepository(db, clock: _now);
        if (c.beforeJson == null) {
          await library.removeEntry(profileId, c.rowKey);
        } else {
          final at = LibraryRepository.editAfterRemoval(
            _now(),
            await library.removedAt(profileId, c.rowKey),
          );
          await library.clearRemoval(profileId, c.rowKey);
          await db
              .into(db.userTitles)
              .insertOnConflictUpdate(
                UserTitle.fromJson(
                  jsonDecode(c.beforeJson!) as Map<String, dynamic>,
                ).copyWith(updatedAt: at),
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
          ..where(
            (o) =>
                o.batchId.isIn(ids) &
                o.titleId.isNull() &
                o.matchClass.isNotIn(const ['dismissed', 'adult_hidden']),
          )
          ..orderBy([(o) => OrderingTerm.asc(o.rawTitle)]))
        .get();
  }

  static NormalizedRecord _recordOf(SourceObservation o) {
    final raw = o.recordJson;
    if (raw != null) {
      return NormalizedRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    final state = LibraryState.values.firstWhere(
      (s) => s.code == o.status,
      orElse: () => LibraryState.seen,
    );
    return NormalizedRecord(
      sourceEntryKey: o.sourceEntryKey,
      title: o.rawTitle,
      state: state == LibraryState.none ? LibraryState.seen : state,
      ratingOriginal: o.ratingOriginal,
      ratingScale: o.ratingScale,
      progressValue: o.progress,
      activityDate: o.activityDate,
    );
  }

  /// Checks the whole review queue again, more thoroughly than the import
  /// did: the full matching chain first, then a title search per entry
  /// still unmatched. An unambiguous exact title is linked; a close one is
  /// stored as a suggestion to confirm; a lookup that could not finish is
  /// counted as not checked rather than as no match. Stops early when
  /// [cancelled] answers true.
  Future<RecheckSummary> recheckReview(
    String profileId, {
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final queue = await reviewQueue(profileId);
    var matched = 0, suggested = 0, unchecked = 0, done = 0;
    onProgress?.call(0, queue.length);
    for (var i = 0; i < queue.length; i += ImportMatcher.batchSize) {
      if (cancelled?.call() ?? false) break;
      final chunk = queue.skip(i).take(ImportMatcher.batchSize).toList();
      final records = [for (final o in chunk) _recordOf(o)];
      final matcher = ImportMatcher(catalog);
      List<MatchedRecord?> first;
      try {
        first = await matcher.match(records);
      } on CatalogUnavailable {
        first = List.filled(chunk.length, null);
      }
      for (var j = 0; j < chunk.length; j++) {
        if (cancelled?.call() ?? false) break;
        final o = chunk[j];
        var m = first[j];
        if (m == null || (!m.resolved && m.candidate == null)) {
          try {
            m = await matcher.deepMatch(records[j]);
          } on CatalogUnavailable {
            m = null;
          }
        }
        if (m == null || (m.unchecked && !m.resolved && m.candidate == null)) {
          unchecked++;
        } else if (m.adultHidden) {
          // Stays as it is: adult titles are never linked on their own.
        } else if (m.resolved && m.matchClass != MatchClass.similar) {
          try {
            await resolve(profileId, o, m.titleId!);
            matched++;
          } on StateError {
            // Answered by hand while the check ran.
          }
        } else if (m.candidate != null) {
          final json = jsonEncode(m.candidate!.json);
          if (json != o.candidateJson) {
            await (db.update(db.sourceObservations)
                  ..where((x) => x.id.equals(o.id) & x.titleId.isNull()))
                .write(SourceObservationsCompanion(candidateJson: Value(json)));
          }
          suggested++;
        }
        onProgress?.call(++done, queue.length);
      }
    }
    if (matched > 0) {
      await LibraryRepository(db, clock: _now).recomputeWeights(profileId);
    }
    return RecheckSummary(
      checked: done,
      matched: matched,
      suggested: suggested,
      unchecked: unchecked,
      remaining: (await reviewQueue(profileId)).length,
    );
  }

  /// Drops a stored suggestion the person said is wrong; the entry stays in
  /// the queue to be matched by hand.
  Future<void> rejectSuggestion(SourceObservation o) =>
      (db.update(db.sourceObservations)..where((x) => x.id.equals(o.id))).write(
        const SourceObservationsCompanion(candidateJson: Value(null)),
      );

  /// Takes an entry out of the review queue ("not in my history"). The
  /// import itself and its undo are unaffected.
  /// Links every queued entry that came with a similar title to that title.
  /// Returns how many were accepted.
  Future<int> acceptAllSimilar(
    String profileId,
    Iterable<SourceObservation> list,
  ) async {
    var n = 0;
    for (final o in list) {
      final raw = o.candidateJson;
      if (raw == null) continue;
      final ids = await catalog.upsert([
        CatalogItemDto(Map<String, dynamic>.from(jsonDecode(raw) as Map)),
      ]);
      await resolve(profileId, o, ids.first);
      n++;
    }
    return n;
  }

  /// Takes many entries out of the review queue at once.
  Future<void> dismissAll(Iterable<SourceObservation> list) =>
      db.transaction(() async {
        for (final o in list) {
          await dismiss(o);
        }
      });

  Future<void> dismiss(SourceObservation o) =>
      (db.update(db.sourceObservations)..where((x) => x.id.equals(o.id))).write(
        const SourceObservationsCompanion(matchClass: Value('dismissed')),
      );

  Future<String> observationProfile(SourceObservation o) async {
    final batch = await (db.select(
      db.importBatches,
    )..where((b) => b.id.equals(o.batchId))).getSingleOrNull();
    if (batch == null || batch.state != 'completed') {
      throw StateError('This import is no longer available for review');
    }
    return batch.profileId;
  }

  /// Resolves a queued observation to a catalog title the person picked.
  /// Links a review entry to [titleId]. [alsoSeen] are further entries the
  /// same row stands for (other seasons, films): added with the same status
  /// but unrated, so one show does not count several times for taste.
  Future<void> resolve(
    String profileId,
    SourceObservation o,
    String titleId, {
    Iterable<String> alsoSeen = const [],
  }) async {
    await db.transaction(() async {
      if (await observationProfile(o) != profileId) {
        throw StateError('This entry belongs to another library');
      }
      final current = await (db.select(
        db.sourceObservations,
      )..where((x) => x.id.equals(o.id))).getSingleOrNull();
      if (current == null ||
          current.titleId != null ||
          current.matchClass == 'dismissed' ||
          current.matchClass == 'adult_hidden') {
        throw StateError('This entry is no longer waiting for review');
      }
      await (db.update(
        db.sourceObservations,
      )..where((x) => x.id.equals(o.id))).write(
        SourceObservationsCompanion(
          titleId: Value(titleId),
          matchClass: const Value('confirmed'),
          included: const Value(true),
          recordJson: const Value(null),
          candidateJson: const Value(null),
        ),
      );
      final state = LibraryState.values.firstWhere(
        (s) => s.code == current.status,
        orElse: () => LibraryState.seen,
      );
      final original = current.recordJson == null
          ? NormalizedRecord(
              sourceEntryKey: current.sourceEntryKey,
              title: current.rawTitle,
              state: state == LibraryState.none ? LibraryState.seen : state,
              ratingOriginal: current.ratingOriginal,
              ratingScale: current.ratingScale,
              progressValue: current.progress,
              activityDate: current.activityDate,
            )
          : NormalizedRecord.fromJson(
              jsonDecode(current.recordJson!) as Map<String, dynamic>,
            );
      await _merge(
        profileId,
        titleId,
        original.state == LibraryState.none
            ? original.copyWith(state: LibraryState.seen)
            : original,
        o.batchId,
        _now(),
      );
      // The person's own pick: the same name in a later import matches it.
      await catalog.rememberImportName(original.kind, original.title, titleId);
      for (final extra in alsoSeen) {
        if (extra == titleId) continue;
        await _merge(
          profileId,
          extra,
          NormalizedRecord(
            sourceEntryKey: '${original.sourceEntryKey}:also:$extra',
            title: original.title,
            kind: original.kind,
            state: original.state == LibraryState.none
                ? LibraryState.seen
                : original.state,
            activityDate: original.activityDate,
          ),
          o.batchId,
          _now(),
        );
      }
      await LibraryRepository(db, clock: _now).recomputeWeights(profileId);
    });
  }
}

enum _Merge { added, updated, unchanged }
