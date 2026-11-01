import 'package:cue/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs the real app on a device or emulator against the deployed Worker:
/// first-run tutorial, a deck decision, Will try, and This library.
/// Run: `flutter test integration_test -d emulator-5554`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int seconds = 2]) async {
    for (var i = 0; i < seconds * 4; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('a person can swipe, find it in Will try and see the library', (
    t,
  ) async {
    await app.main();
    await settle(t, 6);

    // First run: the swipe tutorial.
    if (find.text('How to swipe').evaluate().isNotEmpty) {
      await t.tap(find.text('Got it'));
      await settle(t);
    }

    // Wait for the first card from the live catalog, then decide on it.
    for (var i = 0; i < 40 && find.text('Will try').evaluate().isEmpty; i++) {
      await settle(t, 1);
    }
    await t.tap(find.text('Will try').first);
    await settle(t, 3);

    // It shows in the Will try tab.
    await t.tap(find.text('Will try').last);
    await settle(t, 3);
    expect(find.text('Remove'), findsWidgets);

    // This library reports the deck swipe.
    await t.tap(find.text('Settings').last);
    await settle(t);
    await t.tap(find.text('This library'));
    await settle(t, 3);
    expect(find.text('Deck swipes'), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
