import 'package:cue/app/router.dart';
import 'package:cue/app/widgets.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

/// UI-state checklist items plus behaviours found in design and
/// accessibility reviews.
void main() {
  group('system Back', () {
    testWidgets('from a secondary tab returns to For you', (t) async {
      await pumpCue(t, location: CueRoutes.library);
      final handled = await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.byType(SwipeDeck), findsOneWidget);
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
      expect(await scaleWhilePressed(t, 'Hype'), PressScale.pressedScale);
    });

    testWidgets('reduced motion keeps controls still', (t) async {
      await pumpCue(t, disableAnimations: true);
      expect(await scaleWhilePressed(t, 'Hype'), 1);
    });

    testWidgets('disabled controls do not react', (t) async {
      await pumpCue(t, gateway: FakeGateway(offline: true));
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
