import 'package:cue/app/router.dart';
import 'package:cue/app/tokens.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/features/deck/poster.dart';
import 'package:cue/features/imports/import_job.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import '../support/test_posters.dart';

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

String _poster(int i) => 'https://posters.test/$i.jpg';
String _adultPoster(int i) => 'https://posters.test/adult-$i.jpg';

/// A database whose catalog caches [count] titles with posters, plus a few
/// adult ones that must never show.
Future<CueDatabase> _cachedPosters(WidgetTester t, int count) async {
  final db = memoryDb();
  addTearDown(db.close);
  await t.runAsync(
    () => CatalogRepository(db, FakeGateway()).upsert([
      for (var i = 1; i <= count; i++)
        CatalogItemDto({...item(i), 'posterUrl': _poster(i)}),
      for (var i = 1; i <= 4; i++)
        CatalogItemDto({
          ...item(500 + i, adult: true),
          'posterUrl': _adultPoster(i),
        }),
      // No poster: never dealt.
      CatalogItemDto(item(900)),
    ]),
  );
  return db;
}

/// Matching over a catalog with [count] cached posters, decoded in memory.
/// URLs in [failing] report a load error.
Future<void> _pumpWithPosters(
  WidgetTester t,
  int count, {
  Set<String> failing = const {},
}) async {
  final db = await _cachedPosters(t, count);
  final image = (await t.runAsync(() => createTestImage(width: 2, height: 3)))!;
  addTearDown(image.dispose);
  await pumpCue(
    t,
    location: CueRoutes.importer,
    disableAnimations: true,
    db: db,
    overrides: [
      importJobProvider.overrideWith(_Running.new),
      posterImagesProvider.overrideWithValue(
        (url) => TestPosterImage(url, image, fails: failing.contains(url)),
      ),
    ],
  );
}

/// The poster each placeholder shows (the incoming one mid-fade), or null
/// where it shows a plain tone.
List<String?> _shown(WidgetTester t, String prefix) => [
  for (var i = 0; i < 6; i++)
    () {
      final images = find.descendant(
        of: find.byKey(ValueKey('$prefix-$i')),
        matching: find.byType(Image),
      );
      if (images.evaluate().isEmpty) return null;
      return (t.widget<Image>(images.last).image as TestPosterImage).url;
    }(),
];

List<String?> _tilePosters(WidgetTester t) => _shown(t, 'import-tile');
List<String?> _thumbPosters(WidgetTester t) => _shown(t, 'import-thumb');

int _differences(List<String?> a, List<String?> b) => [
  for (var i = 0; i < a.length; i++)
    if (a[i] != b[i]) i,
].length;

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

  group('cached posters', () {
    testWidgets('fill the tiles and the row thumbnails, dimmed, never adult, '
        'and hold still with reduced motion', (t) async {
      await _pumpWithPosters(t, 30);
      final safe = {for (var i = 1; i <= 30; i++) _poster(i)};

      final tiles = _tilePosters(t);
      final thumbs = _thumbPosters(t);
      expect(tiles, everyElement(isNotNull));
      expect(thumbs, everyElement(isNotNull));
      final all = [...tiles, ...thumbs];
      // Each from the catalog's cached posters, none adult, none twice.
      expect(safe.containsAll(all), isTrue);
      expect(all.toSet(), hasLength(12));

      // Dimmed, and hidden from screen readers like the tones were.
      for (final image in t.widgetList<Image>(find.byType(Image))) {
        expect(image.opacity?.value, closeTo(0.7, 1e-9));
        expect(image.excludeFromSemantics, isTrue);
      }
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('import-thumb-0')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      // Thumbnails keep the review list's poster shape.
      expect(
        t.getSize(find.byKey(const ValueKey('import-thumb-0'))),
        const Size(40, 56),
      );
      // The live region still carries the stage and the progress.
      expect(find.textContaining('Matching 3 of 10'), findsOneWidget);
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.3, 1e-9),
      );

      // Reduced motion: nothing changes and no timer or ticker runs.
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(_tilePosters(t), tiles);
      expect(_thumbPosters(t), thumbs);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('keep changing one tile and one thumbnail at a time, '
        'without repeating one on screen', (t) async {
      await _pumpWithPosters(t, 30);
      final safe = {for (var i = 1; i <= 30; i++) _poster(i)};
      _motion(t, on: true);
      await t.pump();

      var tiles = _tilePosters(t);
      var thumbs = _thumbPosters(t);
      var tileChanges = 0;
      var thumbChanges = 0;
      var crossFaded = false;
      // Changes come 0.7 to 1 s apart, so a half-second step sees at most
      // one per group.
      for (var step = 0; step < 16; step++) {
        await t.pump(const Duration(milliseconds: 500));
        final nowTiles = _tilePosters(t);
        final nowThumbs = _thumbPosters(t);
        final dt = _differences(tiles, nowTiles);
        final dr = _differences(thumbs, nowThumbs);
        expect(dt, lessThanOrEqualTo(1));
        expect(dr, lessThanOrEqualTo(1));
        tileChanges += dt;
        thumbChanges += dr;
        final all = [...nowTiles, ...nowThumbs];
        expect(all, everyElement(isNotNull));
        expect(safe.containsAll(all), isTrue);
        expect(all.toSet(), hasLength(12));
        // Mid-fade the old poster is still there under the new one.
        for (var i = 0; i < 6; i++) {
          final images = find.descendant(
            of: find.byKey(ValueKey('import-tile-$i')),
            matching: find.byType(Image),
          );
          if (images.evaluate().length == 2) crossFaded = true;
        }
        tiles = nowTiles;
        thumbs = nowThumbs;
      }
      expect(tileChanges, greaterThanOrEqualTo(5));
      expect(thumbChanges, greaterThanOrEqualTo(5));
      expect(crossFaded, isTrue);
    });

    testWidgets('fewer than six cached: coloured tiles and blocks', (t) async {
      await _pumpWithPosters(t, 5);
      expect(find.byType(Image), findsNothing);
      expect(_tileColors(t).toSet().length, greaterThanOrEqualTo(3));

      // The tones still cycle with motion on; no poster ever appears.
      final before = _tileColors(t);
      _motion(t, on: true);
      await t.pump();
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(_tileColors(t), isNot(before));
      expect(find.byType(Image), findsNothing);
      final thumb = t.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('import-thumb-0')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((thumb.decoration as BoxDecoration).color, CueColors.surfaceHigh);
    });

    testWidgets('a poster that fails to load leaves its tone', (t) async {
      await _pumpWithPosters(
        t,
        6,
        failing: {for (var i = 1; i <= 6; i++) _poster(i)}..remove(_poster(1)),
      );
      final tiles = _tilePosters(t);
      final thumbs = _thumbPosters(t);
      // Only the one good poster shows; every other placeholder keeps a
      // tone rather than going blank.
      expect([...tiles, ...thumbs].whereType<String>().toSet(), {_poster(1)});
      expect(tiles.where((u) => u == null), hasLength(5));
      for (var i = 0; i < 6; i++) {
        if (tiles[i] != null) continue;
        expect(
          find.descendant(
            of: find.byKey(ValueKey('import-tile-$i')),
            matching: find.byType(DecoratedBox),
          ),
          findsWidgets,
        );
      }
    });

    testWidgets('leaving mid-fade cancels both timers cleanly', (t) async {
      await _pumpWithPosters(t, 30);
      _motion(t, on: true);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 200));
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
      expect(t.takeException(), isNull);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });
}
