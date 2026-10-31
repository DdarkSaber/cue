import 'package:cue/app/providers.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

/// Visible title of the top card.
String topTitle(WidgetTester t) {
  final deck = t.widget<SwipeDeck>(find.byType(SwipeDeck));
  return deck.cards.first.title.displayTitle;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

void main() {
  testWidgets('first open deals a real card from the catalog', (t) async {
    await pumpCue(t);
    await settle(t);
    expect(find.byType(SwipeDeck), findsOneWidget);
    expect(topTitle(t), isNotEmpty);
    expect(find.text('Will try'), findsWidgets);
  });

  testWidgets('a button decision moves to the next card and can be undone', (
    t,
  ) async {
    await pumpCue(t);
    await settle(t);
    final first = topTitle(t);
    await t.tap(find.text('Not now'));
    await settle(t);
    expect(topTitle(t), isNot(first));
    expect(find.text('Hidden for 14 days'), findsOneWidget);

    await t.tap(find.byTooltip('Undo last swipe'));
    await settle(t);
    expect(topTitle(t), first);
  });

  testWidgets('arrow keys follow the swipe map', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, size: desktop, db: db);
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(t);
    final events = await db.select(db.decisionEvents).get();
    expect(events.single.action, Decision.willTry.code);
  });

  testWidgets('a remapped swipe makes the remapped decision', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, size: desktop, db: db);
    await settle(t);
    final scope = ProviderScope.containerOf(t.element(find.byType(SwipeDeck)));
    await scope
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(swipeMap: s.swipeMap.mirrored));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(t);
    final events = await db.select(db.decisionEvents).get();
    expect(events.single.action, Decision.notInterested.code);
  });

  testWidgets(
    'a drag past the commit distance decides; a short one springs back',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      await pumpCue(t, db: db);
      await settle(t);
      final card = find.byType(SwipeDeck);
      final first = topTitle(t);

      await t.drag(card, const Offset(40, 0));
      await settle(t);
      expect(topTitle(t), first);
      expect(await db.select(db.decisionEvents).get(), isEmpty);

      await t.drag(card, const Offset(0, -200));
      await settle(t);
      expect(topTitle(t), isNot(first));
      final events = await db.select(db.decisionEvents).get();
      // Up is Watched, stored as "read" for reading titles.
      expect(events.single.action, anyOf(Decision.watched.code, 'read'));
    },
  );

  testWidgets('decisions persist across a restart', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db);
    await settle(t);
    for (final label in [
      'Will try',
      'Not now',
      'Watched|Read it',
      'Not interested',
    ]) {
      await t.tap(find.textContaining(RegExp('^($label)\$')).first);
      await settle(t);
    }
    // Rebuild the whole app on the same database.
    await t.pumpWidget(const SizedBox());
    await pumpCue(t, db: db);
    await settle(t);
    final events = await db.select(db.decisionEvents).get();
    expect(events.length, 4);
    expect(find.byTooltip('Undo last swipe'), findsOneWidget);
  });

  testWidgets('offline with an empty cache explains instead of a blank', (
    t,
  ) async {
    await pumpCue(t, gateway: FakeGateway(offline: true));
    await settle(t);
    expect(find.textContaining('No stories cached yet'), findsOneWidget);
  });

  testWidgets('offline after a first run still deals from the cache', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db);
    await settle(t);
    await t.pumpWidget(const SizedBox());
    await pumpCue(t, db: db, gateway: FakeGateway(offline: true));
    await settle(t);
    expect(find.byType(SwipeDeck), findsOneWidget);
  });

  testWidgets('reduced motion still decides (cross-fade, no fly-out)', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db, disableAnimations: true);
    await settle(t);
    await t.tap(find.text('Will try').first);
    await settle(t);
    expect((await db.select(db.decisionEvents).get()).length, 1);
  });
}
