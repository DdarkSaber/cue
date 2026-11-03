import 'package:cue/app/providers.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
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
  for (var i = 0; i < 300; i++) {
    await t.pump(const Duration(milliseconds: 100));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    final screen = find.byType(DeckScreen);
    if (i >= 5 && screen.evaluate().isNotEmpty) {
      final container = ProviderScope.containerOf(t.element(screen));
      final deck = container.read(deckControllerProvider);
      // Cached cards appear first; wait for the background refill too.
      if (!deck.loading && !deck.refreshing) break;
    }
  }
  await t.pumpAndSettle();
  final screen = find.byType(DeckScreen);
  if (screen.evaluate().isNotEmpty) {
    final deck = ProviderScope.containerOf(t.element(screen))
        .read(deckControllerProvider);
    expect(
      deck.loading || deck.refreshing,
      isFalse,
      reason: 'WASM candidate loading must finish before deck assertions.',
    );
  }
}

Future<void> waitForDecisions(WidgetTester t, int count) async {
  final container = ProviderScope.containerOf(
    t.element(find.byType(DeckScreen)),
  );
  for (var i = 0; i < 300; i++) {
    if (container.read(deckControllerProvider).sessionDecisions >= count) break;
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  expect(container.read(deckControllerProvider).sessionDecisions, count);
  await settle(t);
}

void main({bool releasePersistenceOnly = false}) {
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

  if (!releasePersistenceOnly) {
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
      final scope = ProviderScope.containerOf(
        t.element(find.byType(SwipeDeck)),
      );
      await scope
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(swipeMap: s.swipeMap.mirrored));
      await settle(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(t);
      final events = await db.select(db.decisionEvents).get();
      expect(events.single.action, Decision.notInterested.code);
    });
  }

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
      await waitForDecisions(t, 1);
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
    var count = 0;
    for (final label in [
      'Will try',
      'Not now',
      'Watched|Read it',
      'Not interested',
    ]) {
      await t.tap(find.textContaining(RegExp('^($label)\$')).first);
      await waitForDecisions(t, ++count);
    }
    // Rebuild the whole app on the same database.
    await t.pumpWidget(const SizedBox());
    await pumpCue(t, db: db);
    await settle(t);
    final events = await db.select(db.decisionEvents).get();
    expect(events.length, 4);
    expect(find.byTooltip('Undo last swipe'), findsOneWidget);
  });

  testWidgets('offline with an empty cache is a friendly retry, not a blank', (
    t,
  ) async {
    await pumpCue(t, gateway: FakeGateway(offline: true));
    await settle(t);
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.textContaining('try again on its own'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
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
    await waitForDecisions(t, 1);
    expect((await db.select(db.decisionEvents).get()).length, 1);
  });
}
