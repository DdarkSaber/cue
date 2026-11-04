import 'package:cue/features/deck/deck_screen.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _small = Size(320, 640);

void main() {
  for (final scale in [1.5, 2.0]) {
    testWidgets('deck fits 320x640 at ${scale}x text', (t) async {
      final handle = t.ensureSemantics();
      await pumpCue(t, size: _small, textScale: scale);
      expect(t.takeException(), isNull);
      expect(find.byType(DeckScreen), findsOneWidget);
      // All four decisions stay reachable as buttons.
      for (final label in ['Not interested', 'Not now', 'Will try']) {
        expect(find.text(label), findsWidgets);
      }
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('details scroll at 320x640 and ${scale}x text', (t) async {
      await pumpCue(t, size: _small, textScale: scale);
      await t.tap(find.byType(SwipeDeck));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Why you are seeing this'), findsOneWidget);
      // The last line of the sheet can be scrolled into view.
      await t.scrollUntilVisible(
        find.textContaining('Metadata and artwork'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(t.takeException(), isNull);
      expect(find.textContaining('Metadata and artwork'), findsOneWidget);
    });
  }
}
