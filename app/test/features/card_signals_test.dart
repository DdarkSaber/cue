import 'package:cue/data/db/database.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle, waitForDecisions;

String topId(WidgetTester t) =>
    t.widget<SwipeDeck>(find.byType(SwipeDeck)).cards.first.title.id;

/// Signal rows are written off the gesture path; give them a moment.
Future<List<CardSignalRow>> signals(
  WidgetTester t,
  CueDatabase db, {
  int atLeast = 0,
}) async {
  var rows = const <CardSignalRow>[];
  for (var i = 0; i < 50; i++) {
    rows = (await t.runAsync(() => db.select(db.cardSignals).get()))!;
    if (rows.length >= atLeast) break;
    await t.pump(const Duration(milliseconds: 20));
  }
  return rows;
}

void main() {
  testWidgets('swiping a card stores one signal with its decision', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db);
    await settle(t);
    final first = topId(t);
    expect(await signals(t, db), isEmpty);

    await t.drag(find.byType(SwipeDeck), const Offset(300, 0));
    await waitForDecisions(t, 1);

    final event = (await db.select(db.decisionEvents).get()).single;
    final row = (await signals(t, db, atLeast: 1)).single;
    expect(row.titleId, first);
    expect(row.profileId, event.profileId);
    expect(row.decision, Decision.willTry.code);
    expect(row.decisionEventId, event.id);
    expect(row.openedDetails, isFalse);
    expect(row.heldPoster, isFalse);
    expect(row.slot, isIn(['familiar', 'explore', 'seeded']));
    expect(row.dwellMs, inInclusiveRange(0, 5 * 60 * 1000));
  });

  testWidgets('opening details before deciding is remembered', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db);
    await settle(t);
    final first = topId(t);

    await t.tap(find.byKey(ValueKey('top-$first')));
    await settle(t);
    expect(find.byTooltip('Close'), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await settle(t);
    expect(await signals(t, db), isEmpty);

    await t.tap(find.text('Not now'));
    await waitForDecisions(t, 1);
    final row = (await signals(t, db, atLeast: 1)).single;
    expect(row.titleId, first);
    expect(row.openedDetails, isTrue);
    expect(row.decision, Decision.notNow.code);

    // The next card starts clean.
    await t.tap(find.text('Not now'));
    await waitForDecisions(t, 2);
    final rows = await signals(t, db, atLeast: 2);
    expect(rows, hasLength(2));
    expect(rows.singleWhere((r) => r.titleId != first).openedDetails, isFalse);
  });

  testWidgets('holding the poster before deciding is remembered', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db);
    await settle(t);
    final first = topId(t);

    final gesture = await t.startGesture(
      t.getCenter(find.byKey(ValueKey('top-$first'))),
    );
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await settle(t);

    await t.tap(find.text('Will try').first);
    await waitForDecisions(t, 1);
    final row = (await signals(t, db, atLeast: 1)).single;
    expect(row.titleId, first);
    expect(row.heldPoster, isTrue);
    expect(row.openedDetails, isFalse);
  });

  testWidgets('undo clears the decision so it does not teach', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db);
    await settle(t);
    final first = topId(t);

    await t.tap(find.text('Not now'));
    await waitForDecisions(t, 1);
    expect(
      (await signals(t, db, atLeast: 1)).single.decision,
      Decision.notNow.code,
    );

    await t.tap(find.byTooltip('Undo last swipe'));
    await settle(t);
    expect(topId(t), first);
    final undone = (await signals(
      t,
      db,
      atLeast: 1,
    )).singleWhere((r) => r.titleId == first);
    expect(undone.decision, isNull);
    expect(undone.decisionEventId, isNull);
  });
}
