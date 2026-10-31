import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/decision.dart';
import '../domain/mood/mode_model.dart';
import '../domain/mood/mood_engine.dart';
import '../domain/mood/sessions.dart';
import '../domain/mood/word_model.dart';
import 'db/database.dart';
import 'profile_repository.dart' show randomId;

/// Stores what the mood learner knows, on this device only.
class MoodRepository implements MoodStore {
  MoodRepository(this.db);
  final CueDatabase db;

  @override
  Future<(List<Mode>, WordModel)?> load(String profileId) async {
    final row = await (db.select(
      db.moodStates,
    )..where((s) => s.profileId.equals(profileId))).getSingleOrNull();
    if (row == null) return null;
    final modes = [
      for (final m in jsonDecode(row.modesJson) as List)
        Mode.fromJson(Map<String, Object?>.from(m as Map)),
    ];
    final words = WordModel({
      for (final e in (jsonDecode(row.wordsJson) as Map).entries)
        '${e.key}': WordEntry({
          for (final w in ((e.value as Map)['w'] as Map).entries)
            '${w.key}': (w.value as num).toDouble(),
        }, ((e.value as Map)['u'] as num).toInt()),
    });
    return (modes, words);
  }

  @override
  Future<void> save(String profileId, List<Mode> modes, WordModel words) => db
      .into(db.moodStates)
      .insertOnConflictUpdate(
        MoodStatesCompanion.insert(
          profileId: profileId,
          modesJson: Value(jsonEncode([for (final m in modes) m.toJson()])),
          wordsJson: Value(
            jsonEncode({
              for (final e in words.words.entries)
                e.key: {'w': e.value.weights, 'u': e.value.uses},
            }),
          ),
          updatedAt: DateTime.now(),
        ),
      );

  @override
  Future<void> sessionEnded(
    String profileId,
    MoodSession session, {
    String? typed,
    String? modeId,
  }) => db
      .into(db.moodSessions)
      .insert(
        MoodSessionsCompanion.insert(
          id: randomId(12),
          profileId: profileId,
          startedAt: session.start,
          endedAt: session.end,
          typed: Value(typed),
          modeId: Value(modeId),
          positives: session.positives,
          negatives: session.negatives,
        ),
      );

  /// The swipe history the modes are learned from, oldest first.
  @override
  Future<List<MoodEvent>> events(String profileId) async {
    final rows =
        await (db.select(db.decisionEvents)
              ..where((e) => e.profileId.equals(profileId))
              ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
            .get();
    return [
      for (final r in rows)
        // Undo rows only matter for what they cancel.
        if (r.reversesEventId != null || Decision.parse(r.action) != null)
          MoodEvent(
            id: r.id,
            titleId: r.titleId,
            decision: Decision.parse(r.action) ?? Decision.notNow,
            at: r.createdAt,
            reverses: r.reversesEventId,
          ),
    ];
  }

  /// "Clear mood learning" in Privacy.
  Future<void> clear(String profileId) async {
    await (db.delete(
      db.moodStates,
    )..where((s) => s.profileId.equals(profileId))).go();
    await (db.delete(
      db.moodSessions,
    )..where((s) => s.profileId.equals(profileId))).go();
  }
}
