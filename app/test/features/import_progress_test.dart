import 'package:cue/app/router.dart';
import 'package:cue/features/imports/import_job.dart';
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
}
