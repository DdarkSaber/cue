import 'package:cue/app/providers.dart';
import 'package:cue/app/route_scaffold.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_rating_service.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/recommendation_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/features/library/rating_cards.dart';
import 'package:cue/features/library/library_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  group('Library rating cards', () {
    late CueDatabase db;
    late LibraryRatingService service;
    late RecommendationRepository recommendations;
    final now = DateTime.utc(2026, 10, 20);
    var changes = 0;

    Future<void> seed({
      String? rating,
      bool followUp = false,
      bool entry = true,
    }) async {
      await db
          .into(db.profiles)
          .insert(ProfilesCompanion.insert(id: 'synthetic', createdAt: now));
      await db
          .into(db.catalogTitles)
          .insert(
            CatalogTitlesCompanion.insert(
              id: 'invented:one',
              mediaKind: 'anime',
              titleEn: const Value('Invented card'),
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
                titleId: 'invented:one',
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
                titleId: 'invented:one',
                addedAt: now.subtract(const Duration(days: 8)),
              ),
            );
      }
    }

    Future<void> settle(WidgetTester t) async {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pumpAndSettle();
    }

    Future<void> pump(
      WidgetTester t, {
      bool followUp = false,
      double scale = 1,
    }) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: LibraryRatingCards(
                service: service,
                profileId: 'synthetic',
                followUp: followUp,
                onChanged: () => changes++,
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
        expect(find.widgetWithText(OutlinedButton, 'Loved'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Enjoyed'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'One-time'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Dropped'), findsOneWidget);
        await t.tap(find.text('Skip'));
        await settle(t);
        expect(changes, 0);
        await t.tap(find.text('Undo'));
        await settle(t);
        expect(find.text('Invented card'), findsOneWidget);
        final rows = await t.runAsync(() => db.select(db.userTitles).get());
        expect(rows!.single.rating, isNull);
        expect(changes, 0);
      },
    );

    testWidgets(
      'Loved saves evidence and Undo restores imported row and monotonic timestamp',
      (t) async {
        await t.runAsync(() => seed());
        final before = (await t.runAsync(() => db.select(db.userTitles).get()))!
            .single;
        await pump(t);
        await t.tap(find.text('Loved'));
        await settle(t);
        final after = (await t.runAsync(() => db.select(db.userTitles).get()))!
            .single;
        expect(after.rating, Rating.favourite.code);
        expect(after.note, before.note);
        expect(after.source, before.source);
        expect(changes, 1);
        await t.tap(find.text('Undo'));
        await settle(t);
        final restored = (await t.runAsync(
          () => db.select(db.userTitles).get(),
        ))!.single;
        expect(restored.copyWith(updatedAt: before.updatedAt), before);
        expect(restored.updatedAt.isAfter(after.updatedAt), isTrue);
        expect(changes, 2);
      },
    );

    testWidgets(
      'existing ratings require opt-in review and explicit overwrite confirmation',
      (t) async {
        await t.runAsync(() => seed(rating: Rating.okay.code));
        await pump(t);
        expect(find.text('Invented card'), findsNothing);
        await t.tap(find.text('Review existing ratings'));
        await settle(t);
        await t.tap(find.text('Enjoyed'));
        await t.pumpAndSettle();
        expect(find.text('Replace your existing rating?'), findsOneWidget);
        await t.tap(find.text('Keep rating'));
        await settle(t);
        expect(
          (await t.runAsync(() => db.select(db.userTitles).get()))!
              .single
              .rating,
          Rating.okay.code,
        );
        await t.tap(find.text('Enjoyed'));
        await t.pumpAndSettle();
        await t.tap(find.text('Replace rating'));
        await settle(t);
        expect(
          (await t.runAsync(() => db.select(db.userTitles).get()))!
              .single
              .rating,
          Rating.enjoyed.code,
        );
        await t.tap(find.text('Undo'));
        await settle(t);
        expect(
          (await t.runAsync(() => db.select(db.userTitles).get()))!
              .single
              .rating,
          Rating.okay.code,
        );
      },
    );

    testWidgets(
      "Haven't started and dismiss are optional, never consume or rate; manual review remains",
      (t) async {
        await t.runAsync(() => seed(followUp: true, entry: false));
        await pump(t, followUp: true);
        await t.tap(find.text("Haven't started"));
        await settle(t);
        expect(await t.runAsync(() => db.select(db.userTitles).get()), isEmpty);
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
        expect(await t.runAsync(() => db.select(db.userTitles).get()), isEmpty);
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
        await t.tap(find.text('Not for me'));
        await settle(t);
        final row = (await t.runAsync(() => db.select(db.userTitles).get()))!
            .single;
        expect(row.rating, Rating.dropped.code);
        expect(row.state, 'none');
        expect(row.actualWatchedAt, isNull);
        expect(await t.runAsync(() => db.select(db.shortlist).get()), isEmpty);
        await t.tap(find.text('Undo'));
        await settle(t);
        expect(await t.runAsync(() => db.select(db.userTitles).get()), isEmpty);
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
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              profileIdProvider.overrideWith((ref) async => 'synthetic'),
              clockProvider.overrideWithValue(() => now),
            ],
            child: const MaterialApp(home: Scaffold(body: LibraryScreen())),
          ),
        );
        await settle(t);
        await t.tap(find.text('Review shortlist picks'));
        await settle(t);
        expect(find.byType(LibraryRatingCards), findsOneWidget);
        await t.tap(find.text('Enjoyed'));
        await settle(t);
        await t.tap(find.byTooltip('Close rating cards'));
        await settle(t);
        expect(find.byType(LibraryRatingCards), findsNothing);
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
        final saved = (await t.runAsync(() => db.select(db.userTitles).get()))!
            .single;
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
          await t.ensureVisible(find.text('Loved'));
          await t.pumpAndSettle();
          final loved = find.widgetWithText(OutlinedButton, 'Loved');
          expect(t.widget<OutlinedButton>(loved).onPressed, isNotNull);
          expect(t.getSize(loved).height, greaterThanOrEqualTo(48));
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
          expect(
            (await t.runAsync(() => db.select(db.userTitles).get()))!
                .single
                .rating,
            Rating.favourite.code,
          );
          expect(t.takeException(), isNull);
        } finally {
          semantics?.dispose();
        }
      },
    );
  });
}
