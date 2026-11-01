import 'package:cue/data/profile_repository.dart';
import 'package:cue/data/recommendation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'choice measures deduplicate event IDs and Undo restores counters',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final id = (await ProfileRepository(db).ensureActive()).id;
      final repo = RecommendationRepository(db);
      await repo.decision(id, picked: false, eventId: 'skip');
      await repo.decision(id, picked: true, eventId: 'try');
      await repo.decision(id, picked: true, eventId: 'try');
      expect((await repo.read(id))['picks'], 1);
      expect((await repo.read(id))['choicesToPick'], 2);
      await repo.undoDecision(id, 'try');
      final state = await repo.read(id);
      expect(state['picks'], 0);
      expect(state['choicesSincePick'], 1);
      expect(state['choicesToPick'], 0);
      await repo.undoDecision(id, 'skip');
      expect((await repo.read(id))['choicesSincePick'], 0);
    },
  );
  test(
    'local measures are bounded, scoped, expiring and deletion-safe',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final profiles = ProfileRepository(db);
      final a = (await profiles.ensureActive()).id;
      final b = (await profiles.create(displayName: 'Other')).id;
      var now = DateTime(2026, 1, 1);
      final repo = RecommendationRepository(db, clock: () => now);
      for (var i = 0; i < 205; i++) {
        await repo.present(a, {'synthetic:$i'}, kinds: {'anime'}, leaks: 0);
      }
      expect((await repo.exposures(a)).length, 200);
      await repo.present(a, {'synthetic:204'}, kinds: {'anime'}, leaks: 0);
      await repo.decision(a, picked: false);
      await repo.decision(a, picked: true);
      await repo.dismiss(a, 'synthetic:204', enjoyed: true);
      final state = await repo.read(a);
      expect(state['repeated'], 1);
      expect(state['choicesToPick'], 2);
      expect(state['picks'], 1);
      expect(state['enjoyed'], 1);
      expect(state['constraintLeaks'], 0);
      expect(await repo.read(b), isEmpty);
      now = now.add(const Duration(days: 1));
      expect(await repo.exposures(a), isEmpty);
      await repo.clearMeasures(a);
      expect(await repo.dismissed(a, 'synthetic:204'), isTrue);
      expect((await repo.read(a))['picks'], isNull);
      await profiles.deleteProfile(a);
      expect(await repo.read(a), isEmpty);
      expect(await repo.read(b), isEmpty);
    },
  );
}
