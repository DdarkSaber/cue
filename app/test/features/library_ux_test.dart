import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/app/router.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/library/library_view.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

Title _title(
  String id,
  String name,
  MediaKind kind, [
  List<String> genres = const [],
]) => Title(id: id, kind: kind, titleEn: name, genres: genres);

LibraryRow _row(
  Title t, {
  LibraryState state = LibraryState.completed,
  Rating? rating,
}) => (LibraryEntry(titleId: t.id, state: state, rating: rating), t);

Future<(CueDatabase, String)> _seed({bool shortlist = false}) async {
  final db = memoryDb();
  final id = (await ProfileRepository(db).ensureActive()).id;
  final catalog = CatalogRepository(db, FakeGateway());
  await catalog.upsert([
    CatalogItemDto(item(1, title: 'Alpha', genres: const ['Action', 'Sports'])),
    CatalogItemDto(
      item(2, title: 'Zed', kind: 'manhwa', genres: const ['Romance']),
    ),
    CatalogItemDto(
      item(3, title: 'Mid', kind: 'movie', genres: const ['Drama']),
    ),
  ]);
  final lib = LibraryRepository(db);
  await lib.saveEntry(
    id,
    'anilist:1',
    state: LibraryState.completed,
    rating: Rating.favourite,
  );
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await lib.saveEntry(id, 'anilist:2', state: LibraryState.planned);
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await lib.saveEntry(id, 'anilist:3', state: LibraryState.watching);
  if (shortlist) {
    final d = DecisionService(db);
    for (final i in [1, 2]) {
      await d.decide(
        id,
        (await catalog.titleById('anilist:${i + 3}')) ??
            (await _extra(catalog, i + 3))!,
        Decision.willTry,
      );
    }
  }
  return (db, id);
}

Future<Title?> _extra(CatalogRepository catalog, int n) async {
  await catalog.upsert([CatalogItemDto(item(n, title: 'Saved'))]);
  return catalog.titleById('anilist:$n');
}

void main() {
  group('LibraryQuery and TasteSummary', () {
    final a = _title('a', 'Alpha', MediaKind.anime, ['Action', 'Drama']);
    final b = _title('b', 'Beta', MediaKind.movie, ['Drama']);
    final c = _title('c', 'Charlie', MediaKind.anime, ['Comedy']);
    final rows = [
      _row(c, rating: Rating.disliked),
      _row(b, rating: Rating.favourite),
      _row(a, state: LibraryState.planned),
    ];

    test('sorts by title, rating and recency', () {
      List<String> ids(LibraryQuery q) =>
          q.apply(rows).map((r) => r.$2.id).toList();
      expect(ids(const LibraryQuery()), ['c', 'b', 'a']);
      expect(ids(const LibraryQuery(sort: LibrarySort.title)), ['a', 'b', 'c']);
      expect(ids(const LibraryQuery(sort: LibrarySort.rating)), [
        'b',
        'c',
        'a',
      ]);
    });

    test('filters by text, format and status together', () {
      expect(const LibraryQuery(kind: MediaKind.anime).apply(rows).length, 2);
      expect(
        const LibraryQuery(
          kind: MediaKind.anime,
          status: StatusFilter.planned,
        ).apply(rows).single.$2.id,
        'a',
      );
      expect(const LibraryQuery(text: 'ALP').apply(rows).single.$2.id, 'a');
      expect(
        const LibraryQuery(status: StatusFilter.unrated)
            .apply(rows)
            .single
            .$2
            .id,
        'a',
      );
      expect(const LibraryQuery().filtering, isFalse);
      expect(const LibraryQuery(text: 'x').filtering, isTrue);
    });

    test('taste counts ratings and learns only from positive ones', () {
      final s = TasteSummary.from(rows);
      expect(s.rated, 2);
      expect(s.liked, 1);
      expect(s.genres, ['Drama']);
      expect(s.kinds, [MediaKind.movie]);
      expect(TasteSummary.from(const []).rated, 0);
    });
  });

  group('Library screen', () {
    testWidgets('shows taste, sorts, filters and rates in place', (t) async {
      late CueDatabase db;
      late String id;
      await t.runAsync(() async => (db, id) = await _seed());
      addTearDown(db.close);
      await pumpCue(t, db: db, location: CueRoutes.library);
      await settle(t);

      expect(find.text('Your taste, from 1 rated title'), findsOneWidget);
      expect(
        find.textContaining('Action, Sports', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Rate more titles'), findsOneWidget);
      expect(find.text('3 titles'), findsOneWidget);

      // Format filter narrows the list and says so.
      await t.ensureVisible(find.text('Sort and filter'));
      await t.pumpAndSettle();
      await t.tap(find.text('Sort and filter'));
      await settle(t);
      await t.ensureVisible(find.text('Movie'));
      await t.pumpAndSettle();
      await t.tap(find.text('Movie'));
      await settle(t);
      expect(find.text('1 of 3 titles'), findsOneWidget);
      expect(find.text('Mid 3'), findsOneWidget);
      expect(find.text('Alpha 1'), findsNothing);

      // Status filter with no result offers a way out.
      await t.tap(find.text('Planned'));
      await settle(t);
      expect(
        find.text('Nothing in your library matches that.'),
        findsOneWidget,
      );
      final clear = find.widgetWithText(OutlinedButton, 'Clear filters');
      await t.ensureVisible(clear);
      await t.pumpAndSettle();
      await t.tap(clear);
      await settle(t);
      expect(find.text('3 titles'), findsOneWidget);

      // Rate in place.
      final rate = find.byTooltip('Rate Zed 2');
      await t.ensureVisible(rate);
      await t.pumpAndSettle();
      expect(t.getSize(rate).height, greaterThanOrEqualTo(48));
      await t.tap(rate);
      await settle(t);
      await t.tap(find.text('Enjoyed'));
      await settle(t);
      final entry = await t.runAsync(
        () => LibraryRepository(db).entry(id, 'anilist:2'),
      );
      expect(entry?.rating, Rating.enjoyed);
      expect(entry?.state, LibraryState.planned);
    });

    testWidgets('bulk rate and remove', (t) async {
      late CueDatabase db;
      late String id;
      await t.runAsync(() async => (db, id) = await _seed());
      addTearDown(db.close);
      await pumpCue(t, db: db, location: CueRoutes.library);
      await settle(t);

      await t.ensureVisible(find.text('Select several'));
      await t.pumpAndSettle();
      await t.tap(find.text('Select several'));
      await settle(t);
      expect(find.text('Tap titles to select them.'), findsOneWidget);
      await t.ensureVisible(find.text('Zed 2'));
      await t.pumpAndSettle();
      await t.tap(find.text('Zed 2'));
      await t.tap(find.text('Mid 3'));
      await settle(t);
      expect(find.text('2 selected'), findsOneWidget);

      await t.tap(find.text('Rate selected'));
      await settle(t);
      await t.tap(find.text('Okay'));
      await settle(t);
      final lib = LibraryRepository(db);
      expect(
        (await t.runAsync(() => lib.entry(id, 'anilist:3')))?.rating,
        Rating.okay,
      );

      await t.ensureVisible(find.text('Zed 2'));
      await t.pumpAndSettle();
      await t.tap(find.text('Zed 2'));
      await t.tap(find.text('Mid 3'));
      await settle(t);
      await t.tap(find.text('Remove selected'));
      await settle(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Remove').last);
      await settle(t);
      expect(await t.runAsync(() => lib.entry(id, 'anilist:2')), isNull);
      expect(await t.runAsync(() => lib.entry(id, 'anilist:3')), isNull);
      expect(await t.runAsync(() => lib.entry(id, 'anilist:1')), isNotNull);
    });

    testWidgets('an empty library points to Import and the deck', (t) async {
      await pumpCue(t, location: CueRoutes.library);
      await settle(t);
      expect(find.text('Import a list'), findsOneWidget);
      expect(find.text('Keep discovering'), findsOneWidget);
    });
  });

  group('Will try', () {
    testWidgets('picks for tonight and prompts a rating after Watched', (
      t,
    ) async {
      late CueDatabase db;
      late String id;
      await t.runAsync(() async => (db, id) = await _seed(shortlist: true));
      addTearDown(db.close);
      await pumpCue(t, db: db, location: CueRoutes.willTry);
      await settle(t);

      await t.tap(find.text('Pick for tonight'));
      await settle(t);
      expect(find.textContaining('Tonight: Saved'), findsOneWidget);

      await t.tap(find.widgetWithText(OutlinedButton, 'Watched'));
      await settle(t);
      expect(find.textContaining('How was Saved'), findsOneWidget);
      await t.tap(find.text('Enjoyed'));
      await settle(t);
      final lib = LibraryRepository(db);
      final rated = await t.runAsync(() async {
        final all = await lib.entries(id);
        return all.where((e) => e.$1.rating == Rating.enjoyed).length;
      });
      expect(rated, 1);
    });

    testWidgets('Watched can be skipped without rating', (t) async {
      late CueDatabase db;
      late String id;
      await t.runAsync(() async => (db, id) = await _seed(shortlist: true));
      addTearDown(db.close);
      await pumpCue(t, db: db, location: CueRoutes.willTry);
      await settle(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Watched'));
      await settle(t);
      await t.tap(find.text('Skip for now'));
      await settle(t);
      final n = await t.runAsync(() async {
        final all = await LibraryRepository(db).entries(id);
        return all.where((e) => e.$1.rating != null).length;
      });
      expect(n, 1); // only the seeded favourite
    });
  });

  group('Settings', () {
    testWidgets('is grouped into labelled sections in order', (t) async {
      await pumpCue(t, location: CueRoutes.settings);
      await settle(t);
      final labels = [
        'Recommendations',
        'Appearance',
        'Library and sync',
        'Privacy',
        'About',
      ];
      double? last;
      for (final l in labels) {
        final f = find.text(l);
        expect(f, findsOneWidget, reason: l);
        final y = t.getTopLeft(f).dy;
        if (last != null) expect(y, greaterThan(last), reason: l);
        last = y;
      }
      expect(find.text('AI picks'), findsOneWidget);
    });

    testWidgets('AI picks explain what is sent and stay opt-in', (t) async {
      await pumpCue(t, location: '${CueRoutes.settings}/preferences');
      await settle(t);
      await t.ensureVisible(find.text('AI picks (optional)'));
      await t.pumpAndSettle();
      expect(find.textContaining('What is never sent'), findsOneWidget);
      expect(
        t.widgetList<Switch>(find.byType(Switch)).every((s) => !s.value),
        isTrue,
      );
    });
  });

  group('Import', () {
    testWidgets('names the step in plain language', (t) async {
      await pumpCue(t, location: CueRoutes.importer);
      await settle(t);
      expect(find.text('Step 1 of 3 · Pick your list'), findsOneWidget);
    });
  });

  group('Large text at 320x640', () {
    const small = Size(320, 640);

    for (final entry in {
      'Library': CueRoutes.library,
      'Will try': CueRoutes.willTry,
      'Settings': CueRoutes.settings,
      'Preferences': '${CueRoutes.settings}/preferences',
      'Import': CueRoutes.importer,
    }.entries) {
      testWidgets('${entry.key} has no overflow at 2x text', (t) async {
        late CueDatabase db;
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          debugPrint(d.toString());
          prev?.call(d);
        };
        await t.runAsync(() async => (db, _) = await _seed(shortlist: true));
        addTearDown(db.close);
        await pumpCue(
          t,
          db: db,
          size: small,
          textScale: 2,
          location: entry.value,
        );
        await settle(t);
        final ex = t.takeException();
        if (ex is FlutterError) debugPrint(ex.toStringDeep());
        expect(ex, isNull);
        // Scroll to the end: lower content must lay out too.
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await t.drag(scrollable.first, const Offset(0, -3000));
          await settle(t);
        }
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('Library selection mode fits at 2x text', (t) async {
      late CueDatabase db;
      await t.runAsync(() async => (db, _) = await _seed());
      addTearDown(db.close);
      await pumpCue(
        t,
        db: db,
        size: small,
        textScale: 2,
        location: CueRoutes.library,
      );
      await settle(t);
      await t.ensureVisible(find.text('Select several'));
      await t.pumpAndSettle();
      await t.tap(find.text('Select several'));
      await settle(t);
      expect(t.takeException(), isNull);
    });
  });
}
