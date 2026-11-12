import 'package:cue/data/card_signal_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late CueDatabase db;
  late CardSignalRepository repo;
  late String profileId;

  setUp(() async {
    db = memoryDb();
    repo = CardSignalRepository(db);
    profileId = (await ProfileRepository(db).ensureActive()).id;
  });
  tearDown(() => db.close());

  CardSignal signal(int minute, {String? decision, String? eventId}) =>
      CardSignal(
        profileId: profileId,
        titleId: 't$minute',
        shownAt: DateTime.utc(2026, 1, 1, 12, minute),
        dwellMs: minute * 100,
        openedDetails: minute.isEven,
        heldPoster: minute.isOdd,
        slot: 'explore',
        decision: decision,
        decisionEventId: eventId,
      );

  test('record stores every field and recent is oldest first', () async {
    await repo.record(signal(3, decision: 'will_try', eventId: 'e3'));
    await repo.record(signal(1));
    await repo.record(signal(2, decision: 'not_now', eventId: 'e2'));

    final all = await repo.recent(profileId);
    expect(all.map((s) => s.titleId), ['t1', 't2', 't3']);
    final last = all.last;
    expect(last.id, isNotEmpty);
    expect(last.profileId, profileId);
    expect(last.shownAt.toUtc(), DateTime.utc(2026, 1, 1, 12, 3));
    expect(last.dwellMs, 300);
    expect(last.openedDetails, isFalse);
    expect(last.heldPoster, isTrue);
    expect(last.slot, 'explore');
    expect(last.decision, 'will_try');
    expect(last.decisionEventId, 'e3');
    expect(all.first.decision, isNull);

    // The limit keeps the newest rows, still oldest first.
    final two = await repo.recent(profileId, limit: 2);
    expect(two.map((s) => s.titleId), ['t2', 't3']);
    expect(await repo.recent('someone-else'), isEmpty);
  });

  test('clearDecision empties only the undone swipe', () async {
    await repo.record(signal(1, decision: 'will_try', eventId: 'e1'));
    await repo.record(signal(2, decision: 'not_now', eventId: 'e2'));
    await repo.clearDecision('e1');

    final all = await repo.recent(profileId);
    expect(all[0].decision, isNull);
    expect(all[0].decisionEventId, isNull);
    expect(all[0].dwellMs, 100);
    expect(all[1].decision, 'not_now');
    expect(all[1].decisionEventId, 'e2');
  });

  test('prune deletes the oldest rows beyond keep', () async {
    for (var i = 0; i < 10; i++) {
      await repo.record(signal(i));
    }
    expect(await repo.prune(profileId), 0);
    expect(await repo.prune(profileId, keep: 4), 6);
    final left = await repo.recent(profileId);
    expect(left.map((s) => s.titleId), ['t6', 't7', 't8', 't9']);
    expect(await repo.prune(profileId, keep: 4), 0);
  });
}
