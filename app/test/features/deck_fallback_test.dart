import 'dart:async';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_fallback.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:cue/features/deck/swipe_deck.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle, waitForDecisions;

class _Comedy extends DeckFiltersController {
  @override
  DeckFilters build() => const DeckFilters(genres: {'comedy'});
}

class _ComedyFromIndia extends DeckFiltersController {
  @override
  DeckFilters build() =>
      const DeckFilters(genres: {'comedy'}, countries: {'IN'});
}

/// Every discoverable kind answers; only anime has titles.
FakeGateway _anime(
  List<List<Map<String, dynamic>>> pages, {
  bool offline = false,
}) => FakeGateway(
  offline: offline,
  pages: {
    for (final k in MediaKind.discoverable)
      if (k != MediaKind.anime) k: const [[]],
    MediaKind.anime: pages,
  },
);

/// Holds every discover call until [gate] completes.
class _SlowGateway extends FakeGateway {
  _SlowGateway(Map<MediaKind, List<List<Map<String, dynamic>>>> pages)
    : super(pages: pages);
  final gate = Completer<void>();

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
  }) async {
    await gate.future;
    return super.discover(kind, mood: mood, page: page, sort: sort);
  }
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(DeckScreen)));

Future<void> _seed(CueDatabase db, List<Map<String, dynamic>> items) =>
    CatalogRepository(
      db,
      FakeGateway(),
    ).upsert([for (final i in items) CatalogItemDto(i)]);

void main() {
  test('filter misses name each explicit filter honestly', () {
    const f = DeckFilters(
      genres: {'comedy'},
      countries: {'KR'},
      status: StatusFilter.finished,
    );
    const title = Title(
      id: 'anilist:1',
      kind: MediaKind.anime,
      titleEn: 'Synthetic 1',
      genres: ['Action'],
      country: 'JP',
      status: 'finished',
    );
    // Passes only the status filter.
    final misses = filterMisses(
      title,
      f,
      (only) => only.genres.isEmpty && only.countries.isEmpty,
    );
    expect(misses.map((m) => m.label), ['Comedy', 'Country: Korea']);
    expect(
      outsideLabel(misses),
      'Outside your filters: Comedy, Country: Korea',
    );
    final cleared = DeckRelaxation(
      DeckRung.outsideFilter,
      outsideLabel(misses),
      misses: misses,
    ).clearedFrom(f);
    expect(cleared.genres, isEmpty);
    expect(cleared.countries, isEmpty);
    expect(cleared.status, StatusFilter.finished);
  });

  testWidgets(
    'explicit filters that exclude everything deal labelled nearest matches with keep and clear',
    (t) async {
      await pumpCue(
        t,
        gateway: _anime([
          [
            item(1, genres: const ['Action']),
            item(2, genres: const ['Action', 'Drama']),
          ],
        ]),
        overrides: [deckFiltersProvider.overrideWith(_Comedy.new)],
      );
      await settle(t);
      final c = _container(t);
      final state = c.read(deckControllerProvider);
      expect(state.cards, isNotEmpty);
      expect(state.emptyMessage, isNull);
      expect(find.byType(SwipeDeck), findsOneWidget);
      for (final card in state.cards) {
        expect(card.reason, startsWith('Outside your filter: Comedy.'));
        expect(state.relaxed[card.title.id]!.rung, DeckRung.outsideFilter);
      }
      expect(find.text('Outside your filter: Comedy'), findsOneWidget);
      expect(find.text('Keep filter'), findsOneWidget);
      await t.tap(find.text('Keep filter'));
      await t.pumpAndSettle();
      expect(find.text('Keep filter'), findsNothing);
      expect(c.read(deckFiltersProvider).genres, {'comedy'});
    },
  );

  testWidgets('Clear filter removes only the filter the card misses', (
    t,
  ) async {
    await pumpCue(
      t,
      gateway: _anime([
        [
          item(1, genres: const ['Comedy'], country: 'JP'),
        ],
      ]),
      overrides: [deckFiltersProvider.overrideWith(_ComedyFromIndia.new)],
    );
    await settle(t);
    final c = _container(t);
    final top = c.read(deckControllerProvider).top!;
    expect(top.title.id, 'anilist:1');
    expect(top.reason, startsWith('Outside your filter: Country: India.'));
    await t.tap(find.text('Clear filter'));
    await settle(t);
    final f = c.read(deckFiltersProvider);
    expect(f.countries, isEmpty);
    expect(f.genres, {'comedy'});
    final state = c.read(deckControllerProvider);
    expect(state.top!.title.id, 'anilist:1');
    expect(state.relaxed, isEmpty);
    expect(state.top!.reason, isNot(contains('Outside your filter')));
  });

  testWidgets(
    'hard exclusions are never relaxed: library, Not interested and novels stay out',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      await t.runAsync(() async {
        final profile = (await ProfileRepository(db).ensureActive()).id;
        await _seed(db, [
          {...item(1), 'format': 'NOVEL'},
          {...item(2), 'format': 'MUSIC'},
          item(3),
          item(4),
        ]);
        final service = ImportService(db, CatalogRepository(db, FakeGateway()));
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
                  title: 'Synthetic 3',
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
        gateway: _anime([[]]),
        overrides: [deckFiltersProvider.overrideWith(_Comedy.new)],
      );
      await settle(t);
      final c = _container(t);
      var state = c.read(deckControllerProvider);
      expect(state.cards.map((c) => c.title.id), ['anilist:4']);
      expect(state.top!.reason, startsWith('Outside your filter: Comedy.'));
      final choice = c
          .read(deckControllerProvider.notifier)
          .decide(Decision.notInterested);
      await waitForDecisions(t, 1);
      await choice;
      state = c.read(deckControllerProvider);
      expect(state.cards, isEmpty);
      expect(state.emptyMessage, contains('Cue has checked so far'));
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Review filters'), findsNothing);
    },
  );

  testWidgets(
    'never shows the empty state while the cache has an eligible title, even offline',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      await t.runAsync(
        () => _seed(db, [
          item(1, genres: const ['Action'], country: 'JP'),
        ]),
      );
      await pumpCue(
        t,
        db: db,
        gateway: _anime(const [], offline: true),
        overrides: [deckFiltersProvider.overrideWith(_ComedyFromIndia.new)],
      );
      await settle(t);
      final state = _container(t).read(deckControllerProvider);
      expect(state.top!.title.id, 'anilist:1');
      expect(state.emptyMessage, isNull);
      expect(state.offline, isTrue);
      expect(
        state.top!.reason,
        startsWith('Outside your filters: Comedy, Country: India.'),
      );
      expect(find.byType(SwipeDeck), findsOneWidget);
    },
  );

  testWidgets('instant open deals from the cache before the network answers', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    await t.runAsync(() => _seed(db, [for (var i = 1; i <= 5; i++) item(i)]));
    final gateway = _SlowGateway({
      for (final k in MediaKind.discoverable)
        if (k != MediaKind.anime) k: const [[]],
      MediaKind.anime: [
        [for (var i = 1; i <= 30; i++) item(i)],
      ],
    });
    await pumpCue(t, db: db, gateway: gateway);
    final c = _container(t);
    for (
      var i = 0;
      i < 100 && c.read(deckControllerProvider).top == null;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    var state = c.read(deckControllerProvider);
    expect(state.top, isNotNull, reason: 'Cached cards must not wait');
    expect(state.loading, isFalse);
    expect(state.refreshing, isTrue);
    expect(gateway.gate.isCompleted, isFalse);
    await t.pump();
    expect(find.byType(SwipeDeck), findsOneWidget);
    final first = state.top!.title.id;
    gateway.gate.complete();
    await settle(t);
    state = c.read(deckControllerProvider);
    expect(state.refreshing, isFalse);
    expect(state.top!.title.id, first, reason: 'The card on screen stays');
    expect(state.cards.length, Ranker.deckSize);
  });

  testWidgets(
    'offline with an empty cache is a friendly retry that recovers on its own',
    (t) async {
      final gateway = _anime([
        [item(1)],
      ], offline: true);
      await pumpCue(t, gateway: gateway);
      await settle(t);
      final c = _container(t);
      expect(c.read(deckControllerProvider).cards, isEmpty);
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('No recommendations'), findsNothing);
      gateway.offline = false;
      // The automatic retry fires without any tap.
      for (
        var i = 0;
        i < 80 && c.read(deckControllerProvider).top == null;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 200));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await settle(t);
      expect(c.read(deckControllerProvider).top!.title.id, 'anilist:1');
      expect(c.read(deckControllerProvider).offline, isFalse);
    },
  );

  testWidgets(
    'titles set aside with Not now never return inside their 14 days',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = _anime([
        [item(1), item(2)],
      ]);
      await pumpCue(t, db: db, gateway: gateway);
      await settle(t);
      var c = _container(t);
      for (var i = 0; i < 2; i++) {
        final choice = c
            .read(deckControllerProvider.notifier)
            .decide(Decision.notNow);
        await waitForDecisions(t, i + 1);
        await choice;
      }
      // A later session: nothing new is reachable.
      await t.pumpWidget(const SizedBox());
      gateway.offline = true;
      await pumpCue(t, db: db, gateway: gateway);
      await settle(t);
      c = _container(t);
      final state = c.read(deckControllerProvider);
      expect(state.cards, isEmpty);
      expect(state.relaxed, isEmpty);
    },
  );

  test('prefetch starts before the deck runs out', () {
    expect(DeckController.refillBelow, greaterThanOrEqualTo(8));
  });
}
