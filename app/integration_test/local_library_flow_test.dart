import 'dart:async';
import 'dart:io';

import 'package:cue/app/providers.dart';
import 'package:cue/app/router.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/imports/import_job.dart';
import 'package:cue/features/imports/import_screen.dart';
import 'package:cue/imports/detect.dart';
import 'package:cue/imports/import_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/library_browser_test.dart' as browser;
import '../test/features/library_settings_test.dart' as settings;
import '../test/features/recommendation_history_test.dart' as recommendations;
import '../test/helpers.dart';
import '../test/imports/xlsx_test.dart' show buildXlsx;
import '../test/support/fakes.dart';

class _PausedGateway extends FakeGateway {
  _PausedGateway()
    : super(
        pages: {
          // Discover must not cache the second import chunk before it is matched.
          // All data and all responses in this test are synthetic.
          MediaKind.anime: [
            [item(90, title: 'Fresh story')],
          ],
        },
      ) {
    for (var i = 1; i <= 24; i++) {
      matchCatalog['invented import $i'] = [
        {...item(i), 'titleEn': 'Invented import $i'},
      ];
    }
  }

  final gate = Completer<void>();
  int requests = 0;

  @override
  Future<MatchResponse> match(
    List<MatchQuery> items, {
    List<int> malAnime = const [],
    List<int> malManga = const [],
  }) async {
    if (++requests == 2) await gate.future;
    return super.match(items, malAnime: malAnime, malManga: malManga);
  }
}

Future<void> _until(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 300 && !ready(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
  }
  expect(ready(), isTrue, reason: 'Flow did not finish within 30 seconds');
  await t.pumpAndSettle();
}

/// Run on a fresh, explicitly selected emulator. No live catalog, account,
/// user history, server deletion or existing on-device database is used.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('library browsing and removal on device', browser.main);
  group('library names and settings on device', settings.main);
  group('merged history and filters on device', recommendations.main);

  testWidgets(
    'Excel match survives navigation and database reopening without auto-import',
    (t) async {
      final directory = await Directory.systemTemp.createTemp(
        'cue-import-flow-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}library.sqlite',
      );
      var db = CueDatabase(NativeDatabase(file));
      final gateway = _PausedGateway();
      final profile = (await ProfileRepository(db).ensureActive()).id;
      final bytes = buildXlsx({
        'Anime': [
          ['Title', 'Status'],
          for (var i = 1; i <= 24; i++) ['Invented import $i', 'Finished'],
        ],
      });
      Future<void>? input;
      var inputDone = false;
      addTearDown(() async {
        if (!gateway.gate.isCompleted) {
          gateway.offline = true;
          gateway.gate.complete();
        }
        if (input != null) await input;
        await db.close();
        await directory.delete(recursive: true);
      });
      await pumpCue(t, db: db, gateway: gateway, location: CueRoutes.importer);
      final container = ProviderScope.containerOf(
        t.element(find.byType(ImportScreen)),
      );
      await t.runAsync(() async {
        input = t
            .state<ImportScreenState>(find.byType(ImportScreen))
            .readBytes(bytes, 'synthetic-history.xlsx')
            .whenComplete(() => inputDone = true);
      });
      await _until(
        t,
        () =>
            container.read(importJobProvider).done == 12 &&
            container.read(importJobProvider).running,
      );
      final saved = await ImportDraftStore(db).load(profile);
      expect(saved!.matched, hasLength(12));
      expect(saved.ready, isFalse);
      await t.tap(find.text('For you').last);
      await t.pumpAndSettle();
      expect(
        find.textContaining('Matching your import: 12 of 24'),
        findsOneWidget,
      );

      // Dispose the app while a real matcher request is suspended. Finish that
      // old request offline, then reopen the same persistent SQLite file.
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      gateway.offline = true;
      gateway.gate.complete();
      await _until(t, () => inputDone);
      await t.runAsync(() => input!);
      input = null;
      await db.close();
      db = CueDatabase(NativeDatabase(file));
      final resumed = _PausedGateway()..gate.complete();
      await pumpCue(t, db: db, gateway: resumed, location: CueRoutes.forYou);
      final restored = ProviderScope.containerOf(
        t.element(find.byType(ImportJobBanner)),
      );
      await _until(t, () => restored.read(importJobProvider).staged != null);
      expect((await LibraryRepository(db).signals(profile)).library, isEmpty);
      expect(
        find.textContaining('Your import is ready to review'),
        findsOneWidget,
      );
      expect(restored.read(importJobProvider).staged!.included, hasLength(24));
      await t.tap(find.textContaining('Your import is ready to review'));
      await t.pumpAndSettle();
      final confirm = find.text('Import 24');
      await t.scrollUntilVisible(
        confirm,
        400,
        scrollable: find
            .descendant(
              of: find.byType(ImportScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.tap(confirm);
      await _until(t, () => restored.read(importJobProvider).idle);
      expect(
        (await LibraryRepository(db).signals(profile)).library,
        hasLength(24),
      );
      await t.tap(find.text('For you').last);
      await _until(t, () => !restored.read(deckControllerProvider).loading);
      expect(restored.read(deckControllerProvider).cards, isNotEmpty);
      expect(
        restored
            .read(deckControllerProvider)
            .cards
            .every((card) => card.title.id == 'anilist:90'),
        isTrue,
      );
      final service = restored.read(importServiceProvider);
      final parsed = parseDetected(detect(bytes, 'synthetic-history.xlsx'));
      final duplicate = await service.commit(
        profile,
        await service.stage(profile, parsed, rawBytes: bytes),
      );
      expect(duplicate.alreadyImported, isTrue);
      expect(
        (await LibraryRepository(db).signals(profile)).library,
        hasLength(24),
      );
      final other = await ProfileRepository(db).create();
      expect((await LibraryRepository(db).signals(other.id)).library, isEmpty);
      expect(await ImportDraftStore(db).load(other.id), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
}
