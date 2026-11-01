import 'package:cue/app/icons.dart';
import 'package:cue/app/providers.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/franchise_exclusion_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/details/details_sheet.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late CueDatabase db;
  late String profileId;
  setUp(() async {
    db = memoryDb();
    profileId = (await ProfileRepository(db).ensureActive()).id;
  });
  tearDown(() => db.close());

  Future<void> mount(
    WidgetTester tester,
    Title title, {
    double scale = 1,
    Future<void> Function(String, Title, String)? more,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          profileIdProvider.overrideWith((ref) async => profileId),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: DetailsActions(title: title, onMoreOfTrait: more),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('actions stay disclosed; unknown traits and franchise disabled', (
    tester,
  ) async {
    await mount(
      tester,
      const Title(id: 'local:1', kind: MediaKind.unknown, titleEn: 'Synthetic'),
    );
    expect(find.text('Wrong information'), findsNothing);
    await tap(tester, 'Refine or correct');
    await tap(tester, 'More like this');
    expect(
      find.text('No known genres or themes. More like this is unavailable.'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    final exclude = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Exclude franchise'),
    );
    expect(exclude.onPressed, isNull);
    expect(find.textContaining('will not guess'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(CueIcon), findsWidgets);
  });

  testWidgets(
    'More offers only actual traits, calls session hook without writes',
    (tester) async {
      final calls = <(String, String, String)>[];
      final before = await db.select(db.profileSettings).get();
      await mount(
        tester,
        const Title(
          id: 'anilist:123',
          kind: MediaKind.anime,
          titleEn: 'Synthetic',
          genres: ['Mystery'],
          tags: ['Found Family', ''],
        ),
        more: (profile, title, feature) async {
          calls.add((profile, title.id, feature));
        },
      );
      await tap(tester, 'Refine or correct');
      await tap(tester, 'More like this');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Mystery'), findsWidgets);
      expect(find.text('Found Family'), findsWidgets);
      expect(find.text('Emotional payoff'), findsNothing);
      await tap(tester, 'Mystery');
      await tap(tester, 'More Mystery');
      expect(calls, [(profileId, 'anilist:123', 'mystery')]);
      expect(find.textContaining('session only'), findsWidgets);
      expect(await db.select(db.profileSettings).get(), before);
      expect(await db.select(db.tagWeights).get(), isEmpty);
      expect(await db.select(db.moodStates).get(), isEmpty);
      expect(await db.select(db.userTitles).get(), isEmpty);
    },
  );

  testWidgets('franchise confirmation cancel, exclude, Undo and restore', (
    tester,
  ) async {
    const title = Title(
      id: 'tmdb:movie:123',
      kind: MediaKind.movie,
      titleEn: 'Synthetic',
      franchiseId: 'tmdb:c456',
    );
    await mount(tester, title);
    final repo = FranchiseExclusionRepository(db);
    await tap(tester, 'Refine or correct');
    await tap(tester, 'Exclude franchise');
    expect(await repo.activeScopes(profileId), isEmpty);
    expect(find.textContaining('Other adaptations'), findsOneWidget);
    await tap(tester, 'Cancel');
    expect(await repo.activeScopes(profileId), isEmpty);
    await tap(tester, 'Exclude franchise');
    await tap(tester, 'Exclude franchise');
    expect(await repo.activeScopes(profileId), {'tmdb:c456'});
    await tap(tester, 'Undo franchise preference');
    expect(await repo.activeScopes(profileId), isEmpty);
    await tap(tester, 'Exclude franchise');
    await tap(tester, 'Exclude franchise');
    await tap(tester, 'Restore franchise');
    expect(await repo.activeScopes(profileId), isEmpty);
    await tap(tester, 'Undo franchise preference');
    expect(await repo.activeScopes(profileId), {'tmdb:c456'});
  });

  testWidgets(
    '200% text scrolls with 48px targets and honest correction routes',
    (tester) async {
      await mount(
        tester,
        const Title(
          id: 'local:1',
          kind: MediaKind.unknown,
          titleEn: 'Synthetic',
        ),
        scale: 2,
      );
      await tap(tester, 'Refine or correct');
      for (final text in [
        'Refine or correct',
        'More like this',
        'Wrong information',
      ]) {
        final button = find.widgetWithText(TextButton, text);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
      await tap(tester, 'Wrong information');
      expect(find.textContaining('cannot repair provider'), findsOneWidget);
      expect(
        find.textContaining('No report or title is uploaded'),
        findsOneWidget,
      );
      expect(find.text('Open library review'), findsOneWidget);
      expect(
        find.text('This title has no saved library entry to edit.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '200% franchise confirmation scrolls; profile switch cancels save',
    (tester) async {
      const title = Title(
        id: 'tmdb:movie:123',
        kind: MediaKind.movie,
        titleEn: 'Synthetic',
        franchiseId: 'tmdb:c456',
      );
      final originalProfile = profileId;
      final other = (await ProfileRepository(db).create()).id;
      await mount(tester, title, scale: 2);
      await tap(tester, 'Refine or correct');
      await tap(tester, 'Exclude franchise');
      final confirm = find.text('Exclude franchise').last;
      await tester.ensureVisible(confirm);
      expect(tester.takeException(), isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DetailsActions)),
      );
      profileId = other;
      container.invalidate(profileIdProvider);
      await tester.pumpAndSettle();
      await tap(tester, 'Exclude franchise');
      final repo = FranchiseExclusionRepository(db);
      expect(await repo.activeScopes(originalProfile), isEmpty);
      expect(await repo.activeScopes(other), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
