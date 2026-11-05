import 'package:cue/app/router.dart';
import 'package:cue/features/imports/import_job.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

class _Running extends ImportJob {
  @override
  ImportJobState build() =>
      const ImportJobState(running: true, done: 3, total: 10);
}

const _skeleton = ValueKey('import-skeleton');
const _tiles = ValueKey('import-tiles');

/// The colour each poster tile shows right now (mid-fade included).
List<Color?> _tileColors(WidgetTester t) => [
  for (var i = 0; i < 6; i++)
    (t
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byKey(ValueKey('import-tile-$i')),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color,
];

Future<void> _pumpMatching(WidgetTester t) => pumpCue(
  t,
  location: CueRoutes.importer,
  // Reduced motion so pumpCue can settle; tests turn motion on after.
  disableAnimations: true,
  overrides: [importJobProvider.overrideWith(_Running.new)],
);

void _motion(WidgetTester t, {required bool on}) =>
    t.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: !on);

void main() {
  testWidgets(
    'matching shows the stage, the real progress and a still skeleton',
    (t) async {
      final semantics = t.ensureSemantics();
      // Reduced motion: pumpCue settles, which already proves nothing ticks.
      await pumpCue(
        t,
        location: CueRoutes.importer,
        disableAnimations: true,
        overrides: [importJobProvider.overrideWith(_Running.new)],
      );

      final label = find.textContaining('Matching 3 of 10');
      expect(label, findsOneWidget);
      final bar = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.3, 1e-9));

      // The words and the bar are announced as a live region.
      expect(
        find.ancestor(
          of: label,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.liveRegion ?? false),
          ),
        ),
        findsOneWidget,
      );

      // Placeholder rows shaped like the review list, hidden from readers.
      final skeleton = find.byKey(_skeleton);
      expect(skeleton, findsOneWidget);
      expect(
        find.descendant(of: skeleton, matching: find.byType(Row)),
        findsNWidgets(6),
      );
      expect(
        find.ancestor(of: skeleton, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );

      // Above the rows: a 3 x 2 wall of poster-shaped tiles, also hidden.
      final tiles = find.byKey(_tiles);
      expect(tiles, findsOneWidget);
      expect(
        find.ancestor(of: tiles, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      for (var i = 0; i < 6; i++) {
        final size = t.getSize(find.byKey(ValueKey('import-tile-$i')));
        expect(size.width / size.height, closeTo(2 / 3, 0.01));
      }
      expect(
        t.getRect(find.byKey(const ValueKey('import-tile-5'))).bottom,
        lessThan(t.getRect(skeleton).top),
      );
      // The tiles start in varied tones.
      expect(_tileColors(t).toSet().length, greaterThanOrEqualTo(3));

      // No shimmer and no animation ticker with reduced motion.
      expect(
        find.descendant(of: skeleton, matching: find.byType(ShaderMask)),
        findsNothing,
      );
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(t.binding.hasScheduledFrame, isFalse);

      // Motion back on: the shimmer runs.
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(of: skeleton, matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

      // And off again: it stops and the screen settles.
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await t.pumpAndSettle();
      expect(
        find.descendant(of: skeleton, matching: find.byType(ShaderMask)),
        findsNothing,
      );
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      semantics.dispose();
    },
  );
  testWidgets('poster tiles hold still with reduced motion', (t) async {
    await _pumpMatching(t);
    final before = _tileColors(t);
    // Long enough for several changes if a timer were running.
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(_tileColors(t), before);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('poster tiles keep cross-fading while motion is on', (t) async {
    await _pumpMatching(t);
    final before = _tileColors(t);
    _motion(t, on: true);
    await t.pump();

    // One tile changes within a second, and cross-fades rather than jumps:
    // part-way through it shows a blend that is in no palette slot.
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(milliseconds: 300));
    final mid = _tileColors(t);
    final changed = [
      for (var i = 0; i < 6; i++)
        if (mid[i] != before[i]) i,
    ];
    expect(changed, hasLength(1));
    expect(before, isNot(contains(mid[changed.single])));

    // When the fade finishes the tile rests on another palette tone.
    await t.pump(const Duration(milliseconds: 300));
    final after = _tileColors(t);
    expect(after[changed.single], isNot(before[changed.single]));

    // And it keeps going.
    var changes = 0;
    var last = after;
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 500));
      final now = _tileColors(t);
      if (!listEquals(now, last)) changes++;
      last = now;
    }
    expect(changes, greaterThanOrEqualTo(2));
  });

  testWidgets('leaving mid-fade cancels the tile timer cleanly', (t) async {
    await _pumpMatching(t);
    _motion(t, on: true);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(milliseconds: 200));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

    // Dispose the screen while a tile is fading and its next change is due.
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(t.binding.hasScheduledFrame, isFalse);
    // The test binding also fails the test if any timer is left pending.
  });
}
