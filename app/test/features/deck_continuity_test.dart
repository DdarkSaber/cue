import 'dart:async';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle, waitForDecisions;

class _AnimeOnly extends DeckFiltersController {
  @override
  DeckFilters build() => const DeckFilters(kinds: {MediaKind.anime});
}

class _Horror extends DeckFiltersController {
  @override
  DeckFilters build() => const DeckFilters(genres: {'Horror'});
}

const _orders = [
  'POPULARITY_DESC',
  'TRENDING_DESC',
  'SCORE_DESC',
  'FAVOURITES_DESC',
  'START_DATE_DESC',
];

/// AniList for a huge anime library: every order overlaps the library
/// heavily, but each still holds titles the person has never seen.
class _BigLibraryAniList extends FakeGateway {
  _BigLibraryAniList(this.library)
    : super(
        pages: {
          for (final kind in MediaKind.discoverable)
            if (kind != MediaKind.anime) kind: const [[]],
          MediaKind.anime: [
            [for (var i = 1; i <= 10; i++) item(i), ...library.take(40)],
            for (var p = 40; p < library.length; p += 50)
              library.skip(p).take(50).toList(),
          ],
        },
      ) {
    for (var o = 1; o < _orders.length; o++) {
      byOrder[_orders[o]] = [
        for (var p = 0; p < 6; p++)
          [
            ...library.skip(p * 30 + o * 7).take(30),
            for (var i = 0; i < 20; i++) item(10000 * o + p * 100 + i),
          ],
      ];
    }
  }

  final List<Map<String, dynamic>> library;
  final byOrder = <String, List<List<Map<String, dynamic>>>>{};

  @override
  List<String?> discoverSorts(MediaKind kind) =>
      kind == MediaKind.anime ? _orders : const [null];

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
  }) async {
    final list = byOrder[sort];
    if (kind != MediaKind.anime || list == null) {
      return super.discover(kind, mood: mood, page: page);
    }
    calls.add('discover:anime:${mood ?? '-'}:$page:$sort');
    if (page > list.length) return const CatalogPageDto([], false);
    return CatalogPageDto(
      list[page - 1].map(CatalogItemDto.new).toList(),
      page < list.length,
    );
  }
}

/// A gateway whose network never answers until [release] is called.
class _StalledGateway extends FakeGateway {
  _StalledGateway({super.pages});
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

  @override
  Future<List<List<CatalogItemDto>>> recommendations(
    List<SeedRef> seeds,
  ) async {
    await gate.future;
    return super.recommendations(seeds);
  }
}

/// Discovery is rate limited for as long as [limited] is set.
class _LimitedGateway extends FakeGateway {
  _LimitedGateway({super.pages});
  bool limited = true;

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
  }) {
    if (limited) {
      calls.add('discover:${kind.name}:limited');
      throw const CatalogUnavailable('rate_limited');
    }
    return super.discover(kind, mood: mood, page: page, sort: sort);
  }
}

Future<void> _seedLibrary(
  CueDatabase db,
  Iterable<Map<String, dynamic>> items, {
  String? rating,
  String source = 'import:fan',
}) async {
  final profile = (await ProfileRepository(db).ensureActive()).id;
  await CatalogRepository(
    db,
    FakeGateway(),
  ).upsert([for (final i in items) CatalogItemDto(i)]);
  await db.batch((b) {
    for (final i in items) {
      b.insert(
        db.userTitles,
        UserTitlesCompanion.insert(
          profileId: profile,
          titleId: 'anilist:${i['providerId']}',
          state: const Value('completed'),
          rating: Value(rating),
          source: Value(source),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
    }
  });
}

void main() {
  testWidgets(
    'a 520-title anime library still gets a continuous stream of anime over 64 swipes',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final library = [for (var i = 1001; i <= 1520; i++) item(i)];
      final gateway = _BigLibraryAniList(library);
      await t.runAsync(() => _seedLibrary(db, library));
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final libraryIds = {
        for (final i in library) 'anilist:${i['providerId']}',
      };
      final shown = <String>{};
      for (var i = 0; i < 64; i++) {
        final state = container.read(deckControllerProvider);
        expect(
          state.cards,
          isNotEmpty,
          reason: 'Anime supply must not end after ${shown.length} cards',
        );
        expect(state.emptyMessage, isNull);
        for (final card in state.cards) {
          expect(card.title.kind, MediaKind.anime);
          expect(libraryIds, isNot(contains(card.title.id)));
        }
        expect(shown.add(state.top!.title.id), isTrue, reason: 'repeat at $i');
        final choice = container
            .read(deckControllerProvider.notifier)
            .decide(Decision.notNow);
        await waitForDecisions(t, i + 1);
        await choice;
      }
      expect(shown, hasLength(64));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'a filter nothing matches deals labelled nearest cards, never the empty state',
    (t) async {
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            [
              for (var i = 1; i <= 6; i++) item(i, genres: const ['Action']),
            ],
          ],
        },
      );
      await pumpCue(
        t,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_Horror.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final state = container.read(deckControllerProvider);
      expect(state.emptyMessage, isNull);
      expect(state.cards, isNotEmpty);
      expect(state.top!.reason, startsWith('Outside your filter: Horror'));
    },
  );

  testWidgets(
    'rate limited discovery with a warm cache keeps dealing cards and recovers',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = _LimitedGateway(
        pages: {
          MediaKind.anime: [
            [for (var i = 50; i < 60; i++) item(i)],
          ],
        },
      );
      await t.runAsync(
        () => CatalogRepository(
          db,
          gateway,
        ).upsert([for (var i = 1; i <= 4; i++) CatalogItemDto(item(i))]),
      );
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      var state = container.read(deckControllerProvider);
      expect(state.emptyMessage, isNull);
      expect(state.cards, isNotEmpty);
      // A refusal is never read as "nothing left".
      expect(state.catalogPending, isTrue);
      gateway.limited = false;
      final choice = container
          .read(deckControllerProvider.notifier)
          .decide(Decision.notNow);
      await waitForDecisions(t, 1);
      await choice;
      state = container.read(deckControllerProvider);
      expect(state.cards.length, greaterThan(3));
    },
  );

  testWidgets(
    'with an empty cache a refused catalog is retried on a growing backoff, not every five seconds',
    (t) async {
      final gateway = _LimitedGateway(
        pages: {
          MediaKind.anime: [
            [item(1)],
          ],
        },
      );
      await pumpCue(
        t,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      int attempts() =>
          gateway.calls.where((c) => c == 'discover:anime:limited').length;
      final first = attempts();
      expect(first, greaterThan(0));
      // Waits double: 5 s, 10 s, 20 s. Every-five-seconds would make six
      // more attempts in this half minute; backoff makes at most three.
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      expect(attempts() - first, lessThanOrEqualTo(3 * first));
      expect(attempts() - first, greaterThan(0));
    },
  );

  testWidgets(
    'because-you-liked cards appear early once a liked title has recommendations',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway(
        pages: {
          for (final kind in MediaKind.discoverable)
            if (kind != MediaKind.anime) kind: const [[]],
          MediaKind.anime: [
            [for (var i = 100; i < 160; i++) item(i)],
          ],
        },
      );
      gateway.recommendationLists['anilist:1'] = [item(900), item(901)];
      gateway.recommendationLists['anilist:2'] = [item(902)];
      await t.runAsync(
        () => _seedLibrary(
          db,
          [for (var i = 1; i <= 6; i++) item(i)],
          rating: 'favourite',
          source: 'manual',
        ),
      );
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final cards = container.read(deckControllerProvider).cards;
      final because = [
        for (var i = 0; i < cards.length; i++)
          if (cards[i].reason.startsWith('Because you liked')) i,
      ];
      expect(because, isNotEmpty);
      expect(because.first, lessThan(5));
      final top = cards[because.first];
      expect(top.becauseOf, isNotEmpty);
      expect({
        'Because you liked Synthetic 1.',
        'Because you liked Synthetic 2.',
      }, contains(top.reason));
    },
  );

  testWidgets(
    'a cold open with a warm cache shows a card before the network answers',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = _StalledGateway(
        pages: {
          MediaKind.anime: [
            [item(99)],
          ],
        },
      );
      await t.runAsync(
        () => CatalogRepository(
          db,
          gateway,
        ).upsert([for (var i = 1; i <= 12; i++) CatalogItemDto(item(i))]),
      );
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      final container = ProviderScope.containerOf(
        t.element(find.byType(DeckScreen)),
      );
      final state = container.read(deckControllerProvider);
      expect(gateway.gate.isCompleted, isFalse);
      expect(state.cards, isNotEmpty);
      expect(state.loading, isFalse);
      expect(state.emptyMessage, isNull);
      expect(state.refreshing, isTrue);
      gateway.gate.complete();
      await settle(t);
      expect(container.read(deckControllerProvider).cards, isNotEmpty);
    },
  );
}
