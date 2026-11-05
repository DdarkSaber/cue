import 'package:cue/app/providers.dart';
import 'package:cue/app/route_scaffold.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_rating_service.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/recommendation_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/features/library/library_screen.dart';
import 'package:cue/features/library/rating_deck.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// A drag far enough to commit in each direction.
const _drags = {
  'up': Offset(0, -320),
  'right': Offset(320, 0),
  'down': Offset(0, 320),
  'left': Offset(-320, 0),
};

void main() {
  group('Library rating deck', () {
    late CueDatabase db;
    late LibraryRatingService service;
    late RecommendationRepository recommendations;
    final now = DateTime.utc(2026, 10, 20);
    var changes = 0;

    Future<void> seed({
      String? rating,
      bool followUp = false,
      bool entry = true,
      List<String> ids = const ['one'],
    }) async {
      await db
          .into(db.profiles)
          .insert(ProfilesCompanion.insert(id: 'synthetic', createdAt: now));
      for (final id in ids) {
        final titleId = 'invented:$id';
        await db
            .into(db.catalogTitles)
            .insert(
              CatalogTitlesCompanion.insert(
                id: titleId,
                mediaKind: 'anime',
                titleEn: Value(
                  id == 'one' ? 'Invented card' : 'Invented card $id',
                ),
                genresJson: const Value('["Comedy"]'),
                updatedAt: now,
              ),
            );
        if (entry) {
          await db
              .into(db.userTitles)
              .insert(
                UserTitlesCompanion.insert(
                  profileId: 'synthetic',
                  titleId: titleId,
                  state: const Value('completed'),
                  rating: Value(rating),
                  progressValue: const Value(12),
                  note: const Value('Synthetic original'),
                  source: const Value('import:fixture'),
                  updatedAt: now.subtract(const Duration(days: 1)),
                ),
              );
        }
        if (followUp) {
          await db
              .into(db.shortlist)
              .insert(
                ShortlistCompanion.insert(
                  profileId: 'synthetic',
                  titleId: titleId,
                  addedAt: now.subtract(const Duration(days: 8)),
                ),
              );
        }
      }
    }

    /// Lets swipe animations, real database work and rebuilds all finish.
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 3; i++) {
        await t.pumpAndSettle();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await t.pumpAndSettle();
    }

    Future<List<UserTitle>> rows(WidgetTester t) async =>
        (await t.runAsync(() => db.select(db.userTitles).get()))!;

    Future<String?> ratingOf(WidgetTester t, String id) async =>
        (await rows(t)).where((r) => r.titleId == id).firstOrNull?.rating;

    /// The title id of the card on top of the deck.
    String topId(WidgetTester t) {
      final key =
          t
                  .widget(
                    find.byWidgetPredicate(
                      (w) =>
                          w.key is ValueKey<String> &&
                          (w.key! as ValueKey<String>).value.startsWith('top-'),
                    ),
                  )
                  .key!
              as ValueKey<String>;
      return key.value.substring('top-'.length);
    }

    Future<void> swipe(WidgetTester t, String direction) async {
      await t.drag(find.byKey(ValueKey('top-${topId(t)}')), _drags[direction]!);
      await settle(t);
    }

    Finder button(String label) => find.widgetWithText(TextButton, label);

    Widget scope(Widget child) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        profileIdProvider.overrideWith((ref) async => 'synthetic'),
        clockProvider.overrideWithValue(() => now),
      ],
      child: child,
    );

    Future<void> pump(
      WidgetTester t, {
      bool followUp = false,
      double scale = 1,
    }) async {
      await t.pumpWidget(
        scope(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: LibraryRatingDeck(
                  service: service,
                  profileId: 'synthetic',
                  followUp: followUp,
                  onChanged: () => changes++,
                ),
              ),
            ),
          ),
        ),
      );
      await settle(t);
    }

    setUp(() {
      db = memoryDb();
      final library = LibraryRepository(db, clock: () => now);
      recommendations = RecommendationRepository(db, clock: () => now);
      service = LibraryRatingService(
        db,
        library,
        recommendations,
        clock: () => now,
      );
      changes = 0;
    });
    tearDown(() async => db.close());

    testWidgets(
      'optional entry never saves until answer; Skip and Undo never fabricate',
      (t) async {
        await t.runAsync(() => seed());
        await pump(t);
        expect(find.text('Invented card'), findsOneWidget);
        expect(find.text('1 of 1'), findsOneWidget);
        for (final label in ['Loved', 'Enjoyed', 'One-time', 'Dropped']) {
          expect(button(label), findsOneWidget, reason: label);
        }
        // A drag that is not far enough springs back and saves nothing.
        await t.drag(
          find.byKey(const ValueKey('top-invented:one')),
          const Offset(0, -30),
        );
        await settle(t);
        expect(find.text('Invented card'), findsOneWidget);
        expect(changes, 0);
        await t.tap(find.text('Skip'));
        await settle(t);
        expect(find.text('Invented card'), findsNothing);
        expect(find.text('Done'), findsOneWidget);
        expect(changes, 0);
        await t.tap(find.text('Undo'));
        await settle(t);
        expect(find.text('Invented card'), findsOneWidget);
        expect((await rows(t)).single.rating, isNull);
        expect(changes, 0);
      },
    );

    testWidgets(
      'each swipe direction saves its rating: up Loved, right Enjoyed, down One-time, left Dropped',
      (t) async {
        await t.runAsync(() => seed(ids: ['a', 'b', 'c', 'd']));
        await pump(t);
        expect(find.text('1 of 4'), findsOneWidget);
        // Dragging previews the answer on the card, like the For you deck.
        final gesture = await t.startGesture(
          t.getCenter(find.byKey(ValueKey('top-${topId(t)}'))),
        );
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -60));
        await t.pump();
        expect(find.text('Loved'), findsNWidgets(2));
        await gesture.moveBy(const Offset(0, 80));
        await gesture.up();
        await settle(t);
        expect(changes, 0);

        final expected = {
          'up': Rating.favourite,
          'right': Rating.enjoyed,
          'down': Rating.once,
          'left': Rating.dropped,
        };
        var position = 1;
        for (final MapEntry(key: direction, value: rating)
            in expected.entries) {
          expect(find.text('$position of 4'), findsOneWidget);
          final id = topId(t);
          await swipe(t, direction);
          expect(await ratingOf(t, id), rating.code, reason: direction);
          position++;
        }
        expect(changes, 4);
        expect(find.text('All 4 done'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets('arrow keys and buttons rate like a swipe', (t) async {
      await t.runAsync(() => seed(ids: ['a', 'b']));
      await pump(t);
      final first = topId(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(t);
      expect(await ratingOf(t, first), Rating.enjoyed.code);
      final second = topId(t);
      await t.tap(button('One-time'));
      await settle(t);
      expect(await ratingOf(t, second), Rating.once.code);
    });

    testWidgets(
      'Loved saves evidence and Undo restores imported row and monotonic timestamp',
      (t) async {
        await t.runAsync(() => seed());
        final before = (await rows(t)).single;
        await pump(t);
        await swipe(t, 'up');
        final after = (await rows(t)).single;
        expect(after.rating, Rating.favourite.code);
        expect(after.note, before.note);
        expect(after.source, before.source);
        expect(changes, 1);
        expect(find.text('Invented card'), findsNothing);
        await t.tap(find.text('Undo'));
        await settle(t);
        final restored = (await rows(t)).single;
        expect(restored.copyWith(updatedAt: before.updatedAt), before);
        expect(restored.updatedAt.isAfter(after.updatedAt), isTrue);
        expect(changes, 2);
        // The card comes back to be answered again.
        expect(find.text('Invented card'), findsOneWidget);
        expect(find.text('1 of 1'), findsOneWidget);
      },
    );

    testWidgets('the exit button and Escape leave at any time', (t) async {
      await t.runAsync(() => seed(ids: ['a', 'b']));
      await t.pumpWidget(
        scope(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LibraryRatingDeck(
                        service: service,
                        profileId: 'synthetic',
                        onChanged: () => changes++,
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await settle(t);
      expect(find.byType(LibraryRatingDeck), findsOneWidget);
      await swipe(t, 'right');
      expect(find.text('2 of 2'), findsOneWidget);
      await t.tap(find.byTooltip('Exit rating'));
      await settle(t);
      expect(find.byType(LibraryRatingDeck), findsNothing);
      // Leaving keeps what was answered and adds nothing else.
      expect((await rows(t)).where((r) => r.rating != null), hasLength(1));

      await t.tap(find.text('Open'));
      await settle(t);
      expect(find.byType(LibraryRatingDeck), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(t);
      expect(find.byType(LibraryRatingDeck), findsNothing);
      expect(changes, 1);
    });

    testWidgets(
      'existing ratings require opt-in review and explicit overwrite confirmation',
      (t) async {
        await t.runAsync(() => seed(rating: Rating.okay.code));
        await pump(t);
        expect(find.text('Invented card'), findsNothing);
        // Empty is never a dead end: it offers a way out.
        expect(find.text('Done'), findsOneWidget);
        await t.tap(find.text('Review existing ratings'));
        await settle(t);
        expect(find.text('Invented card'), findsOneWidget);
        await t.tap(button('Enjoyed'));
        await settle(t);
        expect(find.text('Replace your existing rating?'), findsOneWidget);
        await t.tap(find.text('Keep rating'));
        await settle(t);
        expect((await rows(t)).single.rating, Rating.okay.code);
        // Nothing saved, so the card is back.
        expect(find.text('Invented card'), findsOneWidget);
        await swipe(t, 'right');
        expect(find.text('Replace your existing rating?'), findsOneWidget);
        await t.tap(find.text('Replace rating'));
        await settle(t);
        expect((await rows(t)).single.rating, Rating.enjoyed.code);
        await t.tap(find.text('Undo'));
        await settle(t);
        expect((await rows(t)).single.rating, Rating.okay.code);
      },
    );

    testWidgets(
      'follow-up swipes: up Loved, right Enjoyed, left Not for me, down Haven\'t started',
      (t) async {
        await t.runAsync(
          () => seed(followUp: true, entry: false, ids: ['a', 'b', 'c', 'd']),
        );
        await pump(t, followUp: true);
        expect(find.text('Tried a shortlist pick?'), findsOneWidget);
        for (final label in [
          'Loved',
          'Enjoyed',
          'Not for me',
          "Haven't started",
        ]) {
          expect(button(label), findsOneWidget, reason: label);
        }
        final expected = {
          'up': Rating.favourite.code,
          'right': Rating.enjoyed.code,
          'left': Rating.dropped.code,
          'down': null,
        };
        for (final MapEntry(key: direction, value: code) in expected.entries) {
          final id = topId(t);
          await swipe(t, direction);
          expect(await ratingOf(t, id), code, reason: direction);
          if (code == null) {
            expect(
              await t.runAsync(
                () => recommendations.dismissed('synthetic', id),
              ),
              isTrue,
            );
            expect((await rows(t)).where((r) => r.titleId == id), isEmpty);
          }
        }
        expect(find.text('All 4 done'), findsOneWidget);
      },
    );

    testWidgets(
      "Haven't started and dismiss are optional, never consume or rate; manual review remains",
      (t) async {
        await t.runAsync(() => seed(followUp: true, entry: false));
        await pump(t, followUp: true);
        await t.tap(button("Haven't started"));
        await settle(t);
        expect(await rows(t), isEmpty);
        expect(
          await t.runAsync(
            () => recommendations.dismissed('synthetic', 'invented:one'),
          ),
          isTrue,
        );
        await t.tap(find.text('Review dismissed picks'));
        await settle(t);
        expect(find.text('Invented card'), findsOneWidget);
        await t.tap(find.text('Dismiss follow-up'));
        await settle(t);
        expect(await rows(t), isEmpty);
        expect(
          (await t.runAsync(
            () => recommendations.read('synthetic'),
          ))!['followupAnswers'],
          isNull,
        );
      },
    );

    testWidgets(
      'follow-up Not for me is actual negative evidence and Undo removes only new row',
      (t) async {
        await t.runAsync(() => seed(followUp: true, entry: false));
        await pump(t, followUp: true);
        await swipe(t, 'left');
        final row = (await rows(t)).single;
        expect(row.rating, Rating.dropped.code);
        expect(row.state, 'none');
        expect(row.actualWatchedAt, isNull);
        expect(await t.runAsync(() => db.select(db.shortlist).get()), isEmpty);
        await t.tap(find.text('Undo'));
        await settle(t);
        expect(await rows(t), isEmpty);
        expect(
          await t.runAsync(() => db.select(db.shortlist).get()),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'returning from tried shortlist flow displays rated no-status title in normal Library',
      (t) async {
        await t.runAsync(() => seed(followUp: true, entry: false));
        await t.pumpWidget(
          scope(const MaterialApp(home: Scaffold(body: LibraryScreen()))),
        );
        await settle(t);
        await t.tap(find.text('Review shortlist picks'));
        await settle(t);
        expect(find.byType(LibraryRatingDeck), findsOneWidget);
        await t.tap(button('Enjoyed'));
        await settle(t);
        await t.tap(find.byTooltip('Exit rating'));
        await settle(t);
        expect(find.byType(LibraryRatingDeck), findsNothing);
        final rowFinder = find.byWidgetPredicate(
          (w) => w is CueListRow && w.title == 'Invented card',
        );
        expect(rowFinder, findsOneWidget);
        await t.ensureVisible(rowFinder);
        await t.pumpAndSettle();
        expect(find.text('No status'), findsOneWidget);
        final visibleRow = t.widget<CueListRow>(rowFinder);
        expect(visibleRow.subtitle, contains('No status'));
        expect(visibleRow.subtitle, contains('Enjoyed'));
        expect(visibleRow.subtitle, isNot(contains('rewatch')));
        expect(visibleRow.subtitle, isNot(contains('Completed')));
        expect(
          t.getRect(rowFinder).overlaps(t.getRect(find.byType(Scaffold))),
          isTrue,
        );
        final saved = (await rows(t)).single;
        expect(saved.state, 'none');
        expect(Rating.parse(saved.rating)!.isRewatch, isFalse);
        expect(saved.actualWatchedAt, isNull);
        expect(saved.progressValue, isNull);
        // The live integration binding does not register TestTextInput.
        // Register before focus so enterText gets the real client id rather
        // than sending an ignored update to client -1.
        final registerInput = !t.testTextInput.isRegistered;
        if (registerInput) t.testTextInput.register();
        final filter = find.byType(TextField);
        try {
          await t.ensureVisible(filter);
          await t.pumpAndSettle();
          await t.tap(filter);
          await settle(t);
          expect(t.testTextInput.hasAnyClients, isTrue);
          await t.enterText(filter, 'unrelated invented title');
          await settle(t);
          expect(
            t.widget<EditableText>(find.byType(EditableText)).controller.text,
            'unrelated invented title',
          );
          expect(rowFinder, findsNothing);
          await t.enterText(filter, 'invented card');
          await settle(t);
          expect(
            t.widget<EditableText>(find.byType(EditableText)).controller.text,
            'invented card',
          );
          expect(rowFinder, findsOneWidget);
        } finally {
          if (registerInput) t.testTextInput.unregister();
        }
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('Library "Rate more titles" opens the full-screen deck', (
      t,
    ) async {
      await t.runAsync(() => seed(ids: ['a', 'b']));
      await t.pumpWidget(
        scope(const MaterialApp(home: Scaffold(body: LibraryScreen()))),
      );
      await settle(t);
      final rate = find.text('Rate more titles');
      await t.ensureVisible(rate);
      await t.pumpAndSettle();
      await t.tap(rate);
      await settle(t);
      expect(find.byType(LibraryRatingDeck), findsOneWidget);
      expect(find.text('Rate your library'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      final id = topId(t);
      await swipe(t, 'down');
      expect(await ratingOf(t, id), Rating.once.code);
      await t.tap(find.byTooltip('Exit rating'));
      await settle(t);
      expect(find.byType(LibraryRatingDeck), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets(
      'large text rating buttons retain accessible labelled tap targets',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.runAsync(() => seed());
        await pump(t, scale: 2);
        // Release web integration hosts do not expose SemanticsNode data to
        // WidgetTester. Verify native semantics and web labelled hit targets.
        final semantics = kIsWeb ? null : t.ensureSemantics();
        try {
          final loved = button('Loved');
          expect(t.widget<TextButton>(loved).onPressed, isNotNull);
          expect(t.getSize(loved).height, greaterThanOrEqualTo(48));
          expect(t.getSize(loved).width, greaterThanOrEqualTo(48));
          if (!kIsWeb) {
            expect(
              t.getSemantics(loved),
              matchesSemantics(
                label: 'Loved',
                isButton: true,
                hasTapAction: true,
                hasFocusAction: true,
                isFocusable: true,
                hasEnabledState: true,
                isEnabled: true,
              ),
            );
          }
          await t.tap(loved);
          await settle(t);
          expect((await rows(t)).single.rating, Rating.favourite.code);
          expect(find.text('Done'), findsOneWidget);
          expect(t.takeException(), isNull);
        } finally {
          semantics?.dispose();
        }
      },
    );
  });
}
