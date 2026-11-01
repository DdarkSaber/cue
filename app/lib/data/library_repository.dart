import 'package:drift/drift.dart';

import '../domain/models/library.dart';
import '../domain/models/title.dart';
import '../domain/ranker.dart';
import 'db/database.dart';
import 'franchise_exclusion_repository.dart';
import 'try_now_repository.dart';

/// A decision as Library lists it.
class DecisionRow {
  const DecisionRow(this.event, this.title);
  final DecisionEvent event;
  final Title? title;
}

class LibraryContentEntry {
  const LibraryContentEntry({
    required this.title,
    this.entry,
    this.shortlisted = false,
    this.excluded = false,
    this.deferred = false,
    this.metadataAvailable = true,
  });
  final Title title;
  final LibraryEntry? entry;
  final bool shortlisted;
  final bool excluded;
  final bool deferred;
  final bool metadataAvailable;
}

/// Profile-scoped reads and edits of the personal library.
class LibraryRepository {
  LibraryRepository(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final DateTime Function() _now;

  LibraryEntry _entry(UserTitle u) => LibraryEntry(
    titleId: u.titleId,
    state: LibraryState.parse(u.state),
    rating: Rating.parse(u.rating),
    rewatchMood: RewatchMood.parse(u.rewatchMood),
    actualWatchedAt: u.actualWatchedAt,
    progressUnit: u.progressUnit,
    progressValue: u.progressValue,
    latestKnown: u.latestKnown,
  );

  Future<ProfileSignals> signals(String profileId) async {
    final version =
        await (db.select(db.tagWeights)..where(
              (w) => w.profileId.equals(profileId) & w.tag.equals(_evidenceTag),
            ))
            .getSingleOrNull();
    if (version == null) await recomputeWeights(profileId);
    final now = _now();
    final ex =
        await (db.select(db.exclusions)..where(
              (x) => x.profileId.equals(profileId) & x.active.equals(true),
            ))
            .get();
    final de =
        await (db.select(db.deferrals)..where(
              (x) =>
                  x.profileId.equals(profileId) &
                  x.eligibleAfter.isBiggerThanValue(now),
            ))
            .get();
    final sl = await (db.select(
      db.shortlist,
    )..where((x) => x.profileId.equals(profileId))).get();
    final ut = await (db.select(
      db.userTitles,
    )..where((x) => x.profileId.equals(profileId))).get();
    final tw = await (db.select(
      db.tagWeights,
    )..where((x) => x.profileId.equals(profileId))).get();
    final evidence = await _evidenceCount(profileId);
    final evidenceRow =
        await (db.select(db.tagWeights)..where(
              (w) => w.profileId.equals(profileId) & w.tag.equals(_evidenceTag),
            ))
            .getSingleOrNull();

    final kindRatings = <MediaKind, int>{};
    final rated = ut.where((u) => u.rating != null).map((u) => u.titleId);
    if (rated.isNotEmpty) {
      final kinds =
          await (db.selectOnly(db.catalogTitles)
                ..addColumns([db.catalogTitles.mediaKind])
                ..where(db.catalogTitles.id.isIn(rated)))
              .get();
      for (final r in kinds) {
        final k = MediaKind.parse(r.read(db.catalogTitles.mediaKind));
        kindRatings[k] = (kindRatings[k] ?? 0) + 1;
      }
    }

    return ProfileSignals(
      excluded: {for (final x in ex) x.titleId},
      excludedFranchises: await FranchiseExclusionRepository(db)
          .activeScopes(profileId),
      deferred: {for (final x in de) x.titleId},
      shortlisted: {for (final x in sl) x.titleId},
      library: {for (final u in ut) u.titleId: _entry(u)},
      weights: {
        for (final w in tw)
          if (w.tag != _evidenceTag && w.tag != '_evidence') w.tag: w.weight,
      },
      evidenceTitles: evidence,
      evidenceStrength: evidenceRow?.weight ?? 0,
      weakHistoryIds: {
        for (final u in ut)
          if (u.rating == null &&
              u.source.startsWith('import:') &&
              {
                LibraryState.watching,
                LibraryState.reading,
                LibraryState.completed,
              }.contains(LibraryState.parse(u.state)))
            u.titleId,
      },
      kindRatings: kindRatings,
    );
  }

  /// Evidence titles are counted when weights are recomputed and stored
  /// under a reserved tag, so reading signals stays cheap.
  Future<int> _evidenceCount(String profileId) async {
    final row =
        await (db.select(db.tagWeights)..where(
              (w) => w.profileId.equals(profileId) & w.tag.equals(_evidenceTag),
            ))
            .getSingleOrNull();
    return row?.evidenceCount ?? 0;
  }

  static const _evidenceTag = '_evidence_v2';

  /// Recomputes tag weights from distinct evidence: ratings, Will try and
  /// Not interested. Re-importing the same records cannot double them.
  Future<void> recomputeWeights(String profileId) async {
    final ut = await (db.select(
      db.userTitles,
    )..where((x) => x.profileId.equals(profileId))).get();
    final sl = await (db.select(
      db.shortlist,
    )..where((x) => x.profileId.equals(profileId))).get();
    final ex =
        await (db.select(db.exclusions)..where(
              (x) => x.profileId.equals(profileId) & x.active.equals(true),
            ))
            .get();

    final evidence = <String, double>{};
    for (final u in ut) {
      final r = Rating.parse(u.rating);
      if (r != null) {
        evidence[u.titleId] = (evidence[u.titleId] ?? 0) + r.weight;
      } else if (u.source.startsWith('import:')) {
        final weak = switch (LibraryState.parse(u.state)) {
          LibraryState.watching || LibraryState.reading => 0.2,
          LibraryState.completed => 0.15,
          _ => 0.0,
        };
        if (weak > 0) evidence[u.titleId] = weak;
      }
    }
    final ratedIds = {
      for (final u in ut)
        if (u.rating != null) u.titleId,
    };
    for (final s in sl) {
      if (ratedIds.contains(s.titleId)) continue;
      evidence[s.titleId] = 1;
    }
    for (final x in ex) {
      evidence[x.titleId] = (evidence[x.titleId] ?? 0) - 0.3;
    }

    final rows = await (db.select(
      db.catalogTitles,
    )..where((t) => t.id.isIn(evidence.keys.toList()))).get();
    final titles = rows
        .where((r) => Title.fromRow(r).features.isNotEmpty)
        .toList();
    final weights = <String, double>{};
    final counts = <String, int>{};
    for (final row in titles) {
      final t = Title.fromRow(row);
      final e = evidence[t.id]!;
      for (final f in t.features) {
        weights[f] = (weights[f] ?? 0) + e;
        counts[f] = (counts[f] ?? 0) + 1;
      }
    }
    final now = _now();
    await db.transaction(() async {
      await (db.delete(
        db.tagWeights,
      )..where((w) => w.profileId.equals(profileId))).go();
      await db.batch((b) {
        b.insertAll(db.tagWeights, [
          for (final e in weights.entries)
            TagWeightsCompanion.insert(
              profileId: profileId,
              tag: e.key,
              weight: e.value,
              evidenceCount: counts[e.key]!,
              updatedAt: now,
            ),
          TagWeightsCompanion.insert(
            profileId: profileId,
            tag: _evidenceTag,
            weight: titles.fold<double>(
              0,
              (sum, row) => sum + evidence[row.id]!.abs().clamp(0, 1),
            ),
            evidenceCount: titles.length,
            updatedAt: now,
          ),
        ]);
      });
    });
  }

  Future<int> decisionCount(String profileId) async {
    final c = db.decisionEvents.id.count();
    final q = db.selectOnly(db.decisionEvents)
      ..addColumns([c])
      ..where(db.decisionEvents.profileId.equals(profileId));
    return (await q.getSingle()).read(c) ?? 0;
  }

  /// Shortlist, newest first.
  Future<List<Title>> shortlist(String profileId) async {
    final rows =
        await (db.select(db.shortlist)
              ..where((x) => x.profileId.equals(profileId))
              ..orderBy([(x) => OrderingTerm.desc(x.addedAt)]))
            .get();
    final titles = await _titles(rows.map((r) => r.titleId));
    return [
      for (final r in rows)
        if (titles[r.titleId] != null) titles[r.titleId]!,
    ];
  }

  /// "Reset swipes": forgets every deck decision and what it implied
  /// (Will try, Not interested, Not now, learned tag weights) but keeps the
  /// titles that came from imports or were rated in Library.
  Future<void> resetSwipes(String profileId) => db.transaction(() async {
    await TryNowRepository(db, clock: _now).clearAll(profileId);
    // Titles that exist only because of a Watched swipe (no import behind
    // them, no rating) go too; everything imported or rated stays.
    final watched = {
      for (final e
          in await (db.select(db.decisionEvents)..where(
                (x) =>
                    x.profileId.equals(profileId) &
                    x.action.isIn(const ['watched', 'read']),
              ))
              .get())
        e.titleId,
    };
    final batches = await (db.select(
      db.importBatches,
    )..where((b) => b.profileId.equals(profileId))).get();
    final imported = {
      for (final o in await (db.select(
        db.sourceObservations,
      )..where((o) => o.batchId.isIn([for (final b in batches) b.id]))).get())
        ?o.titleId,
    };
    final swipeOnly = watched.difference(imported);
    if (swipeOnly.isNotEmpty) {
      final rows =
          await (db.select(db.userTitles)..where(
                (x) =>
                    x.profileId.equals(profileId) &
                    x.titleId.isIn(swipeOnly) &
                    x.rating.isNull(),
              ))
              .get();
      for (final row in rows) {
        await removeEntry(profileId, row.titleId);
      }
    }
    await (db.delete(
      db.decisionEvents,
    )..where((x) => x.profileId.equals(profileId))).go();
    await (db.delete(
      db.shortlist,
    )..where((x) => x.profileId.equals(profileId))).go();
    await (db.delete(
      db.exclusions,
    )..where((x) => x.profileId.equals(profileId))).go();
    await (db.delete(
      db.deferrals,
    )..where((x) => x.profileId.equals(profileId))).go();
    await (db.delete(
      db.tagWeights,
    )..where((x) => x.profileId.equals(profileId))).go();
  });

  Future<void> removeFromShortlist(String profileId, String titleId) =>
      db.transaction(() async {
        await TryNowRepository(db, clock: _now).clearTitle(profileId, titleId);
        await (db.delete(db.shortlist)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .go();
      });

  Future<Map<String, Title>> _titles(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const {};
    final rows = await (db.select(
      db.catalogTitles,
    )..where((t) => t.id.isIn(list))).get();
    return {for (final r in rows) r.id: Title.fromRow(r)};
  }

  /// All currently held titles, not historical or reversed decision events.
  /// Missing catalog metadata is shown explicitly rather than hiding a row.
  Future<List<LibraryContentEntry>> contents(String profileId) =>
      db.transaction(() async {
        final s = await signals(profileId);
        final ids = {
          ...s.library.keys,
          ...s.shortlisted,
          ...s.excluded,
          ...s.deferred,
        };
        final titles = await _titles(ids);
        return [
          for (final id in ids)
            LibraryContentEntry(
              title:
                  titles[id] ??
                  Title(id: id, kind: MediaKind.unknown, titleEn: id),
              entry: s.library[id],
              shortlisted: s.shortlisted.contains(id),
              excluded: s.excluded.contains(id),
              deferred: s.deferred.contains(id),
              metadataAvailable: titles.containsKey(id),
            ),
        ];
      });

  Future<void> removeTitle(String profileId, String titleId) =>
      db.transaction(() async {
        await removeEntry(profileId, titleId);
        await removeFromShortlist(profileId, titleId);
        await (db.delete(db.exclusions)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .go();
        await (db.delete(db.deferrals)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .go();
      });

  /// Entries with their titles, for Library sections.
  Future<List<(LibraryEntry, Title)>> entries(String profileId) async {
    final ut =
        await (db.select(db.userTitles)
              ..where((x) => x.profileId.equals(profileId))
              ..orderBy([(x) => OrderingTerm.desc(x.updatedAt)]))
            .get();
    final titles = await _titles(ut.map((u) => u.titleId));
    return [
      for (final u in ut)
        if (titles[u.titleId] != null) (_entry(u), titles[u.titleId]!),
    ];
  }

  Future<LibraryEntry?> entry(String profileId, String titleId) async {
    final u =
        await (db.select(db.userTitles)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    return u == null ? null : _entry(u);
  }

  /// Manual library edit. A manual edit always wins over imports.
  Future<void> saveEntry(
    String profileId,
    String titleId, {
    required LibraryState state,
    Rating? rating,
    RewatchMood? rewatchMood,
    DateTime? actualWatchedAt,
  }) => db.transaction(() async {
    final existing =
        await (db.select(db.userTitles)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    final removed = await removedAt(profileId, titleId);
    await clearRemoval(profileId, titleId);
    await db
        .into(db.userTitles)
        .insertOnConflictUpdate(
          UserTitlesCompanion.insert(
            profileId: profileId,
            titleId: titleId,
            state: Value(state.code),
            rating: Value(rating?.code),
            rewatchMood: Value(rewatchMood?.code),
            actualWatchedAt: Value(actualWatchedAt),
            progressUnit: Value(existing?.progressUnit),
            progressValue: Value(existing?.progressValue),
            latestKnown: Value(existing?.latestKnown),
            note: Value(existing?.note),
            source: const Value('user'),
            updatedAt: editAfterRemoval(_now(), removed),
          ),
        );
  });

  /// A tombstone prevents an older synced copy from restoring a removal.
  Future<void> removeEntry(String profileId, String titleId) =>
      db.transaction(() async {
        await TryNowRepository(db, clock: _now).clearTitle(profileId, titleId);
        await recordRemoval(profileId, titleId, _now());
        await (db.delete(db.userTitles)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .go();
      });

  static const removalPrefix = 'libraryRemoved:';

  Future<DateTime?> removedAt(String profileId, String titleId) async {
    final row =
        await (db.select(db.profileSettings)..where(
              (s) =>
                  s.profileId.equals(profileId) &
                  s.key.equals('$removalPrefix$titleId'),
            ))
            .getSingleOrNull();
    return row == null ? null : DateTime.parse(row.value);
  }

  Future<Map<String, DateTime>> removals(String profileId) async => {
    for (final row
        in await (db.select(db.profileSettings)..where(
              (s) =>
                  s.profileId.equals(profileId) & s.key.like('$removalPrefix%'),
            ))
            .get())
      row.key.substring(removalPrefix.length): DateTime.parse(row.value),
  };

  Future<void> recordRemoval(
    String profileId,
    String titleId,
    DateTime when,
  ) async {
    final at = DateTime.fromMillisecondsSinceEpoch(
      when.millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: true,
    );
    final prior = await removedAt(profileId, titleId);
    if (prior != null && !at.isAfter(prior)) return;
    await db
        .into(db.profileSettings)
        .insertOnConflictUpdate(
          ProfileSettingsCompanion.insert(
            profileId: profileId,
            key: '$removalPrefix$titleId',
            value: at.toIso8601String(),
          ),
        );
  }

  Future<void> clearRemoval(String profileId, String titleId) async {
    await (db.delete(db.profileSettings)..where(
          (s) =>
              s.profileId.equals(profileId) &
              s.key.equals('$removalPrefix$titleId'),
        ))
        .go();
  }

  /// Drift stores row timestamps to the second. An explicit re-add must be
  /// later even if it happens in the same second as the removal.
  static DateTime editAfterRemoval(DateTime now, DateTime? removed) {
    final second = DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: true,
    );
    return removed != null && !second.isAfter(removed)
        ? removed.add(const Duration(seconds: 1))
        : now;
  }

  Future<void> applyRemovals(String profileId) async {
    final deleted = await removals(profileId);
    final rows = await (db.select(
      db.userTitles,
    )..where((u) => u.profileId.equals(profileId))).get();
    for (final row in rows) {
      final at = deleted[row.titleId];
      if (at != null && !row.updatedAt.isAfter(at)) {
        await (db.delete(db.userTitles)..where(
              (u) =>
                  u.profileId.equals(profileId) & u.titleId.equals(row.titleId),
            ))
            .go();
      }
    }
  }

  /// Titles hidden by Not interested (active) or Not now (still deferred).
  Future<List<(Title, bool excluded, DateTime? until)>> hidden(
    String profileId,
  ) async {
    final now = _now();
    final ex =
        await (db.select(db.exclusions)
              ..where(
                (x) => x.profileId.equals(profileId) & x.active.equals(true),
              )
              ..orderBy([(x) => OrderingTerm.desc(x.createdAt)]))
            .get();
    final de =
        await (db.select(db.deferrals)..where(
              (x) =>
                  x.profileId.equals(profileId) &
                  x.eligibleAfter.isBiggerThanValue(now),
            ))
            .get();
    final titles = await _titles([
      ...ex.map((x) => x.titleId),
      ...de.map((d) => d.titleId),
    ]);
    return [
      for (final x in ex)
        if (titles[x.titleId] != null) (titles[x.titleId]!, true, null),
      for (final d in de)
        if (titles[d.titleId] != null)
          (titles[d.titleId]!, false, d.eligibleAfter),
    ];
  }

  /// Recent decisions with titles, newest first.
  Future<List<DecisionRow>> recentDecisions(
    String profileId, {
    int limit = 50,
  }) async {
    final rows =
        await (db.select(db.decisionEvents)
              ..where((x) => x.profileId.equals(profileId))
              ..orderBy([(x) => OrderingTerm.desc(x.createdAt)])
              ..limit(limit))
            .get();
    final titles = await _titles(rows.map((r) => r.titleId));
    return [for (final r in rows) DecisionRow(r, titles[r.titleId])];
  }
}
