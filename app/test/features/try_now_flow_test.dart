import 'package:cue/app/router.dart';
import 'package:cue/app/providers.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/data/try_now_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter/material.dart' show DropdownButton;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

void main() {
  testWidgets(
    'shortlist progressive saved options pick compare promote and undo',
    (tester) async {
      final db = memoryDb();
      addTearDown(db.close);
      final profile = (await ProfileRepository(db).ensureActive()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      await catalog.upsert([
        CatalogItemDto(
          item(
            1,
            title: 'Saved',
            year: 2020,
            genres: const ['Comedy'],
            score: 82,
            episodes: 12,
          ),
        ),
        CatalogItemDto(
          item(
            2,
            title: 'Saved',
            year: null,
            genres: const [],
            score: null,
            episodes: null,
          ),
        ),
      ]);
      final a = (await catalog.titleById('anilist:1'))!;
      final b = (await catalog.titleById('anilist:2'))!;
      final decisions = DecisionService(db);
      await decisions.tryNow(profile, a);
      await decisions.decide(profile, b, Decision.willTry);

      await pumpCue(tester, location: CueRoutes.willTry, db: db);
      expect(
        find.text('TRY NOW - priority marker only; not consumed'),
        findsOneWidget,
      );

      await tester.tap(find.text('Saved options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Tonight's picks"));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.text('Saved 1'), findsOneWidget);
      expect(find.text('Saved 2'), findsNothing);

      await tester.tap(find.text('Saved options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all saved'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      await tester.tap(find.text('Saved options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compare two saved titles'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Only catalog facts are shown. Cue does not choose a winner.',
        ),
        findsOneWidget,
      );
      expect(find.text('Catalog score'), findsOneWidget);
      final picker = find.byType(DropdownButton<String>).last;
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved 2').last);
      await tester.pumpAndSettle();
      expect(find.text('Not listed'), findsAtLeastNWidgets(3));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saved options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick from saved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show this saved title'));
      await tester.pumpAndSettle();
      expect(find.text('Saved 2'), findsOneWidget);
      expect(
        find.text('Showing Saved 2 from your saved picks.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Saved options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try now this title'));
      await tester.pumpAndSettle();
      expect(await TryNowRepository(db).isActive(profile, b.id), isTrue);
      expect(
        find.text('Saved for tonight and moved to the top of Will try.'),
        findsOneWidget,
      );
      expect(find.text('Undo Try now'), findsOneWidget);
      await tester.tap(find.text('Undo Try now'));
      await tester.pumpAndSettle();
      expect(await TryNowRepository(db).isActive(profile, b.id), isFalse);
      expect(await TryNowRepository(db).isActive(profile, a.id), isTrue);
    },
  );

  testWidgets('failed Try now persistence is shown without escaping', (
    tester,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final profile = (await ProfileRepository(db).ensureActive()).id;
    final catalog = CatalogRepository(db, FakeGateway());
    await catalog.upsert([CatalogItemDto(item(1, title: 'Saved'))]);
    final title = (await catalog.titleById('anilist:1'))!;
    await DecisionService(db).decide(profile, title, Decision.willTry);

    await pumpCue(
      tester,
      location: CueRoutes.willTry,
      db: db,
      overrides: [
        decisionServiceProvider.overrideWithValue(_FailingTryNowService(db)),
      ],
    );
    await tester.tap(find.text('Saved options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try now this title'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save that change. Please try again.'),
      findsOneWidget,
    );
  });
}

class _FailingTryNowService extends DecisionService {
  _FailingTryNowService(super.db);

  @override
  Future<DecisionResult> tryNow(String profileId, Title title) async {
    throw const DecisionFailed();
  }
}
