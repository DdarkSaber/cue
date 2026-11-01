import 'package:cue/app/providers.dart';
import 'package:cue/app/router.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/try_now_repository.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

Future<void> _until(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 300 && !ready(); i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  expect(ready(), isTrue);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('root double-tap saves Try now once, preserves rating and Undo', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db, disableAnimations: true);
    final c = ProviderScope.containerOf(t.element(find.byType(DeckScreen)));
    await _until(t, () => c.read(deckControllerProvider).top != null);
    final id = await c.read(profileIdProvider.future);
    final title = c.read(deckControllerProvider).top!.title;
    final target = find.byType(SwipeDeck);
    await t.tap(target);
    await t.pump(const Duration(milliseconds: 70));
    await t.tap(target);
    await _until(
      t,
      () => c.read(deckControllerProvider).lastDecision?.tryNow == true,
    );
    final state = await t.runAsync(
      () async => (
        await TryNowRepository(db).isActive(id, title.id),
        await LibraryRepository(db).entry(id, title.id),
        await db.select(db.decisionEvents).get(),
      ),
    );
    expect(state!.$1, isTrue);
    expect(state.$2, isNull);
    expect(state.$3.where((e) => e.action == 'try_now'), hasLength(1));
    expect(find.text('Try now saved. Undo is available.'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
    await t.tap(find.byTooltip('Undo last swipe'));
    await _until(
      t,
      () => c.read(deckControllerProvider).top?.title.id == title.id,
    );
    expect(
      await t.runAsync(() => TryNowRepository(db).isActive(id, title.id)),
      isFalse,
    );
    expect(
      await t.runAsync(() => LibraryRepository(db).shortlist(id)),
      isEmpty,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Shift Enter is accessible Try now without extra home controls', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await pumpCue(t, db: db, size: desktop);
    final c = ProviderScope.containerOf(t.element(find.byType(DeckScreen)));
    await _until(t, () => c.read(deckControllerProvider).top != null);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _until(
      t,
      () => c.read(deckControllerProvider).lastDecision?.tryNow == true,
    );
    expect(find.byTooltip('Why and session recommendations'), findsNothing);
    expect(find.byTooltip('Filters and mood'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'small phone large text uses disclosed session actions and optional context',
    (t) async {
      await pumpCue(t, size: phoneSmall, textScale: 2, disableAnimations: true);
      final c = ProviderScope.containerOf(t.element(find.byType(DeckScreen)));
      await _until(t, () => c.read(deckControllerProvider).top != null);
      final beforeMap = c.read(currentSettingsProvider).swipeMap;
      await t.tap(find.byTooltip('Filters and mood'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Session picks and Why'));
      await t.pumpAndSettle();
      await t.tap(find.text('Session picks and Why'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Surprise me'));
      await t.pumpAndSettle();
      await t.tap(find.text('Surprise me'));
      await _until(
        t,
        () => c.read(deckControllerProvider.notifier).surpriseRemaining == 5,
      );
      expect(
        find.textContaining('Exploration boost: 5 choices'),
        findsOneWidget,
      );
      await t.ensureVisible(find.text('Bring back later / context'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bring back later / context'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Saving for later'));
      await t.tap(find.text('Saving for later'));
      await t.ensureVisible(find.text('Not now: Tomorrow'));
      await t.tap(find.text('Not now: Tomorrow'));
      await _until(
        t,
        () =>
            c.read(deckControllerProvider).lastDecision?.decision ==
            Decision.notNow,
      );
      expect(c.read(currentSettingsProvider).swipeMap, beforeMap);
      expect(c.read(deckControllerProvider.notifier).repeatedNotNow, isFalse);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'exhausted filtered deck offers explicit filters and saved alternative',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      await pumpCue(
        t,
        db: db,
        gateway: FakeGateway(),
        location: CueRoutes.forYou,
      );
      final c = ProviderScope.containerOf(t.element(find.byType(DeckScreen)));
      await _until(t, () => !c.read(deckControllerProvider).loading);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Choose from saved'), findsOneWidget);
      await t.tap(find.text('Choose from saved'));
      await t.pumpAndSettle();
      expect(find.text('Find a story'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
