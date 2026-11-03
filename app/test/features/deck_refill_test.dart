import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/mood_rules.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle, waitForDecisions;

class _ShortAnime extends DeckFiltersController {
  @override
  DeckFilters build() =>
      parseMood('short anime').applyTo(const DeckFilters(), 'short anime');
}

void main() {
  testWidgets(
    'exact short picks precede nearest labelled fallback, watched works stay excluded, and new exact metadata recovers',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            [
              item(1),
              item(2, episodes: 14, score: 40),
              item(3, episodes: 16, score: 99),
              item(4, episodes: 100, score: 100),
              item(5, episodes: null),
            ],
          ],
        },
      );
      final catalog = CatalogRepository(db, gateway);
      await t.runAsync(() async {
        final profile = (await ProfileRepository(db).ensureActive()).id;
        final service = ImportService(db, catalog);
        await catalog.upsert([CatalogItemDto(item(6, episodes: 14))]);
        await service.commit(
          profile,
          await service.stage(
            profile,
            const ParsedImport(
              sourceType: 'generic_csv',
              adapterVersion: '1',
              records: [
                NormalizedRecord(
                  sourceEntryKey: 'watched',
                  title: 'Synthetic 6',
                  state: LibraryState.completed,
                ),
              ],
            ),
            offlineOnly: true,
          ),
        );
      });
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_ShortAnime.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final controller = container.read(deckControllerProvider.notifier);
      expect(container.read(deckControllerProvider).top!.title.id, 'anilist:1');
      expect(container.read(deckControllerProvider).lengthFallback, isFalse);
      final decision = controller.decide(Decision.notNow);
      await waitForDecisions(t, 1);
      await decision;
      var state = container.read(deckControllerProvider);
      expect(state.lengthFallback, isTrue);
      expect(state.cards.map((c) => c.title.episodes), [14, 16, 100]);
      expect(
        state.cards.every(
          (c) => c.reason.startsWith('Longer than requested -'),
        ),
        isTrue,
      );
      final longer = controller.decide(Decision.notNow);
      await waitForDecisions(t, 2);
      await longer;
      final undo = controller.undo();
      await settle(t);
      await undo;
      state = container.read(deckControllerProvider);
      expect(state.top!.title.id, 'anilist:2');
      expect(
        state.top!.reason,
        startsWith('Longer than requested - 14 episodes.'),
      );
      gateway.offline = true;
      final cached = controller.redeal();
      await settle(t);
      await cached;
      expect(container.read(deckControllerProvider).top!.title.id, 'anilist:2');
      await t.runAsync(() => catalog.upsert([CatalogItemDto(item(7))]));
      final recovered = controller.redeal();
      await settle(t);
      await recovered;
      state = container.read(deckControllerProvider);
      expect(state.lengthFallback, isFalse);
      expect(state.top!.title.id, 'anilist:7');
      expect(state.top!.reason, isNot(startsWith('Longer than requested')));
      expect(find.text('Review filters'), findsNothing);
    },
  );

  testWidgets(
    'short anime fills beyond watched and long first-page titles and keeps refilling after swipes',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            [
              for (var i = 1; i <= 4; i++) item(i, idMal: 70 + i),
              for (var i = 10; i < 30; i++) item(i, episodes: 24),
              for (var i = 101; i <= 106; i++) item(i),
              item(99, episodes: null),
            ],
            [],
            [for (var i = 201; i <= 220; i++) item(i)],
            [for (var i = 301; i <= 320; i++) item(i)],
            [for (var i = 401; i <= 420; i++) item(i)],
          ],
        },
      );
      final catalog = CatalogRepository(db, gateway);
      await t.runAsync(() async {
        final profile = (await ProfileRepository(db).ensureActive()).id;
        await catalog.upsert([
          for (var i = 71; i <= 74; i++)
            CatalogItemDto(item(i, provider: 'mal', providerKind: 'anime')),
        ]);
        final service = ImportService(db, catalog);
        await service.commit(
          profile,
          await service.stage(
            profile,
            ParsedImport(
              sourceType: 'mal_xml',
              adapterVersion: '1',
              records: [
                for (var i = 71; i <= 74; i++)
                  NormalizedRecord(
                    sourceEntryKey: '$i',
                    title: 'Invented imported alias $i',
                    kind: MediaKind.anime,
                    malId: i,
                    state: LibraryState.completed,
                  ),
              ],
            ),
            offlineOnly: true,
          ),
        );
      });
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_ShortAnime.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final shown = <String>{};
      for (var i = 0; i < 28; i++) {
        final state = container.read(deckControllerProvider);
        expect(
          state.cards,
          isNotEmpty,
          reason: 'Must not stop after the first six picks',
        );
        expect(find.text('Review filters'), findsNothing);
        for (final card in state.cards) {
          expect(card.title.kind, MediaKind.anime);
          expect(card.title.episodes, inInclusiveRange(1, 13));
          expect(card.title.id.startsWith('mal:'), isFalse);
          expect([
            'anilist:1',
            'anilist:2',
            'anilist:3',
            'anilist:4',
          ], isNot(contains(card.title.id)));
        }
        expect(shown.add(state.top!.title.id), isTrue);
        final choice = container
            .read(deckControllerProvider.notifier)
            .decide(Decision.notNow);
        await waitForDecisions(t, i + 1);
        await choice;
      }
      expect(gateway.calls, contains('discover:anime:-:4'));
      expect(container.read(deckFiltersProvider).shortOnly, isTrue);
      expect(
        await t.runAsync(() => catalog.findByIdentity('anilist', '1')),
        'mal:anime:71',
      );
    },
  );

  testWidgets(
    'a bounded batch is not exhaustion: longer picks show while later exact pages are fetched in the background',
    (t) async {
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            for (var page = 1; page <= 6; page++)
              [item(page, episodes: page <= 4 ? 24 : 12)],
          ],
        },
      );
      await pumpCue(
        t,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_ShortAnime.new)],
      );
      await settle(t);
      // One bounded batch, then a background continuation reaches pages 5-6.
      expect(gateway.calls, hasLength(DeckController.maxRefillRounds + 2));
      expect(find.text('Review filters'), findsNothing);
      expect(find.textContaining('More catalog pages remain'), findsNothing);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final state = container.read(deckControllerProvider);
      expect(state.cards.take(2).map((c) => c.title.id).toSet(), {
        'anilist:5',
        'anilist:6',
      });
      expect(state.lengthFallback, isFalse);
      expect(
        state.cards
            .skip(2)
            .every((c) => c.reason.startsWith('Longer than requested -')),
        isTrue,
      );
      expect(container.read(deckFiltersProvider).shortOnly, isTrue);
    },
  );

  testWidgets(
    'offline deals cached nearest picks, not Review filters, and retries failed pages automatically',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway(
        offline: true,
        pages: {
          MediaKind.anime: [
            [item(2)],
          ],
        },
      );
      await t.runAsync(
        () => CatalogRepository(
          db,
          gateway,
        ).upsert([CatalogItemDto(item(1, episodes: 24))]),
      );
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_ShortAnime.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      var state = container.read(deckControllerProvider);
      expect(find.text('Review filters'), findsNothing);
      expect(state.top!.title.id, 'anilist:1');
      expect(state.top!.reason, startsWith('Longer than requested - 24'));
      expect(state.offline, isTrue);
      gateway.offline = false;
      // No tap: the automatic retry picks up the connection.
      await t.pump(DeckController.retryBase + const Duration(seconds: 1));
      await settle(t);
      state = container.read(deckControllerProvider);
      expect(state.top!.title.id, 'anilist:2');
      expect(state.offline, isFalse);
      expect(
        gateway.calls.where((c) => c == 'discover:anime:-:1'),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'terminal short-anime exhaustion offers a labelled longer anime, not a filter dead-end',
    (t) async {
      await pumpCue(
        t,
        gateway: FakeGateway(
          pages: {
            MediaKind.anime: [
              [item(1, episodes: 24)],
            ],
          },
        ),
        overrides: [deckFiltersProvider.overrideWith(_ShortAnime.new)],
      );
      await settle(t);
      expect(find.text('Review filters'), findsNothing);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final state = container.read(deckControllerProvider);
      expect(state.lengthFallback, isTrue);
      expect(state.top!.title.episodes, 24);
      expect(
        state.top!.reason,
        startsWith('Longer than requested - 24 episodes.'),
      );
      expect(container.read(deckFiltersProvider).shortOnly, isTrue);
    },
  );
}
