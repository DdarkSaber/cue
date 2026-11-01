import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/db/database.dart';
import '../data/try_now_repository.dart';
import '../data/profile_repository.dart';
import 'models/decision.dart';
import 'models/library.dart';
import 'models/title.dart';

/// Where a decision was made.
enum DeckContext { deck, revisit, shortlist, tryNow }

class DecisionResult {
  const DecisionResult(
    this.eventId,
    this.titleId,
    this.decision, {
    this.tryNow = false,
    this.alreadySaved = false,
    this.repeated = false,
  });
  final String eventId;
  final String titleId;
  final Decision decision;
  final bool tryNow;
  final bool alreadySaved;
  final bool repeated;
}

class UndoResult {
  const UndoResult(
    this.titleId,
    this.decision, {
    this.tryNow = false,
    this.eventId,
  });
  final String titleId;
  final Decision? decision;
  final bool tryNow;
  final String? eventId;
}

/// Thrown when a decision could not be stored; the card returns.
class DecisionFailed implements Exception {
  const DecisionFailed();
}

/// Decision commands and undo. Every command is one transaction that
/// writes an event plus the rows it changes, with the replaced rows kept on
/// the event so undo still works after a restart.
class DecisionService {
  DecisionService(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final DateTime Function() _now;
  late final _tryNow = TryNowRepository(db, clock: _now);

  static const deferral = Duration(days: 14);

  /// Undo reaches back this many decisions.
  static const undoDepth = 40;

  static const _decisionCodes = [
    'try_now',
    'will_try',
    'not_now',
    'watched',
    'read',
    'not_interested',
  ];

  Future<DecisionResult> decide(
    String profileId,
    Title title,
    Decision d, {
    DeckContext context = DeckContext.deck,
    String? mood,

    /// How long Not now hides the title; [deferral] when not given.
    Duration? defer,
  }) async {
    final now = _now();
    final id = randomId();
    try {
      await db.transaction(() async {
        final before = await _snapshot(profileId, title.id);
        switch (d) {
          case Decision.willTry:
            await db
                .into(db.shortlist)
                .insertOnConflictUpdate(
                  ShortlistCompanion.insert(
                    profileId: profileId,
                    titleId: title.id,
                    addedAt: now,
                  ),
                );
          case Decision.notNow:
            await db
                .into(db.deferrals)
                .insertOnConflictUpdate(
                  DeferralsCompanion.insert(
                    profileId: profileId,
                    titleId: title.id,
                    eligibleAfter: now.add(defer ?? deferral),
                  ),
                );
          case Decision.watched:
            final existing = before.userTitle;
            final state = LibraryState.parse(existing?.state);
            // Seen is not completed; never downgrade a completion.
            final keep =
                state == LibraryState.completed ||
                state == LibraryState.caughtUp;
            await db
                .into(db.userTitles)
                .insertOnConflictUpdate(
                  UserTitlesCompanion.insert(
                    profileId: profileId,
                    titleId: title.id,
                    state: Value(keep ? state.code : LibraryState.seen.code),
                    rating: Value(existing?.rating),
                    rewatchMood: Value(existing?.rewatchMood),
                    progressUnit: Value(existing?.progressUnit),
                    progressValue: Value(existing?.progressValue),
                    latestKnown: Value(existing?.latestKnown),
                    actualWatchedAt: Value(existing?.actualWatchedAt),
                    note: Value(existing?.note),
                    source: Value(existing?.source ?? 'user'),
                    updatedAt: now,
                  ),
                );
          case Decision.notInterested:
            await db
                .into(db.exclusions)
                .insertOnConflictUpdate(
                  ExclusionsCompanion.insert(
                    profileId: profileId,
                    titleId: title.id,
                    active: const Value(true),
                    createdAt: now,
                  ),
                );
        }
        // Acting on a shortlisted title from the shortlist settles it.
        if (context == DeckContext.shortlist && d != Decision.willTry) {
          await (db.delete(db.shortlist)..where(
                (s) =>
                    s.profileId.equals(profileId) & s.titleId.equals(title.id),
              ))
              .go();
        }
        if (await _tryNow.isActive(profileId, title.id)) {
          await _tryNow.setInTransaction(profileId, title.id, false, now: now);
        }
        await db
            .into(db.decisionEvents)
            .insert(
              DecisionEventsCompanion.insert(
                id: id,
                profileId: profileId,
                titleId: title.id,
                action: d == Decision.watched && title.kind.isReading
                    ? 'read'
                    : d.code,
                context: Value(context.name),
                mood: Value(mood),
                createdAt: now,
                beforeJson: Value(jsonEncode(before.toJson())),
              ),
            );
      });
    } on Exception {
      throw const DecisionFailed();
    }
    return DecisionResult(id, title.id, d);
  }

  /// Promotes a title to the top of the existing Will try shortlist.
  ///
  /// This is a directional choice only: it does not create a rating or change
  /// watched/read state, progress, dates, or long-term taste evidence.
  Future<DecisionResult> tryNow(String profileId, Title title) async {
    final id = randomId();
    try {
      return await db.transaction(() async {
        await _requireProfile(profileId);
        final snapshot = await _snapshot(profileId, title.id);
        final before = snapshot.shortlist == null
            ? _Snapshot(
                snapshot.shortlist,
                snapshot.deferral,
                snapshot.exclusion,
                snapshot.userTitle,
                null,
              )
            : snapshot;
        final alreadySaved = before.shortlist != null;
        if (alreadySaved && before.tryNowIntent?.active == true) {
          final priorEvent =
              await (db.select(db.decisionEvents)
                    ..where(
                      (e) =>
                          e.profileId.equals(profileId) &
                          e.titleId.equals(title.id) &
                          e.action.equals('try_now'),
                    )
                    ..orderBy([(e) => OrderingTerm.desc(e.createdAt)])
                    ..limit(1))
                  .getSingleOrNull();
          return DecisionResult(
            priorEvent?.id ?? id,
            title.id,
            Decision.willTry,
            tryNow: true,
            alreadySaved: true,
            repeated: true,
          );
        }

        final now = _now();
        if (!alreadySaved) {
          if (snapshot.tryNowIntent?.active == true) {
            await _tryNow.setInTransaction(
              profileId,
              title.id,
              false,
              now: _now(),
            );
          }
          await db
              .into(db.shortlist)
              .insert(
                ShortlistCompanion.insert(
                  profileId: profileId,
                  titleId: title.id,
                  addedAt: now,
                ),
              );
        }
        final intent = await _tryNow.setInTransaction(
          profileId,
          title.id,
          true,
          now: now,
        );
        final after = await _snapshot(profileId, title.id);
        await db
            .into(db.decisionEvents)
            .insert(
              DecisionEventsCompanion.insert(
                id: id,
                profileId: profileId,
                titleId: title.id,
                action: 'try_now',
                context: const Value('tryNow'),
                createdAt: intent.updatedAt,
                beforeJson: Value(
                  jsonEncode({
                    ...before.toJson(),
                    'tryNowAfterAt': intent.updatedAt.toIso8601String(),
                    'shortlistAfterAddedAt': after.shortlist!.addedAt
                        .toIso8601String(),
                    'tryNowAfterSnapshot': after.toJson(),
                  }),
                ),
              ),
            );
        return DecisionResult(
          id,
          title.id,
          Decision.willTry,
          tryNow: true,
          alreadySaved: alreadySaved,
          repeated: false,
        );
      });
    } on Exception {
      throw const DecisionFailed();
    }
  }

  /// Reverses the most recent decision that has not been undone.
  /// Returns what it reversed, or null if there is nothing to undo.
  Future<UndoResult?> undoLast(String profileId) async {
    final target = await _undoTarget(profileId);
    if (target == null) return null;
    return _undoEvent(profileId, target.id);
  }

  /// Undo a specific promotion without risking a newer decision.
  Future<UndoResult?> undoTryNow(String profileId, String eventId) async {
    return _undoEvent(profileId, eventId, requireTryNow: true);
  }

  Future<UndoResult?> _undoEvent(
    String profileId,
    String eventId, {
    bool requireTryNow = false,
  }) async {
    var applied = false;
    DecisionEvent? undoneEvent;
    await db.transaction(() async {
      if (!await _profileExists(profileId)) return;
      final target =
          await (db.select(db.decisionEvents)..where(
                (e) => e.profileId.equals(profileId) & e.id.equals(eventId),
              ))
              .getSingleOrNull();
      if (target == null ||
          !_decisionCodes.contains(target.action) ||
          (requireTryNow && target.action != 'try_now')) {
        return;
      }
      final alreadyReversed = await (db.select(
        db.decisionEvents,
      )..where((e) => e.reversesEventId.equals(target.id))).getSingleOrNull();
      if (alreadyReversed != null) return;
      final before = _Snapshot.fromJson(
        target.beforeJson == null
            ? const {}
            : jsonDecode(target.beforeJson!) as Map<String, dynamic>,
      );
      if (target.action == 'try_now') {
        final payload = target.beforeJson == null
            ? const <String, dynamic>{}
            : jsonDecode(target.beforeJson!) as Map<String, dynamic>;
        final afterAt = DateTime.tryParse('${payload['tryNowAfterAt']}');
        final afterAddedAt = DateTime.tryParse(
          '${payload['shortlistAfterAddedAt']}',
        );
        final current = await _snapshot(profileId, target.titleId);
        final expectedSnapshot = payload['tryNowAfterSnapshot'];
        if (afterAt == null ||
            afterAddedAt == null ||
            current.tryNowIntent?.active != true ||
            !current.tryNowIntent!.updatedAt.isAtSameMomentAs(afterAt) ||
            current.shortlist == null ||
            !current.shortlist!.addedAt.isAtSameMomentAs(afterAddedAt) ||
            expectedSnapshot is! Map ||
            jsonEncode(current.toJson()) != jsonEncode(expectedSnapshot)) {
          return;
        }
      }
      if (target.action == 'try_now') {
        await _restoreTryNow(profileId, target.titleId, before);
      } else {
        await _restore(profileId, target.titleId, before);
      }
      await db
          .into(db.decisionEvents)
          .insert(
            DecisionEventsCompanion.insert(
              id: randomId(),
              profileId: profileId,
              titleId: target.titleId,
              action: 'undo',
              context: Value(target.context),
              createdAt: _now(),
              reversesEventId: Value(target.id),
            ),
          );
      applied = true;
      undoneEvent = target;
    });
    if (!applied) return null;
    return UndoResult(
      undoneEvent!.titleId,
      Decision.parse(undoneEvent!.action),
      tryNow: undoneEvent!.action == 'try_now',
      eventId: undoneEvent!.id,
    );
  }

  Future<void> _requireProfile(String profileId) async {
    if (!await _profileExists(profileId)) {
      throw const DecisionFailed();
    }
  }

  Future<bool> _profileExists(String profileId) async =>
      await (db.select(
        db.profiles,
      )..where((p) => p.id.equals(profileId))).getSingleOrNull() !=
      null;

  Future<bool> canUndo(String profileId) async =>
      (await _undoTarget(profileId)) != null;

  Future<DecisionEvent?> _undoTarget(String profileId) async {
    final recent =
        await (db.select(db.decisionEvents)
              ..where((e) => e.profileId.equals(profileId))
              ..orderBy([(e) => OrderingTerm.desc(e.createdAt)])
              ..limit(undoDepth * 2))
            .get();
    final reversed = {
      for (final e in recent)
        if (e.reversesEventId != null) e.reversesEventId!,
    };
    var seen = 0;
    for (final e in recent) {
      if (!_decisionCodes.contains(e.action)) continue;
      if (++seen > undoDepth) break;
      if (!reversed.contains(e.id)) return e;
    }
    return null;
  }

  /// Library "Restore": lifts a Not interested or Not now for a title.
  Future<void> restore(String profileId, String titleId) =>
      db.transaction(() async {
        await (db.update(db.exclusions)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .write(const ExclusionsCompanion(active: Value(false)));
        await (db.delete(db.deferrals)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .go();
        await db
            .into(db.decisionEvents)
            .insert(
              DecisionEventsCompanion.insert(
                id: randomId(),
                profileId: profileId,
                titleId: titleId,
                action: 'restore',
                context: const Value('library'),
                createdAt: _now(),
              ),
            );
      });

  Future<_Snapshot> _snapshot(String profileId, String titleId) async {
    final s =
        await (db.select(db.shortlist)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    final d =
        await (db.select(db.deferrals)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    final x =
        await (db.select(db.exclusions)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    final u =
        await (db.select(db.userTitles)..where(
              (x) => x.profileId.equals(profileId) & x.titleId.equals(titleId),
            ))
            .getSingleOrNull();
    final intent = (await _tryNow.allInTransaction(profileId))[titleId];
    return _Snapshot(s, d, x, u, intent);
  }

  Future<void> _restore(String profileId, String titleId, _Snapshot b) async {
    Expression<bool> mine(
      GeneratedColumn<String> p,
      GeneratedColumn<String> t,
    ) => p.equals(profileId) & t.equals(titleId);
    await (db.delete(
      db.shortlist,
    )..where((x) => mine(x.profileId, x.titleId))).go();
    await (db.delete(
      db.deferrals,
    )..where((x) => mine(x.profileId, x.titleId))).go();
    await (db.delete(
      db.exclusions,
    )..where((x) => mine(x.profileId, x.titleId))).go();
    await (db.delete(
      db.userTitles,
    )..where((x) => mine(x.profileId, x.titleId))).go();
    if (b.shortlist != null) await db.into(db.shortlist).insert(b.shortlist!);
    if (b.deferral != null) await db.into(db.deferrals).insert(b.deferral!);
    if (b.exclusion != null) await db.into(db.exclusions).insert(b.exclusion!);
    if (b.userTitle != null) await db.into(db.userTitles).insert(b.userTitle!);
    await _tryNow.setInTransaction(
      profileId,
      titleId,
      b.tryNowIntent?.active ?? false,
      now: _now(),
    );
  }

  Future<void> _restoreTryNow(
    String profileId,
    String titleId,
    _Snapshot before,
  ) async {
    await (db.delete(db.shortlist)..where(
          (s) => s.profileId.equals(profileId) & s.titleId.equals(titleId),
        ))
        .go();
    if (before.shortlist != null) {
      await db.into(db.shortlist).insert(before.shortlist!);
    }
    await _tryNow.setInTransaction(
      profileId,
      titleId,
      before.tryNowIntent?.active ?? false,
      now: _now(),
    );
  }
}

class _Snapshot {
  const _Snapshot(
    this.shortlist,
    this.deferral,
    this.exclusion,
    this.userTitle,
    this.tryNowIntent,
  );

  final ShortlistEntry? shortlist;
  final Deferral? deferral;
  final Exclusion? exclusion;
  final UserTitle? userTitle;
  final TryNowIntent? tryNowIntent;

  Map<String, dynamic> toJson() => {
    'shortlist': shortlist?.toJson(),
    'deferral': deferral?.toJson(),
    'exclusion': exclusion?.toJson(),
    'userTitle': userTitle?.toJson(),
    'tryNowIntent': tryNowIntent == null
        ? null
        : {'titleId': tryNowIntent!.titleId, ...tryNowIntent!.toJson()},
  };

  factory _Snapshot.fromJson(Map<String, dynamic> j) {
    T? read<T>(String k, T Function(Map<String, dynamic>) f) {
      final v = j[k];
      return v == null ? null : f(Map<String, dynamic>.from(v as Map));
    }

    final rawIntent = j['tryNowIntent'];
    final intent = rawIntent is Map
        ? TryNowIntent.fromJson('${rawIntent['titleId'] ?? ''}', rawIntent)
        : null;
    return _Snapshot(
      read('shortlist', ShortlistEntry.fromJson),
      read('deferral', Deferral.fromJson),
      read('exclusion', Exclusion.fromJson),
      read('userTitle', UserTitle.fromJson),
      intent,
    );
  }
}
