import 'package:cue/app/providers.dart';
import 'package:cue/app/widgets.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/decisions.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/features/settings/settings_screen.dart';
import 'package:cue/imports/import_draft.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:cue/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await _settle(t);
}

class _Fixture {
  final db = memoryDb();
  late String first;
  late String second;
  late CodeStore codes;

  Future<void> seed() async {
    final profiles = ProfileRepository(db);
    first = (await profiles.create(displayName: 'First library')).id;
    second = (await profiles.create(displayName: 'Second library')).id;
    final catalog = CatalogRepository(db, FakeGateway());
    await catalog.upsert([
      CatalogItemDto(item(1, title: 'Other')),
      CatalogItemDto(item(2, title: 'Alpha')),
      CatalogItemDto(item(3, title: 'Cinema', kind: 'movie')),
      CatalogItemDto(item(4, title: 'Drama', kind: 'kdrama')),
      CatalogItemDto(item(5, title: 'Saved')),
      CatalogItemDto(item(6, title: 'Zebra')),
    ]);
    final lib = LibraryRepository(db);
    for (final i in [1, 2]) {
      await lib.saveEntry(first, 'anilist:$i', state: LibraryState.completed);
    }
    for (final i in [2, 3, 4, 6]) {
      await lib.saveEntry(second, 'anilist:$i', state: LibraryState.completed);
    }
    await DecisionService(
      db,
    ).decide(second, (await catalog.titleById('anilist:5'))!, Decision.willTry);
    await db
        .into(db.userTitles)
        .insert(
          UserTitlesCompanion.insert(
            profileId: second,
            titleId: 'missing:99',
            updatedAt: DateTime.now(),
          ),
        );
    await profiles.activate(first);
  }
}

void main() {
  late _Fixture fixture;

  setUp(() {
    fixture = _Fixture();
    addTearDown(fixture.db.close);
  });

  Future<void> open(
    WidgetTester t, {
    String? location,
    Size size = phoneLarge,
  }) async {
    await t.runAsync(fixture.seed);
    await pumpCue(
      t,
      db: fixture.db,
      size: size,
      location: location ?? '/settings/library',
    );
    await _settle(t);
    fixture.codes = ProviderScope.containerOf(
      t.element(find.byType(LibrarySettingsPage)),
    ).read(codeStoreProvider);
  }

  testWidgets('tap any library, browse by type and name without switching', (
    t,
  ) async {
    await open(t, size: desktop);
    await _tap(t, find.text('Second library'));
    expect(find.byType(LibraryContentsPage), findsOneWidget);
    expect(
      (await ProfileRepository(fixture.db).ensureActive()).id,
      fixture.first,
    );
    expect(
      find.text('Viewing only. Your active library is unchanged.'),
      findsOneWidget,
    );
    expect(
      find.text('6 titles, grouped by type and sorted A-Z.'),
      findsOneWidget,
    );
    expect(
      t.getTopLeft(find.text('Alpha 2')).dy,
      lessThan(t.getTopLeft(find.text('Zebra 6')).dy),
    );
    await _tap(t, find.byKey(const ValueKey('kind-movie')));
    expect(find.text('Cinema 3'), findsOneWidget);
    expect(find.text('Alpha 2'), findsNothing);
    await _tap(t, find.byKey(const ValueKey('kind-kdrama')));
    expect(find.text('Drama 4'), findsOneWidget);
    expect(find.text('Cinema 3'), findsNothing);
    await t.enterText(find.byType(TextField), 'DOES NOT EXIST');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump(const Duration(milliseconds: 500));
    await _settle(t);
    expect(find.text('No titles match these filters.'), findsOneWidget);
    await _tap(t, find.byTooltip('Clear search'));
    expect(
      t.widget<EditableText>(find.byType(EditableText)).controller.text,
      '',
    );
    await _tap(t, find.byKey(const ValueKey('kind-unknown')));
    expect(
      t
          .widget<CueChoiceChip>(find.byKey(const ValueKey('kind-unknown')))
          .selected,
      isTrue,
    );
    await t.scrollUntilVisible(
      find.text('missing:99'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(LibraryContentsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('missing:99'), findsOneWidget);
    expect(find.text('Catalog details unavailable, No status'), findsOneWidget);
    await _tap(t, find.text('Use this library'));
    expect(
      (await ProfileRepository(fixture.db).ensureActive()).id,
      fixture.second,
    );
    expect(find.text('This is your active library.'), findsOneWidget);
  });

  testWidgets('removal asks first and only changes the library being viewed', (
    t,
  ) async {
    await open(t);
    await _tap(t, find.text('Second library'));
    await _tap(t, find.byKey(const ValueKey('kind-anime')));
    await _tap(t, find.byTooltip('Remove Alpha 2'));
    expect(find.text('Remove Alpha 2?'), findsOneWidget);
    await _tap(t, find.text('Cancel'));
    final lib = LibraryRepository(fixture.db);
    expect(await lib.entry(fixture.second, 'anilist:2'), isNotNull);
    await _tap(t, find.byTooltip('Remove Alpha 2'));
    await _tap(t, find.text('Remove title'));
    expect(await lib.entry(fixture.second, 'anilist:2'), isNull);
    expect(await lib.entry(fixture.first, 'anilist:2'), isNotNull);
    expect(find.text('Alpha 2'), findsNothing);
    expect(
      find.text('5 titles, grouped by type and sorted A-Z.'),
      findsOneWidget,
    );
    expect(
      (await ProfileRepository(fixture.db).ensureActive()).id,
      fixture.first,
    );
    await _tap(t, find.byTooltip('Remove Saved 5'));
    await _tap(t, find.text('Remove title'));
    expect((await lib.signals(fixture.second)).shortlisted, isEmpty);
    expect(
      find.text('4 titles, grouped by type and sorted A-Z.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'delete an inactive library, including mood data, not its neighbour',
    (t) async {
      await open(t);
      await t.runAsync(() async {
        final now = DateTime.now();
        await fixture.db
            .into(fixture.db.moodStates)
            .insert(
              MoodStatesCompanion.insert(
                profileId: fixture.second,
                updatedAt: now,
              ),
            );
        await fixture.db
            .into(fixture.db.moodSessions)
            .insert(
              MoodSessionsCompanion.insert(
                id: 'synthetic-session',
                profileId: fixture.second,
                startedAt: now,
                endedAt: now,
                positives: 1,
                negatives: 0,
              ),
            );
        await fixture.codes.write(fixture.second, 'synthetic-local-code');
      });
      await _tap(t, find.byTooltip('Delete Second library'));
      expect(find.text('Delete Second library?'), findsOneWidget);
      await _tap(t, find.text('Cancel'));
      expect((await ProfileRepository(fixture.db).all()).length, 2);
      await _tap(t, find.byTooltip('Delete Second library'));
      await _tap(t, find.text('Delete library'));
      final profiles = await ProfileRepository(fixture.db).all();
      expect(profiles.single.id, fixture.first);
      expect(
        (await ProfileRepository(fixture.db).ensureActive()).id,
        fixture.first,
      );
      expect(await fixture.db.select(fixture.db.moodStates).get(), isEmpty);
      expect(await fixture.db.select(fixture.db.moodSessions).get(), isEmpty);
      expect(await fixture.codes.read(fixture.second), isNull);
      expect(
        (await LibraryRepository(fixture.db).contents(fixture.first)).length,
        2,
      );
      expect(find.text('Second library'), findsNothing);
    },
  );

  testWidgets(
    'delete active library clears its draft and uses remaining library',
    (t) async {
      await open(t);
      await t.runAsync(() async {
        await ImportDraftStore(fixture.db).create(
          fixture.first,
          const ParsedImport(
            sourceType: 'mal',
            adapterVersion: 'synthetic',
            records: [
              NormalizedRecord(
                sourceEntryKey: '1',
                title: 'Other 1',
                cueId: 'anilist:1',
              ),
            ],
          ),
          offlineOnly: true,
          dayFirst: false,
        );
      });
      await _tap(t, find.text('First library').last);
      await _tap(t, find.text('Delete this library'));
      await _tap(t, find.text('Delete library'));
      expect(
        (await ProfileRepository(fixture.db).all()).single.id,
        fixture.second,
      );
      expect(
        (await ProfileRepository(fixture.db).ensureActive()).id,
        fixture.second,
      );
      expect(await ImportDraftStore(fixture.db).load(fixture.first), isNull);
      expect(
        (await LibraryRepository(fixture.db).contents(fixture.second)).length,
        6,
      );
    },
  );

  testWidgets('deleting the last library creates a fresh empty one', (t) async {
    late String id;
    await t.runAsync(() async {
      id = (await ProfileRepository(
        fixture.db,
      ).create(displayName: 'Only library')).id;
    });
    await pumpCue(t, db: fixture.db, location: '/settings/library');
    await _settle(t);
    await _tap(t, find.byTooltip('Delete Only library'));
    await _tap(t, find.text('Delete library'));
    final profiles = await ProfileRepository(fixture.db).all();
    expect(profiles.length, 1);
    expect(profiles.single.id, isNot(id));
    expect(
      (await LibraryRepository(fixture.db).contents(profiles.single.id)),
      isEmpty,
    );
    expect(find.text('Only library'), findsNothing);
  });

  testWidgets('source counts exclude unticked and removed observations', (
    t,
  ) async {
    late String id;
    await t.runAsync(() async {
      id = (await ProfileRepository(fixture.db).ensureActive()).id;
      final catalog = CatalogRepository(fixture.db, FakeGateway());
      await catalog.upsert([CatalogItemDto(item(1)), CatalogItemDto(item(2))]);
      final imports = ImportService(fixture.db, catalog);
      const parsed = ParsedImport(
        sourceType: 'mal',
        adapterVersion: 'synthetic',
        records: [
          NormalizedRecord(
            sourceEntryKey: '1',
            title: 'Synthetic 1',
            cueId: 'anilist:1',
            state: LibraryState.completed,
          ),
          NormalizedRecord(
            sourceEntryKey: '2',
            title: 'Synthetic 2',
            cueId: 'anilist:2',
            state: LibraryState.completed,
            confirmed: false,
          ),
        ],
      );
      await imports.commit(
        id,
        await imports.stage(id, parsed, offlineOnly: true),
      );
    });
    await pumpCue(t, db: fixture.db, location: '/settings/library');
    await _settle(t);
    expect(find.text('1 titles'), findsOneWidget);
    await LibraryRepository(fixture.db).removeEntry(id, 'anilist:1');
    final container = ProviderScope.containerOf(
      t.element(find.byType(LibrarySettingsPage)),
    );
    container.read(libraryVersionProvider.notifier).bump();
    await _settle(t);
    expect(find.text('0 titles'), findsOneWidget);
  });
}
