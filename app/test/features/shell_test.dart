import 'package:cue/app/layout.dart';
import 'package:cue/app/router.dart';
import 'package:cue/domain/models/quick_mood.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:cue/features/deck/mood_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('home is the card (no welcome, quiz or login)', () {
    testWidgets('phone shows wordmark, mood rail, card, actions, nav', (
      t,
    ) async {
      await pumpCue(t, size: phoneSmall);
      expect(find.bySemanticsLabel('Cue'), findsOneWidget);
      for (final m in QuickMood.values) {
        expect(
          find.descendant(
            of: find.byType(MoodRail),
            matching: find.text(m.label),
          ),
          findsOneWidget,
        );
      }
      expect(find.byType(SwipeDeck), findsOneWidget);
      for (final a in ['Not interested', 'Not now', 'Will try']) {
        expect(find.text(a), findsWidgets);
      }
      for (final n in ['For you', 'Library', 'Settings']) {
        expect(find.text(n), findsWidgets);
      }
      expect(
        find.textContaining(
          RegExp('sign in|log in|welcome', caseSensitive: false),
        ),
        findsNothing,
      );
    });

    testWidgets('no all-caps labels anywhere in the shell', (t) async {
      await pumpCue(t, size: desktop);
      final texts = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '');
      for (final s in texts) {
        // The desktop genre eyebrow is the one allowed all-caps label.
        if (s.contains(' · ')) continue;
        final letters = s.replaceAll(RegExp('[^A-Za-z]'), '');
        if (letters.length > 1) {
          expect(
            letters == letters.toUpperCase(),
            isFalse,
            reason: '"$s" is all caps',
          );
        }
      }
      expect(find.text('YOUR NEXT STORY'), findsNothing);
    });
  });

  for (final size in [phoneSmall, desktop]) {
    testWidgets(
      'every text resolves to bundled DM Sans at ${size.width.toInt()}',
      (t) async {
        await pumpCue(t, size: size);
        for (final rt in t.widgetList<RichText>(find.byType(RichText))) {
          final span = rt.text;
          if (span is TextSpan && (span.toPlainText().trim().isEmpty)) continue;
          expect(
            span.style?.fontFamily,
            'DM Sans',
            reason: '"${span.toPlainText()}" uses ${span.style?.fontFamily}',
          );
        }
      },
    );
  }

  group('undo placement', () {
    testWidgets('phone hides the header undo until there is a swipe', (
      t,
    ) async {
      await pumpCue(t, size: phoneLarge);
      expect(find.byTooltip('Undo last swipe'), findsNothing);
    });

    testWidgets('phone shows the header undo after a swipe', (t) async {
      await pumpCue(t, size: phoneLarge);
      await t.tap(find.text('Not now'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Undo last swipe'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('desktop keeps a visible Undo under the actions', (t) async {
      await pumpCue(t, size: desktop);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.byTooltip('Undo last swipe'), findsNothing);
    });
  });

  testWidgets('mood chips select one at a time', (t) async {
    await pumpCue(t);
    Finder chip(String label) => find.descendant(
      of: find.byType(MoodRail),
      matching: find.widgetWithText(OutlinedButton, label),
    );
    expect(t.getSemantics(chip('For you')), isSemantics(isSelected: true));
    await t.tap(chip('Hype'));
    await t.pumpAndSettle();
    expect(t.getSemantics(chip('Hype')), isSemantics(isSelected: true));
    expect(t.getSemantics(chip('For you')), isSemantics(isSelected: false));
  });

  testWidgets('nav dock switches destinations', (t) async {
    await pumpCue(t);
    await t.tap(find.text('Library'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Your history belongs here. Bring a list, or keep discovering.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Settings'));
    await t.pumpAndSettle();
    expect(find.text('Make yourself at home'), findsOneWidget);
    await t.tap(find.text('Will try').last);
    await t.pumpAndSettle();
    expect(find.text('Your shortlist'), findsOneWidget);
    await t.tap(find.text('For you'));
    await t.pumpAndSettle();
    expect(find.byType(SwipeDeck), findsOneWidget);
  });

  testWidgets('deep link opens a destination directly', (t) async {
    await pumpCue(t, location: CueRoutes.settings);
    expect(find.text('Make yourself at home'), findsOneWidget);
  });

  group('accessibility', () {
    for (final size in [phoneSmall, phoneLarge, desktop]) {
      testWidgets(
        'survives 200% text at ${size.width.toInt()}x${size.height.toInt()}',
        (t) async {
          await pumpCue(t, size: size, textScale: 2);
          expect(t.takeException(), isNull);
          for (final a in ['Not interested', 'Not now']) {
            expect(find.text(a), findsOneWidget);
          }
        },
      );
    }

    testWidgets('tap targets are at least 48 px', (t) async {
      await pumpCue(t, size: phoneSmall);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('labelled tap targets', (t) async {
      await pumpCue(t, size: phoneSmall);
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('text contrast', (t) async {
      await loadCueFonts();
      await pumpCue(t, size: phoneLarge);
      await expectLater(t, meetsGuideline(textContrastGuideline));
    });

    testWidgets('reduced motion is read from the platform', (t) async {
      await pumpCue(t, disableAnimations: true);
      final ctx = t.element(find.byType(Scaffold));
      expect(ctx.reduceMotion, isTrue);
    });
  });
}
