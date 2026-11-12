import 'package:drift/drift.dart';

import '../domain/learning/replay.dart';
import '../domain/models/title.dart';
import 'catalog_repository.dart';
import 'db/database.dart';

/// How a run of deck cards was answered.
class OutcomeStats {
  const OutcomeStats({
    this.saved = 0,
    this.notInterested = 0,
    this.watched = 0,
    this.notNow = 0,
    this.byKind = const {},
  });

  /// Will try plus Try now.
  final int saved;
  final int notInterested;

  /// Watched or read.
  final int watched;
  final int notNow;

  /// Saved and rejected (Not interested) per format.
  final Map<MediaKind, ({int saved, int rejected})> byKind;

  /// Cards with a lasting answer; Not now only postpones.
  int get decided => saved + notInterested + watched;

  /// Saved out of saved plus Not interested; 0 when there are none.
  double get saveRate =>
      saved + notInterested == 0 ? 0 : saved / (saved + notInterested);
}

/// Reads how recommendations landed from `decision_events`. Read only.
class OutcomeStatsRepository {
  OutcomeStatsRepository(this.db, this.catalog, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final CatalogRepository catalog;
  final DateTime Function() _now;

  static const _saved = ['will_try', 'try_now'];
  static const _watched = ['watched', 'read'];
  static const _counted = [..._saved, ..._watched, 'not_interested', 'not_now'];

  /// Deck decisions that still stand: an undo is its own row pointing at the
  /// decision it reversed through `reverses_event_id`, so both that row (its
  /// action is 'undo') and the decision it points at are left out.
  Expression<bool> _standing($DecisionEventsTable e, String profileId) {
    final undo = db.alias(db.decisionEvents, 'undo');
    return e.profileId.equals(profileId) &
        e.context.equals('deck') &
        e.action.isIn(_counted) &
        e.id.isNotInQuery(
          db.selectOnly(undo)
            ..addColumns([undo.reversesEventId])
            ..where(
              undo.profileId.equals(profileId) &
                  undo.reversesEventId.isNotNull(),
            ),
        );
  }

  /// Newest first; decisions stored in the same second keep insert order.
  static List<OrderingTerm> _newestFirst($DecisionEventsTable e) => [
    OrderingTerm.desc(e.createdAt),
    OrderingTerm.desc(e.rowId),
  ];

  /// Deck decisions only (context 'deck'), undone events excluded; the newest
  /// [last] decisions after skipping [skip], or since [since]. Every kind of
  /// decision, Not now included, takes one of the [last] places.
  Future<OutcomeStats> stats(
    String profileId, {
    int? last,
    int skip = 0,
    DateTime? since,
  }) async {
    final e = db.decisionEvents;
    final t = db.catalogTitles;
    var where = _standing(e, profileId);
    if (since != null) {
      where = where & e.createdAt.isBiggerOrEqualValue(since);
    }
    final q =
        db.selectOnly(e).join([leftOuterJoin(t, t.id.equalsExp(e.titleId))])
          ..addColumns([e.action, t.mediaKind])
          ..where(where)
          ..orderBy(_newestFirst(e));
    if (last != null || skip > 0) {
      // SQLite reads a negative limit as "no limit".
      q.limit(last ?? -1, offset: skip);
    }

    var saved = 0;
    var notInterested = 0;
    var watched = 0;
    var notNow = 0;
    final byKind = <MediaKind, ({int saved, int rejected})>{};
    for (final row in await q.get()) {
      final action = row.read(e.action)!;
      final kind = MediaKind.parse(row.read(t.mediaKind));
      final was = byKind[kind] ?? (saved: 0, rejected: 0);
      if (_saved.contains(action)) {
        saved++;
        byKind[kind] = (saved: was.saved + 1, rejected: was.rejected);
      } else if (action == 'not_interested') {
        notInterested++;
        byKind[kind] = (saved: was.saved, rejected: was.rejected + 1);
      } else if (_watched.contains(action)) {
        watched++;
      } else {
        notNow++;
      }
    }
    return OutcomeStats(
      saved: saved,
      notInterested: notInterested,
      watched: watched,
      notNow: notNow,
      byKind: byKind,
    );
  }

  /// Saved/rejected per local day for the last [days] days, today included
  /// (days without decisions omitted), oldest first.
  Future<List<({DateTime day, int saved, int rejected})>> daily(
    String profileId, {
    int days = 14,
  }) async {
    final now = _now();
    final from = DateTime(now.year, now.month, now.day - (days - 1));
    final e = db.decisionEvents;
    final q = db.selectOnly(e)
      ..addColumns([e.action, e.createdAt])
      ..where(
        _standing(e, profileId) &
            e.action.isIn(const [..._saved, 'not_interested']) &
            e.createdAt.isBiggerOrEqualValue(from),
      );
    final byDay = <DateTime, ({int saved, int rejected})>{};
    for (final row in await q.get()) {
      final at = row.read(e.createdAt)!.toLocal();
      final day = DateTime(at.year, at.month, at.day);
      final was = byDay[day] ?? (saved: 0, rejected: 0);
      byDay[day] = _saved.contains(row.read(e.action))
          ? (saved: was.saved + 1, rejected: was.rejected)
          : (saved: was.saved, rejected: was.rejected + 1);
    }
    final sorted = byDay.keys.toList()..sort();
    return [
      for (final day in sorted)
        (day: day, saved: byDay[day]!.saved, rejected: byDay[day]!.rejected),
    ];
  }

  /// The newest [limit] deck decisions as [ReplayEvent]s, oldest first,
  /// undone excluded. Decisions whose title is no longer cached are left out.
  ///
  /// will_try/try_now: label 1 weight 1; not_interested: 0, weight 1;
  /// watched/read: 1, weight 0.5; not_now: 0, weight 0.25.
  Future<List<ReplayEvent>> replayEvents(
    String profileId, {
    int limit = 2000,
  }) async {
    final rows =
        await (db.select(db.decisionEvents)
              ..where((e) => _standing(e, profileId))
              ..orderBy([
                (e) => OrderingTerm.desc(e.createdAt),
                (e) => OrderingTerm.desc(e.rowId),
              ])
              ..limit(limit))
            .get();
    final ids = {for (final r in rows) r.titleId}.toList();
    final titles = <String, Title>{};
    // Batches stay well under SQLite's bound-variable cap.
    for (var i = 0; i < ids.length; i += 500) {
      final batch = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      for (final title in await catalog.titlesByIds(batch)) {
        titles[title.id] = title;
      }
    }
    return [
      for (final r in rows.reversed)
        if (titles[r.titleId] case final title?)
          switch (r.action) {
            'will_try' || 'try_now' => ReplayEvent(title, 1, at: r.createdAt),
            'not_interested' => ReplayEvent(title, 0, at: r.createdAt),
            'watched' ||
            'read' => ReplayEvent(title, 1, weight: 0.5, at: r.createdAt),
            _ => ReplayEvent(title, 0, weight: 0.25, at: r.createdAt),
          },
    ];
  }
}
