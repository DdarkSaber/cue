import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/features/deck/card_signal_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

RankedCard card(
  String id, {
  String reason = 'Fits your taste',
  List<String> becauseOf = const [],
}) => RankedCard(
  Title(id: id, kind: MediaKind.anime, titleEn: 'Invented $id'),
  1,
  reason,
  becauseOf: becauseOf,
);

void main() {
  late DateTime now;
  late CardSignalTracker tracker;
  void wait(Duration d) => now = now.add(d);

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
    tracker = CardSignalTracker(clock: () => now);
  });

  test('dwell is the time between show and finish', () {
    final shown = now;
    tracker.show('p', card('a'));
    wait(const Duration(milliseconds: 4200));
    final s = tracker.finish(
      decision: Decision.willTry,
      decisionEventId: 'e1',
    )!;
    expect(s.profileId, 'p');
    expect(s.titleId, 'a');
    expect(s.shownAt, shown);
    expect(s.dwellMs, 4200);
    expect(s.decision, 'will_try');
    expect(s.decisionEventId, 'e1');
    expect(s.openedDetails, isFalse);
    expect(s.heldPoster, isFalse);
    expect(tracker.titleId, isNull);
    expect(tracker.finish(), isNull);
  });

  test('dwell is capped at five minutes', () {
    tracker.show('p', card('a'));
    wait(const Duration(hours: 2));
    expect(tracker.finish()!.dwellMs, 5 * 60 * 1000);
  });

  test('time in the background does not count', () {
    tracker.show('p', card('a'));
    wait(const Duration(seconds: 3));
    tracker.pause();
    tracker.pause();
    wait(const Duration(minutes: 30));
    tracker.resume();
    tracker.resume();
    wait(const Duration(seconds: 2));
    expect(tracker.finish()!.dwellMs, 5000);
  });

  test('a card finished or shown while paused counts no background time', () {
    tracker.show('p', card('a'));
    wait(const Duration(seconds: 1));
    tracker.pause();
    wait(const Duration(seconds: 50));
    expect(tracker.finish()!.dwellMs, 1000);

    tracker.show('p', card('b'));
    wait(const Duration(seconds: 40));
    tracker.resume();
    wait(const Duration(seconds: 2));
    expect(tracker.finish()!.dwellMs, 2000);
  });

  test('the same title shown again keeps its running dwell', () {
    final shown = now;
    tracker.show('p', card('a'));
    wait(const Duration(seconds: 2));
    tracker.detailsOpened('a');
    tracker.hide();
    wait(const Duration(seconds: 10));
    tracker.show('p', card('a'));
    wait(const Duration(seconds: 3));
    final s = tracker.finish()!;
    expect(s.dwellMs, 5000);
    expect(s.shownAt, shown);
    expect(s.openedDetails, isTrue);
  });

  test('details and poster flags belong to the card on top only', () {
    tracker.show('p', card('a'));
    tracker.detailsOpened('other');
    tracker.posterHeld('other');
    var s = tracker.finish()!;
    expect(s.openedDetails, isFalse);
    expect(s.heldPoster, isFalse);

    tracker.show('p', card('b'));
    tracker.detailsOpened('b');
    tracker.posterHeld('b');
    s = tracker.finish()!;
    expect(s.openedDetails, isTrue);
    expect(s.heldPoster, isTrue);

    // Flags do not leak into the next card.
    tracker.show('p', card('c'));
    s = tracker.finish()!;
    expect(s.openedDetails, isFalse);
    expect(s.heldPoster, isFalse);
  });

  test('slot comes from how the ranker produced the card', () {
    expect(CardSignalTracker.slotOf(card('a')), 'familiar');
    expect(CardSignalTracker.slotOf(card('a', reason: '')), 'familiar');
    expect(
      CardSignalTracker.slotOf(
        card('a', reason: ' Exploring another eligible theme or format.'),
      ),
      'explore',
    );
    expect(
      CardSignalTracker.slotOf(
        card(
          'a',
          reason: ' Exploring another eligible theme or format.',
          becauseOf: const ['seed'],
        ),
      ),
      'seeded',
    );
    tracker.show('p', card('a', becauseOf: const ['seed']));
    expect(tracker.finish()!.slot, 'seeded');
  });

  test('finishing without a decision leaves the decision empty', () {
    tracker.show('p', card('a'));
    wait(const Duration(seconds: 1));
    final s = tracker.finish()!;
    expect(s.decision, isNull);
    expect(s.decisionEventId, isNull);
    expect(s.dwellMs, 1000);
  });

  test('a different title starts from zero', () {
    tracker.show('p', card('a'));
    wait(const Duration(seconds: 9));
    tracker.show('p', card('b'));
    wait(const Duration(seconds: 1));
    final s = tracker.finish()!;
    expect(s.titleId, 'b');
    expect(s.dwellMs, 1000);
  });
}
