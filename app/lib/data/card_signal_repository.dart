import 'package:drift/drift.dart';

import 'db/database.dart';
import 'profile_repository.dart' show randomId;

/// How one card on the main deck was looked at. Kept on this device only.
class CardSignal {
  const CardSignal({
    this.id,
    required this.profileId,
    required this.titleId,
    required this.shownAt,
    required this.dwellMs,
    this.openedDetails = false,
    this.heldPoster = false,
    this.slot = '',
    this.decision,
    this.decisionEventId,
  });

  /// Row id; null until stored.
  final String? id;
  final String profileId;
  final String titleId;
  final DateTime shownAt;

  /// Time on top in milliseconds, without time the app was in the background.
  final int dwellMs;
  final bool openedDetails;
  final bool heldPoster;

  /// '', 'familiar', 'explore' or 'seeded'.
  final String slot;

  /// The decision code; null when the card left the top undecided or the
  /// decision was undone.
  final String? decision;
  final String? decisionEventId;

  CardSignal withDecision(String? decision, String? decisionEventId) =>
      CardSignal(
        id: id,
        profileId: profileId,
        titleId: titleId,
        shownAt: shownAt,
        dwellMs: dwellMs,
        openedDetails: openedDetails,
        heldPoster: heldPoster,
        slot: slot,
        decision: decision,
        decisionEventId: decisionEventId,
      );
}

/// Local store of card signals. Not part of backup, export or sync.
class CardSignalRepository {
  CardSignalRepository(this.db);

  final CueDatabase db;

  Future<void> record(CardSignal s) async {
    await db
        .into(db.cardSignals)
        .insert(
          CardSignalsCompanion.insert(
            id: s.id ?? randomId(),
            profileId: s.profileId,
            titleId: s.titleId,
            shownAt: s.shownAt,
            dwellMs: s.dwellMs,
            openedDetails: Value(s.openedDetails),
            heldPoster: Value(s.heldPoster),
            slot: Value(s.slot),
            decision: Value(s.decision),
            decisionEventId: Value(s.decisionEventId),
          ),
        );
  }

  /// The newest [limit] signals of a profile, oldest first.
  Future<List<CardSignal>> recent(String profileId, {int limit = 2000}) async {
    final rows =
        await (db.select(db.cardSignals)
              ..where((t) => t.profileId.equals(profileId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.shownAt),
                (t) => OrderingTerm.desc(t.rowId),
              ])
              ..limit(limit))
            .get();
    return [
      for (final r in rows.reversed)
        CardSignal(
          id: r.id,
          profileId: r.profileId,
          titleId: r.titleId,
          shownAt: r.shownAt,
          dwellMs: r.dwellMs,
          openedDetails: r.openedDetails,
          heldPoster: r.heldPoster,
          slot: r.slot,
          decision: r.decision,
          decisionEventId: r.decisionEventId,
        ),
    ];
  }

  /// An undone swipe keeps its row but no longer counts as a decision.
  Future<void> clearDecision(String decisionEventId) async {
    await (db.update(
      db.cardSignals,
    )..where((t) => t.decisionEventId.equals(decisionEventId))).write(
      const CardSignalsCompanion(
        decision: Value(null),
        decisionEventId: Value(null),
      ),
    );
  }

  /// Deletes the oldest rows of a profile beyond the newest [keep]. Returns
  /// how many were deleted.
  Future<int> prune(String profileId, {int keep = 5000}) => db.customUpdate(
    'DELETE FROM card_signals WHERE profile_id = ?1 AND rowid NOT IN ('
    'SELECT rowid FROM card_signals WHERE profile_id = ?1 '
    'ORDER BY shown_at DESC, rowid DESC LIMIT ?2)',
    variables: [Variable.withString(profileId), Variable.withInt(keep)],
    updates: {db.cardSignals},
    updateKind: UpdateKind.delete,
  );
}
