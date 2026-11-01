import 'package:drift/drift.dart';

import '../domain/models/library.dart';
import '../domain/models/title.dart';
import 'db/database.dart';
import 'library_repository.dart';
import 'recommendation_repository.dart';
import 'try_now_repository.dart';

enum FollowUpAnswer { loved, enjoyed, notForMe, haventStarted }

class RatingCandidate {
  const RatingCandidate(
    this.title,
    this.before, {
    this.removedAt,
    this.shortlist,
  });
  final Title title;
  final UserTitle? before;
  final DateTime? removedAt;
  final ShortlistEntry? shortlist;
}

class RatingUndo {
  RatingUndo._(
    this.owner,
    this.profileId,
    this.before,
    this.after,
    this.shortlistBefore,
    this.decisionsBefore,
    this.priorityBefore,
    this.priorityAfter,
  );
  final LibraryRatingService owner;
  final String profileId;
  final UserTitle? before;
  final UserTitle after;
  final ShortlistEntry? shortlistBefore;
  final List<DecisionEvent>? decisionsBefore;
  final TryNowIntent? priorityBefore;
  final TryNowIntent? priorityAfter;
  bool _used = false;
}

class RatingConflict implements Exception {
  const RatingConflict();
}

/// Rating-only edits: status, import provenance and progress are never inferred.
class LibraryRatingService {
  LibraryRatingService(
    this.db,
    this.library,
    this.recommendations, {
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final CueDatabase db;
  final LibraryRepository library;
  final RecommendationRepository recommendations;
  final DateTime Function() _now;

  Future<UserTitle?> _row(String profileId, String titleId) =>
      (db.select(db.userTitles)..where(
            (u) => u.profileId.equals(profileId) & u.titleId.equals(titleId),
          ))
          .getSingleOrNull();

  Future<ShortlistEntry?> _shortlist(String profileId, String titleId) =>
      (db.select(db.shortlist)..where(
            (s) => s.profileId.equals(profileId) & s.titleId.equals(titleId),
          ))
          .getSingleOrNull();

  Future<List<DecisionEvent>> _decisions(String profileId, String titleId) =>
      (db.select(db.decisionEvents)
            ..where(
              (e) => e.profileId.equals(profileId) & e.titleId.equals(titleId),
            )
            ..orderBy([(e) => OrderingTerm.asc(e.id)]))
          .get();

  Future<List<RatingCandidate>> candidates(
    String profileId, {
    bool followUp = false,
    bool includeDismissed = false,
    bool includeRated = false,
  }) => db.transaction(() async {
    final rows = await (db.select(
      db.userTitles,
    )..where((u) => u.profileId.equals(profileId))).get();
    final entries = {for (final row in rows) row.titleId: row};
    final shortlisted = await (db.select(
      db.shortlist,
    )..where((s) => s.profileId.equals(profileId))).get();
    final shortlist = {for (final row in shortlisted) row.titleId: row};
    final Set<String> ids;
    if (followUp) {
      final cutoff = _now().subtract(const Duration(days: 7));
      final dismissed = List<String>.from(
        (await recommendations.read(profileId))['dismissed'] as List? ?? [],
      ).toSet();
      ids = {
        for (final s in shortlisted)
          if (s.addedAt.isBefore(cutoff) &&
              (includeRated || entries[s.titleId]?.rating == null) &&
              (includeDismissed || !dismissed.contains(s.titleId)))
            s.titleId,
      };
    } else {
      ids = {
        for (final row in rows)
          if ((includeRated || row.rating == null) &&
              LibraryState.parse(row.state).isSeen)
            row.titleId,
      };
    }
    final titles = await (db.select(
      db.catalogTitles,
    )..where((t) => t.id.isIn(ids.toList()))).get();
    final removals = await library.removals(profileId);
    return [
      for (final title in titles)
        RatingCandidate(
          Title.fromRow(title),
          entries[title.id],
          removedAt: removals[title.id],
          shortlist: shortlist[title.id],
        ),
    ];
  });

  // Drift's default timestamp storage has second precision. Always advance
  // a whole second so same-second sync edits and undo cannot compare equal.
  DateTime _editTime(DateTime? previous, DateTime? removed) {
    var now = DateTime.fromMillisecondsSinceEpoch(
      (_now().millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    for (final at in [previous, removed]) {
      if (at != null && !now.isAfter(at)) {
        now = DateTime.fromMillisecondsSinceEpoch(
          (at.millisecondsSinceEpoch ~/ 1000 + 1) * 1000,
          isUtc: true,
        );
      }
    }
    return now;
  }

  Future<RatingUndo> rate(
    String profileId,
    RatingCandidate candidate,
    Rating rating, {
    bool overwrite = false,
    bool followUp = false,
  }) => db.transaction(() async {
    final before = await _row(profileId, candidate.title.id);
    final shortlistBefore = followUp
        ? await _shortlist(profileId, candidate.title.id)
        : null;
    final decisionsBefore = followUp
        ? await _decisions(profileId, candidate.title.id)
        : null;
    final priority = TryNowRepository(db, clock: _now);
    final priorityBefore = followUp
        ? (await priority.allInTransaction(profileId))[candidate.title.id]
        : null;
    if (before != candidate.before ||
        (before?.rating != null && !overwrite) ||
        (!followUp &&
            (before == null || !LibraryState.parse(before.state).isSeen))) {
      throw const RatingConflict();
    }
    if (followUp &&
        !(await candidates(
          profileId,
          followUp: true,
          includeDismissed: true,
          includeRated: overwrite,
        )).any((c) => c.title.id == candidate.title.id)) {
      throw const RatingConflict();
    }
    if (followUp && shortlistBefore != candidate.shortlist) {
      throw const RatingConflict();
    }
    final removed = await library.removedAt(profileId, candidate.title.id);
    if (removed != candidate.removedAt) throw const RatingConflict();
    final updatedAt = _editTime(before?.updatedAt, removed);
    await library.clearRemoval(profileId, candidate.title.id);
    if (before == null) {
      await db
          .into(db.userTitles)
          .insert(
            UserTitlesCompanion.insert(
              profileId: profileId,
              titleId: candidate.title.id,
              rating: Value(rating.code),
              updatedAt: updatedAt,
            ),
          );
    } else {
      await (db.update(db.userTitles)..where(
            (u) =>
                u.profileId.equals(profileId) &
                u.titleId.equals(candidate.title.id),
          ))
          .write(
            UserTitlesCompanion(
              rating: Value(rating.code),
              updatedAt: Value(updatedAt),
            ),
          );
    }
    if (followUp) {
      await library.removeFromShortlist(profileId, candidate.title.id);
      await priority.clearTitle(profileId, candidate.title.id);
    }
    await library.recomputeWeights(profileId);
    return RatingUndo._(
      this,
      profileId,
      before,
      (await _row(profileId, candidate.title.id))!,
      shortlistBefore,
      decisionsBefore,
      priorityBefore,
      followUp
          ? (await priority.allInTransaction(profileId))[candidate.title.id]
          : null,
    );
  });

  Future<RatingUndo?> answer(
    String profileId,
    RatingCandidate candidate,
    FollowUpAnswer answer, {
    bool overwrite = false,
  }) => db.transaction(() async {
    if (answer == FollowUpAnswer.haventStarted) {
      await dismiss(profileId, candidate.title.id);
      return null;
    }
    final rating = switch (answer) {
      FollowUpAnswer.loved => Rating.favourite,
      FollowUpAnswer.enjoyed => Rating.enjoyed,
      FollowUpAnswer.notForMe => Rating.dropped,
      FollowUpAnswer.haventStarted => throw StateError('Unreachable'),
    };
    final undo = await rate(
      profileId,
      candidate,
      rating,
      overwrite: overwrite,
      followUp: true,
    );
    await recommendations.dismiss(
      profileId,
      candidate.title.id,
      enjoyed: answer != FollowUpAnswer.notForMe,
    );
    return undo;
  });

  /// Skip is session-local in the cards; only a follow-up dismissal is persisted.
  Future<void> dismiss(String profileId, String titleId) =>
      recommendations.dismiss(profileId, titleId);

  Future<bool> undo(String profileId, RatingUndo token) => db.transaction(
    () async {
      if (token.owner != this || token._used || token.profileId != profileId) {
        return false;
      }
      final current = await _row(profileId, token.after.titleId);
      final priority = TryNowRepository(db, clock: _now);
      if (token.decisionsBefore != null) {
        final currentPriority = (await priority.allInTransaction(
          profileId,
        ))[token.after.titleId];
        if (currentPriority?.active != token.priorityAfter?.active ||
            currentPriority?.updatedAt != token.priorityAfter?.updatedAt) {
          return false;
        }
      }
      final decisions = token.decisionsBefore == null
          ? null
          : await _decisions(profileId, token.after.titleId);
      if (decisions != null &&
          (decisions.length != token.decisionsBefore!.length ||
              Iterable<int>.generate(decisions.length)
                  .any((i) => decisions[i] != token.decisionsBefore![i]))) {
        return false;
      }
      if (current != token.after ||
          await library.removedAt(profileId, token.after.titleId) != null ||
          (token.shortlistBefore != null &&
              await _shortlist(profileId, token.after.titleId) != null)) {
        return false;
      }
      final at = _editTime(current!.updatedAt, null);
      if (token.before == null) {
        await library.recordRemoval(profileId, current.titleId, at);
        await (db.delete(db.userTitles)..where(
              (u) =>
                  u.profileId.equals(profileId) &
                  u.titleId.equals(current.titleId),
            ))
            .go();
      } else {
        await db
            .into(db.userTitles)
            .insertOnConflictUpdate(
              token.before!.copyWith(updatedAt: at).toCompanion(false),
            );
      }
      if (token.shortlistBefore != null) {
        await db
            .into(db.shortlist)
            .insert(token.shortlistBefore!.toCompanion(false));
        if (token.priorityBefore?.active ?? false) {
          await priority.setInTransaction(
            profileId,
            current.titleId,
            true,
            now: at,
          );
        }
      }
      await library.recomputeWeights(profileId);
      token._used = true;
      return true;
    },
  );
}
