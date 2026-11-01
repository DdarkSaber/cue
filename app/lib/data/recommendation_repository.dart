import 'dart:convert';

import 'db/database.dart';

/// Bounded per-library, local-only data. No diagnostics, backup or sync hooks.
class RecommendationRepository {
  RecommendationRepository(this.db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;
  final CueDatabase db;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> read(String id) async {
    final row = await (db.select(
      db.recommendationStates,
    )..where((s) => s.profileId.equals(id))).getSingleOrNull();
    return row == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(row.json) as Map);
  }

  Future<void> _change(String id, void Function(Map<String, dynamic>) update) =>
      db.transaction(() async {
        final profile = await (db.select(
          db.profiles,
        )..where((p) => p.id.equals(id))).getSingleOrNull();
        if (profile == null) throw StateError('library_missing');
        final state = await read(id);
        update(state);
        await db
            .into(db.recommendationStates)
            .insertOnConflictUpdate(
              RecommendationStatesCompanion.insert(
                profileId: id,
                json: jsonEncode(state),
              ),
            );
      });

  Future<Map<String, int>> exposures(String id) async {
    final state = await read(id);
    final now = _now().millisecondsSinceEpoch;
    return {
      for (final e in Map<String, dynamic>.from(
        state['exposures'] as Map? ?? {},
      ).entries)
        if (now - (e.value as int) < const Duration(days: 1).inMilliseconds)
          e.key: e.value as int,
    };
  }

  Future<void> present(
    String id,
    Set<String> titles, {
    required Set<String> kinds,
    required int leaks,
  }) => _change(id, (s) {
    final now = _now().millisecondsSinceEpoch;
    final history = Map<String, dynamic>.from(s['exposures'] as Map? ?? {})
      ..removeWhere(
        (_, v) => now - (v as int) >= const Duration(days: 1).inMilliseconds,
      );
    var repeated = 0;
    for (final t in titles) {
      if (history.containsKey(t)) repeated++;
      history.remove(t);
      history[t] = now;
    }
    while (history.length > 200) {
      history.remove(history.keys.first);
    }
    s['exposures'] = history;
    s['presented'] = (s['presented'] as int? ?? 0) + titles.length;
    s['repeated'] = (s['repeated'] as int? ?? 0) + repeated;
    s['constraintLeaks'] = (s['constraintLeaks'] as int? ?? 0) + leaks;
    s['kinds'] = {
      ...List<String>.from(s['kinds'] as List? ?? []),
      ...kinds,
    }.toList();
  });

  Future<void> decision(String id, {required bool picked, String? eventId}) =>
      _change(id, (s) {
        if (eventId != null) {
          final journal = List<Map<String, dynamic>>.from(
            (s['decisionJournal'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          if (journal.any((e) => e['eventId'] == eventId)) return;
          journal.add({
            'eventId': eventId,
            'choicesSincePick': s['choicesSincePick'] ?? 0,
            'picks': s['picks'] ?? 0,
            'choicesToPick': s['choicesToPick'] ?? 0,
          });
          s['decisionJournal'] = journal
              .skip(journal.length > 40 ? journal.length - 40 : 0)
              .toList();
        }
        s['choicesSincePick'] = (s['choicesSincePick'] as int? ?? 0) + 1;
        if (picked) {
          s['picks'] = (s['picks'] as int? ?? 0) + 1;
          s['choicesToPick'] =
              (s['choicesToPick'] as int? ?? 0) +
              (s['choicesSincePick'] as int);
          s['choicesSincePick'] = 0;
        }
      });

  Future<void> undoDecision(String id, String eventId) => _change(id, (s) {
    final journal = List<Map<String, dynamic>>.from(
      (s['decisionJournal'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    if (journal.isEmpty || journal.last['eventId'] != eventId) return;
    final before = journal.removeLast();
    for (final key in ['choicesSincePick', 'picks', 'choicesToPick']) {
      s[key] = before[key];
    }
    s['decisionJournal'] = journal;
  });

  Future<bool> dismissed(String id, String titleId) async =>
      List<String>.from((await read(id))['dismissed'] as List? ?? [])
          .contains(titleId);

  Future<void> dismiss(String id, String titleId, {bool? enjoyed}) =>
      _change(id, (s) {
        final ids = List<String>.from(s['dismissed'] as List? ?? [])
          ..remove(titleId)
          ..add(titleId);
        s['dismissed'] = ids
            .skip(ids.length > 200 ? ids.length - 200 : 0)
            .toList();
        if (enjoyed != null) {
          s['followupAnswers'] = (s['followupAnswers'] as int? ?? 0) + 1;
          s['enjoyed'] = (s['enjoyed'] as int? ?? 0) + (enjoyed ? 1 : 0);
        }
      });

  Future<void> clear(String id) async => (db.delete(
    db.recommendationStates,
  )..where((s) => s.profileId.equals(id))).go();

  Future<void> clearMeasures(String id) => _change(id, (s) {
    final dismissed = s['dismissed'];
    s.clear();
    if (dismissed != null) s['dismissed'] = dismissed;
  });
}
