import 'package:cue/app/icons.dart';
import 'package:cue/app/providers.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/franchise_exclusion_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/features/settings/franchise_exclusions_section.dart';
import 'package:cue/domain/models/title.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const member = Title(
  id: 'tmdb:movie:123',
  kind: MediaKind.movie,
  titleEn: 'Synthetic member',
  franchiseId: 'tmdb:c456',
);

void main() {
  late CueDatabase db;
  late String profileId;
  late FranchiseExclusionRepository repo;
  String? managedProfile;

  setUp(() async {
    db = memoryDb();
    profileId = (await ProfileRepository(db).ensureActive()).id;
    repo = FranchiseExclusionRepository(db);
  });
  tearDown(() => db.close());

  Future<void> waitForCollections(WidgetTester tester) async {
    final scopes = await repo.activeScopes(managedProfile ?? profileId);
    final header = find.text('Excluded franchises (${scopes.length})');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (header.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      // WASM database work needs real browser event-loop turns, not merely
      // animation frames; pumpAndSettle may finish before the query returns.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(header, findsOneWidget, reason: 'Collection query must finish');
  }

  Future<void> mount(
    WidgetTester tester, {
    double scale = 1,
    String? managedProfileId,
  }) async {
    managedProfile = managedProfileId;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          profileIdProvider.overrideWith((ref) async => profileId),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: FranchiseExclusionsSection(
                    profileId: managedProfileId,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForCollections(tester);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await waitForCollections(tester);
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    await waitForCollections(tester);
  }

  testWidgets(
    'collapsed count and factual cached names, never guessed franchise',
    (tester) async {
      await repo.exclude(profileId, member);
      final catalog = CatalogRepository(db, FakeGateway());
      await catalog.upsert([
        CatalogItemDto(
          item(
            123,
            provider: 'tmdb',
            providerKind: 'movie',
            kind: 'movie',
            title: 'Synthetic known',
            franchiseKey: 'tmdb:c456',
          ),
        ),
        CatalogItemDto(
          item(
            124,
            provider: 'cinemeta',
            kind: 'movie',
            title: 'Unproven alias',
            franchiseKey: 'tmdb:c456',
          ),
        ),
        CatalogItemDto(
          item(
            125,
            provider: 'tmdb',
            providerKind: 'movie',
            kind: 'movie',
            title: 'Guessed Part 2',
          ),
        ),
      ]);
      await mount(tester);
      expect(find.text('Excluded franchises (1)'), findsOneWidget);
      expect(find.text('TMDB collection 456'), findsNothing);
      await tap(tester, 'Excluded franchises (1)');
      expect(find.text('TMDB collection 456'), findsOneWidget);
      expect(find.text('Cached members: Synthetic known 123'), findsOneWidget);
      expect(find.textContaining('Unproven alias'), findsNothing);
      expect(find.textContaining('Guessed Part'), findsNothing);
      expect(
        find.textContaining('Resetting swipe history keeps'),
        findsOneWidget,
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(CueIcon), findsWidgets);
      expect(await repo.activeScopes(profileId), {'tmdb:c456'});
    },
  );

  testWidgets(
    'survives missing title cache; restore confirmation Cancel and Undo',
    (tester) async {
      await repo.exclude(profileId, member);
      await mount(tester);
      await tap(tester, 'Excluded franchises (1)');
      expect(
        find.text('No verified member names cached on this device.'),
        findsOneWidget,
      );
      await tap(tester, 'Restore TMDB collection 456');
      expect(await repo.activeScopes(profileId), {'tmdb:c456'});
      await tap(tester, 'Cancel');
      expect(await repo.activeScopes(profileId), {'tmdb:c456'});
      await tap(tester, 'Restore TMDB collection 456');
      await tap(tester, 'Restore collection');
      expect(await repo.activeScopes(profileId), isEmpty);
      expect(find.text('Excluded franchises (0)'), findsOneWidget);
      expect(
        find.text('No excluded franchises in this library.'),
        findsOneWidget,
      );
      await tap(tester, 'Undo collection restoration');
      expect(await repo.activeScopes(profileId), {'tmdb:c456'});
      expect(find.text('Excluded franchises (1)'), findsOneWidget);
    },
  );

  testWidgets('Undo does not overwrite a newer synced preference', (
    tester,
  ) async {
    await repo.exclude(profileId, member);
    await mount(tester);
    await tap(tester, 'Excluded franchises (1)');
    await tap(tester, 'Restore TMDB collection 456');
    await tap(tester, 'Restore collection');
    await repo.restore(profileId, 'tmdb:c456');
    await tap(tester, 'Undo collection restoration');
    expect(await repo.activeScopes(profileId), isEmpty);
    expect(
      find.text('A newer preference was kept. Nothing was overwritten.'),
      findsOneWidget,
    );
  });

  testWidgets(
    '200% scrolling, accessible targets, profile switch cancels restore',
    (tester) async {
      final a = profileId;
      final b = (await ProfileRepository(db).create()).id;
      await repo.exclude(a, member);
      await mount(tester, scale: 2);
      await tap(tester, 'Excluded franchises (1)');
      final restore = find.widgetWithText(
        TextButton,
        'Restore TMDB collection 456',
      );
      expect(tester.getSize(restore).height, greaterThanOrEqualTo(48));
      await tap(tester, 'Restore TMDB collection 456');
      await tester.ensureVisible(find.text('Restore collection'));
      expect(tester.takeException(), isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FranchiseExclusionsSection)),
      );
      profileId = b;
      container.invalidate(profileIdProvider);
      await tester.pumpAndSettle();
      await tap(tester, 'Restore collection');
      expect(await repo.activeScopes(a), {'tmdb:c456'});
      expect(await repo.activeScopes(b), isEmpty);
      expect(find.text('Excluded franchises (0)'), findsOneWidget);
      expect(find.text('Undo collection restoration'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit managed profile isolated; swipe reset preserves preference',
    (tester) async {
      final a = profileId;
      final b = (await ProfileRepository(db).create()).id;
      await repo.exclude(a, member);
      await LibraryRepository(db).resetSwipes(a);
      expect(await repo.activeScopes(a), {'tmdb:c456'});
      profileId = b;
      await mount(tester, managedProfileId: a);
      await tap(tester, 'Excluded franchises (1)');
      await tap(tester, 'Restore TMDB collection 456');
      await tap(tester, 'Restore collection');
      expect(await repo.activeScopes(a), isEmpty);
      expect(await repo.activeScopes(b), isEmpty);
      await tap(tester, 'Undo collection restoration');
      expect(await repo.activeScopes(a), {'tmdb:c456'});
      expect(await repo.activeScopes(b), isEmpty);
    },
  );
}
