import 'package:cue/app/providers.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/mood_read_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('Tell me on the rail sets the deck text', (tester) async {
    await pumpCue(tester);
    await tester.tap(find.text('Tell me…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'slow rom com');
    await tester.tap(find.text('Show me'));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MoodReadChip)),
    );
    expect(c.read(deckFiltersProvider).tellMe, 'slow rom com');
    expect(find.text('“slow rom com”'), findsOneWidget);
  });

  testWidgets('a new person sees the learning chip', (tester) async {
    await pumpCue(tester);
    expect(find.text('Cue is learning your moods'), findsOneWidget);
  });

  testWidgets('the swipe tutorial shows once', (tester) async {
    await pumpCue(tester, tutorial: true);
    expect(find.text('How to swipe'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MoodReadChip)),
    );
    final id = await c.read(profileIdProvider.future);
    expect(
      await c.read(profileRepositoryProvider).rawSetting(id, 'tutorialDone'),
      'true',
    );
  });

  testWidgets('long-press Not now hides for the chosen length', (tester) async {
    await pumpCue(tester);
    await tester.longPress(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now: Tomorrow'));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(MoodReadChip)),
    );
    final db = c.read(databaseProvider);
    final row = await db.select(db.deferrals).getSingle();
    final days = row.eligibleAfter.difference(DateTime.now()).inHours;
    expect(days, inInclusiveRange(22, 25));
  });

  testWidgets('desktop buttons show their keys', (tester) async {
    await pumpCue(tester, size: desktop);
    expect(find.byTooltip('Will try (→)'), findsOneWidget);
    expect(find.byTooltip('Not now (↓)'), findsOneWidget);
  });
}
