import 'package:cue/app/router.dart';
import 'package:cue/app/providers.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers.dart';
import '../support/fakes.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

class _FailingProfileRepository extends ProfileRepository {
  _FailingProfileRepository(super.db);
  bool failSave = false;

  @override
  Future<void> saveSettings(String profileId, AppSettings settings) {
    if (failSave) throw StateError('Synthetic save failure');
    return super.saveSettings(profileId, settings);
  }
}

void main() {
  testWidgets('name save failure is visible and does not report success', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final repo = _FailingProfileRepository(db);
    late String id;
    await t.runAsync(() async {
      id = (await repo.ensureActive()).id;
      await repo.saveSettings(
        id,
        (await repo.loadSettings(id)).copyWith(displayName: 'Original'),
      );
      repo.failSave = true;
    });
    await pumpCue(
      t,
      db: db,
      location: '/settings/library',
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    );
    await t.enterText(find.byType(TextField), 'Not persisted');
    await t.tap(find.widgetWithText(OutlinedButton, 'Save'));
    await settle(t);
    expect(
      find.text('Could not save the library name. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Library name saved.'), findsNothing);
    expect((await repo.loadSettings(id)).displayName, 'Original');
  });

  testWidgets('library name loads, saves, clears and survives reopening', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final repo = ProfileRepository(db);
    late String id;
    await t.runAsync(() async {
      id = (await repo.ensureActive()).id;
      await repo.saveSettings(
        id,
        (await repo.loadSettings(id)).copyWith(displayName: 'Original'),
      );
    });
    await pumpCue(t, db: db, location: '/settings/library');
    await settle(t);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Original',
    );
    await t.enterText(find.byType(TextField), '  Renamed  ');
    await t.tap(find.widgetWithText(OutlinedButton, 'Save'));
    await settle(t);
    expect(find.text('Library name saved.'), findsOneWidget);
    expect(await t.runAsync(() => repo.loadSettings(id)), isNotNull);
    expect((await repo.loadSettings(id)).displayName, 'Renamed');
    expect(find.text('Renamed'), findsWidgets);

    await t.pumpWidget(const SizedBox.shrink());
    await settle(t);
    await pumpCue(t, db: db, location: '/settings/library');
    await settle(t);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Renamed',
    );
    await t.enterText(find.byType(TextField), '');
    await t.tap(find.widgetWithText(OutlinedButton, 'Save'));
    await settle(t);
    expect((await repo.loadSettings(id)).displayName, isNull);
    expect(find.text('Renamed'), findsNothing);
  });

  test('queued preference edits keep the correct library', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final repo = ProfileRepository(db);
    final first = (await repo.ensureActive()).id;
    final second = (await repo.create()).id;
    await repo.activate(first);
    final c = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    final save = c
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(displayName: 'First only'));
    final toggle = c
        .read(settingsProvider.notifier)
        .change((s) => s.copyWith(haptics: false));
    await repo.activate(second);
    c.invalidate(profileIdProvider);
    await Future.wait([save, toggle]);
    await c.read(settingsProvider.future);
    expect((await repo.loadSettings(first)).displayName, 'First only');
    expect((await repo.loadSettings(first)).haptics, isFalse);
    expect((await repo.loadSettings(second)).displayName, isNull);
    expect(c.read(currentSettingsProvider).displayName, isNull);
  });

  testWidgets('empty Library says why and offers import', (t) async {
    await pumpCue(t, location: CueRoutes.library);
    await settle(t);
    expect(
      find.text(
        'Your history belongs here. Bring a list, or keep discovering.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Import a list'));
    await settle(t);
    expect(find.text('Upload any file'), findsOneWidget);
    expect(find.text('MyAnimeList'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
  });

  testWidgets('Library lists entries, revisit and restore', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await t.runAsync(() async {
      final id = (await ProfileRepository(db).ensureActive()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      await catalog.upsert([
        CatalogItemDto(item(1, title: 'Kept')),
        CatalogItemDto(item(2, title: 'Hidden')),
      ]);
      await LibraryRepository(db).saveEntry(
        id,
        'anilist:1',
        state: LibraryState.completed,
        rating: Rating.rewatched,
      );
      await DecisionService(db).decide(
        id,
        (await catalog.titleById('anilist:2'))!,
        Decision.notInterested,
      );
    });
    await pumpCue(t, db: db, location: CueRoutes.library);
    await settle(t);
    expect(find.text('Kept 1'), findsOneWidget);
    expect(find.text('1 to rewatch.'), findsOneWidget);
    expect(find.textContaining('Taste: 1 of 20 ratings'), findsOneWidget);
    expect(find.text('Hidden from your deck'), findsOneWidget);
    // The Add a title button moved the list down; bring Restore on screen.
    await t.ensureVisible(find.widgetWithText(OutlinedButton, 'Restore'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(OutlinedButton, 'Restore'));
    await settle(t);
    expect(find.text('Hidden from your deck'), findsNothing);
  });

  testWidgets('Will try shows the shortlist with explicit Next story', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await t.runAsync(() async {
      final id = (await ProfileRepository(db).ensureActive()).id;
      final catalog = CatalogRepository(db, FakeGateway());
      await catalog.upsert([
        CatalogItemDto(item(1, title: 'First')),
        CatalogItemDto(item(2, title: 'Second')),
      ]);
      final d = DecisionService(db);
      await d.decide(
        id,
        (await catalog.titleById('anilist:1'))!,
        Decision.willTry,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await d.decide(
        id,
        (await catalog.titleById('anilist:2'))!,
        Decision.willTry,
      );
    });
    await pumpCue(t, db: db, location: CueRoutes.willTry);
    await settle(t);
    expect(find.text('1 of 2'), findsOneWidget);
    await t.tap(find.text('Next story'));
    await settle(t);
    expect(find.text('2 of 2'), findsOneWidget);
    await t.tap(find.widgetWithText(OutlinedButton, 'Watched'));
    await settle(t);
    expect(find.text('1 of 1'), findsOneWidget);
  });

  testWidgets('Settings sections open, and swipe actions can be swapped', (
    t,
  ) async {
    await pumpCue(t, location: CueRoutes.settings);
    await settle(t);
    for (final s in [
      'This library',
      'Recommendation preferences',
      'Swipe actions',
      'Privacy and data',
      'About Cue',
    ]) {
      expect(find.text(s), findsOneWidget);
    }
    await t.tap(find.text('Swipe actions'));
    await settle(t);
    await t.ensureVisible(find.text('Swap left and right'));
    await t.pumpAndSettle();
    await t.tap(find.text('Swap left and right'));
    await settle(t);
    // The header scrolled away; the nav item returns to the Settings root.
    await t.tap(find.text('Settings').last);
    await settle(t);
    expect(find.text('Customised'), findsOneWidget);
  });

  testWidgets('adult titles need an explicit confirmation', (t) async {
    await pumpCue(t, location: '${CueRoutes.settings}/preferences');
    await settle(t);
    await t.ensureVisible(find.text('Show adult-tagged titles'));
    await t.pumpAndSettle();
    await t.tap(find.text('Show adult-tagged titles'));
    await settle(t);
    expect(find.text('Show adult-tagged titles?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    final sw = t.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Show adult-tagged titles'),
    );
    expect(sw.value, isFalse);
  });

  testWidgets('delete library asks first and leaves a fresh one', (t) async {
    await pumpCue(t, location: '${CueRoutes.settings}/privacy');
    await settle(t);
    await t.ensureVisible(find.text('Delete this library'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete this library'));
    await settle(t);
    expect(find.text('Delete this library?'), findsOneWidget);
    await t.tap(find.text('Delete library'));
    await settle(t);
    expect(find.textContaining('A fresh, empty one is ready'), findsOneWidget);
  });

  testWidgets('This library lists what it holds per source', (t) async {
    final db = memoryDb();
    addTearDown(db.close);
    await t.runAsync(() async {
      final id = (await ProfileRepository(db).ensureActive()).id;
      final catalog = CatalogRepository(db, sampleGateway());
      await catalog.upsert([CatalogItemDto(item(1))]);
      await DecisionService(
        db,
      ).decide(id, (await catalog.titleById('anilist:1'))!, Decision.willTry);
    });
    await pumpCue(t, db: db, location: '/settings/library');
    await settle(t);
    expect(find.text('What is in this library'), findsOneWidget);
    expect(find.text('Deck swipes'), findsOneWidget);
    expect(find.text('1 titles'), findsOneWidget);
  });
}
