import 'package:cue/app/router.dart';
import 'package:cue/app/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// UI-state checklist (docs/checklists/ui-states.md) items reachable in M0,
/// plus behaviours found in the M0 design and accessibility review.
void main() {
  group('empty states say why and offer one next step', () {
    for (final (route, label) in [
      (CueRoutes.willTry, 'Find a story'),
      (CueRoutes.library, 'Keep discovering'),
    ]) {
      testWidgets('$route -> "$label" returns to the deck', (t) async {
        await pumpCue(t, location: route);
        await t.tap(find.widgetWithText(FilledButton, label));
        await t.pumpAndSettle();
        expect(
          find.bySemanticsLabel('Loading recommendations'),
          findsOneWidget,
        );
      });
    }
  });

  group('system Back', () {
    testWidgets('from a secondary tab returns to For you', (t) async {
      await pumpCue(t, location: CueRoutes.library);
      final handled = await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.bySemanticsLabel('Loading recommendations'), findsOneWidget);
    });

    testWidgets('on For you is left to the system', (t) async {
      await pumpCue(t);
      final handled = await t.binding.handlePopRoute();
      expect(handled, isFalse);
    });
  });

  group('press feedback', () {
    Future<double> scaleWhilePressed(WidgetTester t, String label) async {
      final target = find.text(label).first;
      final g = await t.startGesture(t.getCenter(target));
      await t.pump(const Duration(milliseconds: 150));
      final s = t
          .widget<AnimatedScale>(
            find
                .ancestor(of: target, matching: find.byType(AnimatedScale))
                .first,
          )
          .scale;
      await g.up();
      await t.pumpAndSettle();
      return s;
    }

    testWidgets('enabled controls scale to 0.96', (t) async {
      await pumpCue(t);
      expect(await scaleWhilePressed(t, 'Comfort'), PressScale.pressedScale);
    });

    testWidgets('reduced motion keeps controls still', (t) async {
      await pumpCue(t, disableAnimations: true);
      expect(await scaleWhilePressed(t, 'Comfort'), 1);
    });

    testWidgets('disabled controls do not react', (t) async {
      await pumpCue(t);
      expect(await scaleWhilePressed(t, 'Not now'), 1);
    });
  });

  group('narrowest supported width (320 px)', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('home survives at text scale $scale', (t) async {
        await pumpCue(t, size: const Size(320, 640), textScale: scale);
        expect(t.takeException(), isNull);
        expect(find.text('Not interested'), findsOneWidget);
      });
    }
  });
}
