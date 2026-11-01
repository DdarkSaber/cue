import 'dart:convert';

import 'package:cue/app/providers.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/diagnostics/technical_diagnostics.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/mood_rules.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../diagnostics/technical_diagnostics_test.dart' show ConsentMemory;
import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle;

class _AiFailGateway extends FakeGateway {
  _AiFailGateway()
    : super(
        pages: {
          MediaKind.anime: [
            [
              item(1),
              item(2, genres: ['Comedy']),
            ],
          ],
        },
      );
  bool failHints = false;
  @override
  Future<(List<String>, List<String>)> moodHints(
    String text,
    List<String> allowed,
  ) async {
    if (failHints) throw const CatalogUnavailable('not_configured');
    return super.moodHints(text, allowed);
  }
}

void main() {
  testWidgets(
    'diagnostics sharing reset hides old code and waits for new uploads',
    (t) async {
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        ConsentMemory(),
        clientFactory: () => MockClient(
          (r) async => http.Response(
            jsonEncode({
              'accepted': 1,
              'token': 'A' * 43,
              'expiresAt': DateTime.utc(2030).millisecondsSinceEpoch,
            }),
            200,
          ),
        ),
      );
      addTearDown(service.dispose);
      await service.load();
      await service.setEnabled(true);
      service.finish(
        service.begin(DiagnosticProvider.local, DiagnosticOperation.settings),
        DiagnosticStatus.ok,
        DiagnosticError.none,
      );
      await service.upload();
      final db = memoryDb();
      addTearDown(db.close);
      await t.runAsync(() => db.customSelect('SELECT 1').get());
      await pumpCue(
        t,
        db: db,
        location: '/settings/privacy',
        size: desktop,
        overrides: [technicalDiagnosticsProvider.overrideWithValue(service)],
      );
      final show = find.text('Show recovery code');
      await t.ensureVisible(show);
      await t.pumpAndSettle();
      await t.tap(show);
      await t.pumpAndSettle();
      expect(find.text('A' * 43), findsOneWidget);
      final reset = find.text('Start new diagnostics session');
      await t.ensureVisible(reset);
      await t.pumpAndSettle();
      await t.tap(reset);
      await t.pumpAndSettle();
      expect(service.enabled, isTrue);
      expect(service.recoveryCode, isNull);
      expect(find.text('A' * 43), findsNothing);
      expect(find.text('Show recovery code'), findsNothing);
    },
  );

  testWidgets(
    'large one-kind cache still fetches missing formats and explores them',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway(
        pages: {
          for (final k in [
            MediaKind.anime,
            MediaKind.movie,
            MediaKind.series,
            MediaKind.kdrama,
          ])
            k: [
              [
                for (var i = 0; i < 5; i++)
                  item(1000 + k.index * 10 + i, kind: k.name, score: 50),
              ],
            ],
        },
      );
      await t.runAsync(
        () => CatalogRepository(db, gateway).upsert([
          for (var i = 0; i < 50; i++)
            CatalogItemDto(item(i, kind: 'manhwa', score: 95)),
        ]),
      );
      await pumpCue(t, db: db, gateway: gateway);
      await settle(t);
      final c = ProviderScope.containerOf(t.element(find.byType(DeckScreen)));
      final cards = c.read(deckControllerProvider).cards;
      expect(
        cards.map((c) => c.title.kind).toSet().length,
        greaterThanOrEqualTo(4),
      );
      for (final k in [
        MediaKind.anime,
        MediaKind.movie,
        MediaKind.series,
        MediaKind.kdrama,
      ]) {
        expect(gateway.calls, contains('discover:${k.name}:-:1'));
      }
      c
          .read(deckFiltersProvider.notifier)
          .apply(const DeckFilters(kinds: {MediaKind.movie}));
      await t.pumpAndSettle();
      await settle(t);
      expect(
        c
            .read(deckControllerProvider)
            .cards
            .every((c) => c.title.kind == MediaKind.movie),
        isTrue,
      );
    },
  );

  testWidgets(
    'review from inactive library resolves its history, not active neighbour',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway();
      late String first, second;
      await t.runAsync(() async {
        final repo = ProfileRepository(db);
        first = (await repo.create(displayName: 'Active synthetic')).id;
        second = (await repo.create(displayName: 'Review synthetic')).id;
        final service = ImportService(db, CatalogRepository(db, gateway));
        await service.commit(
          second,
          await service.stage(
            second,
            const ParsedImport(
              sourceType: 'generic_csv',
              adapterVersion: '1',
              records: [
                NormalizedRecord(
                  sourceEntryKey: 'invented',
                  title: 'Unmatched invented story',
                ),
              ],
            ),
            offlineOnly: true,
          ),
        );
        gateway.searchResults['unmatched invented story'] = [item(88)];
        await repo.activate(first);
      });
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        location: '/settings/library/$second',
        size: desktop,
      );
      expect(find.text('Needs review (1)'), findsOneWidget);
      await t.tap(find.text('Unmatched invented story'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('This one'));
      await t.tap(find.text('This one'));
      await t.pumpAndSettle();
      final check = await t.runAsync(() async {
        return (
          (await LibraryRepository(db).signals(second)).library,
          (await LibraryRepository(db).signals(first)).library,
          (await ProfileRepository(db).ensureActive()).id,
        );
      });
      expect(check!.$1.keys, contains('anilist:88'));
      expect(check.$2, isEmpty);
      expect(check.$3, first);
      expect(find.text('Needs review (1)'), findsNothing);
    },
  );

  testWidgets(
    'Tell me AI stays opt-in; toggling sends current synthetic phrase and handles failure',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = _AiFailGateway()..hints = (['comedy'], ['horror']);
      await pumpCue(t, db: db, gateway: gateway);
      final c = ProviderScope.containerOf(t.element(find.byType(DeckScreen)));
      const text = 'wholesome anime with teleporting potatoes';
      c
          .read(deckFiltersProvider.notifier)
          .apply(parseMood(text).applyTo(const DeckFilters(), text));
      await t.pumpAndSettle();
      expect(gateway.moodHintCalls, isEmpty);
      await c
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(smartMoodText: true));
      await t.pumpAndSettle();
      expect(gateway.moodHintCalls, [text]);
      expect(
        c.read(deckControllerProvider).notice,
        contains('preference hints'),
      );
      gateway.failHints = true;
      c
          .read(deckFiltersProvider.notifier)
          .apply(
            parseMood('tense anime')
                .applyTo(c.read(deckFiltersProvider), 'tense anime'),
          );
      await t.pumpAndSettle();
      expect(c.read(deckControllerProvider).notice, contains('unavailable'));
      await c
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(smartMoodText: false));
      await t.pumpAndSettle();
      expect(
        c.read(deckControllerProvider).notice,
        isNot(contains('Smarter mood')),
      );
    },
  );

  testWidgets(
    'diagnostics switch needs consent and off discards queued events',
    (t) async {
      final service = TechnicalDiagnostics(
        'https://synthetic.test',
        ConsentMemory(),
      );
      addTearDown(service.dispose);
      await service.load();
      await pumpCue(
        t,
        location: '/settings/privacy',
        size: desktop,
        overrides: [technicalDiagnosticsProvider.overrideWithValue(service)],
      );
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Share technical diagnostics',
      );
      await t.ensureVisible(toggle);
      await t.pumpAndSettle();
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(service.enabled, isFalse);
      expect(find.text('Share technical diagnostics?'), findsOneWidget);
      await t.ensureVisible(find.text('Enable diagnostics'));
      await t.tap(find.text('Enable diagnostics'));
      await t.pumpAndSettle();
      expect(service.enabled, isTrue);
      service.finish(
        service.begin(DiagnosticProvider.cue, DiagnosticOperation.match),
        DiagnosticStatus.ok,
        DiagnosticError.none,
      );
      await t.pump();
      expect(service.pendingCount, 1);
      await t.ensureVisible(toggle);
      await t.pumpAndSettle();
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(service.enabled, isFalse);
      expect(service.pendingCount, 0);
    },
  );
}
