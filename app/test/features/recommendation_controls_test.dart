import 'dart:async';

import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

void main() {
  Future<void> finish(WidgetTester t, String message) async {
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (find.text(message).evaluate().isNotEmpty) return;
    }
    fail('The session action did not complete: $message');
  }

  testWidgets(
    'session controls never write ratings, persistent taste or learned mood',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      await pumpCue(t, db: db, size: desktop);
      final c = ProviderScope.containerOf(t.element(find.byType(DeckScreen)));
      final controller = c.read(deckControllerProvider.notifier);
      final before = await t.runAsync(
        () async => [
          (await db.select(db.tagWeights).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.moodStates).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.userTitles).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.exclusions).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.decisionEvents).get())
              .map((r) => r.toJson())
              .toList(),
        ],
      );
      await t.tap(find.byTooltip('Filters and mood'));
      await t.pumpAndSettle();
      await t.tap(find.text('Session picks and Why'));
      await t.pumpAndSettle();
      expect(find.text('For this session'), findsOneWidget);
      await t.tap(find.text('More like this'));
      await finish(t, 'More like this, only for this session.');
      expect(
        find.text('More like this, only for this session.'),
        findsOneWidget,
      );
      expect(
        c.read(deckControllerProvider).cards.length,
        lessThanOrEqualTo(10),
      );
      await t.tap(find.text('Less like this'));
      await finish(t, 'Less like this, only for this session.');
      expect(
        find.text('Less like this, only for this session.'),
        findsOneWidget,
      );
      var explored = false;
      unawaited(controller.setExploration(1).then((_) => explored = true));
      for (var i = 0; !explored && i < 80; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(explored, isTrue);
      expect(controller.exploration, 1);
      await t.ensureVisible(find.text('Reset session'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Reset session'));
      await finish(
        t,
        'Temporary preferences reset; library ratings and mood learning kept.',
      );
      expect(controller.exploration, 0.35);
      final after = await t.runAsync(
        () async => [
          (await db.select(db.tagWeights).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.moodStates).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.userTitles).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.exclusions).get())
              .map((r) => r.toJson())
              .toList(),
          (await db.select(db.decisionEvents).get())
              .map((r) => r.toJson())
              .toList(),
        ],
      );
      expect(after, before);
      expect(t.takeException(), isNull);
    },
  );
}
