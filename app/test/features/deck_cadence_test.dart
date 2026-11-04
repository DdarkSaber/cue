import 'dart:async';
import 'dart:convert';

import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/ai_taste.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/decision.dart';
import 'package:cue/domain/models/settings.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/features/deck/candidate_sources.dart';
import 'package:cue/features/deck/deck_controller.dart';
import 'package:cue/features/deck/deck_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../support/fakes.dart';
import 'deck_test.dart' show settle, waitForDecisions;

class _AnimeOnly extends DeckFiltersController {
  @override
  DeckFilters build() => const DeckFilters(kinds: {MediaKind.anime});
}

Future<void> _cache(CueDatabase db, Iterable<Map<String, dynamic>> items) =>
    CatalogRepository(
      db,
      FakeGateway(),
    ).upsert([for (final i in items) CatalogItemDto(i)]);

Future<void> _like(CueDatabase db, Iterable<Map<String, dynamic>> items) async {
  final profile = (await ProfileRepository(db).ensureActive()).id;
  await _cache(db, items);
  await db.batch((b) {
    for (final i in items) {
      b.insert(
        db.userTitles,
        UserTitlesCompanion.insert(
          profileId: profile,
          titleId: 'anilist:${i['providerId']}',
          state: const Value('completed'),
          rating: const Value('favourite'),
          source: const Value('manual'),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
    }
  });
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(DeckScreen)));

int _discovers(FakeGateway g) =>
    g.calls.where((c) => c.startsWith('discover')).length;

/// Discovery waits for [gate]; [started] counts requests that were made.
class _GatedGateway extends FakeGateway {
  _GatedGateway({super.pages});
  final gate = Completer<void>();
  int started = 0;

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
  }) async {
    started++;
    await gate.future;
    return super.discover(kind, mood: mood, page: page, sort: sort);
  }
}

class _GatedSeeds extends FakeGateway {
  _GatedSeeds({super.pages});
  final gate = Completer<void>();

  @override
  Future<List<List<CatalogItemDto>>> recommendations(
    List<SeedRef> seeds,
  ) async {
    await gate.future;
    return super.recommendations(seeds);
  }
}

class _Refusing extends FakeGateway {
  _Refusing({super.pages});
  bool refuse = true;
  Duration? retryAfter;
  int refused = 0;

  @override
  Future<CatalogPageDto> discover(
    MediaKind kind, {
    String? mood,
    int page = 1,
    String? sort,
  }) {
    if (refuse) {
      refused++;
      throw CatalogUnavailable('rate_limited', retryAfter: retryAfter);
    }
    return super.discover(kind, mood: mood, page: page, sort: sort);
  }
}

class _FakeSource implements CandidateSource {
  Map<String, AiPick> picks = {};
  void Function()? added;

  @override
  void refill(
    String profileId,
    ProfileSignals signals,
    Set<MediaKind> kinds,
    AppSettings settings, {
    void Function()? onAdded,
  }) => added = onAdded;

  @override
  Future<Map<String, AiPick>> provenance(
    String profileId,
    AppSettings settings,
  ) async => picks;
}

Future<void> _pause(WidgetTester t, [int ms = 20]) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
}

void main() {
  testWidgets(
    'a full cache is never refilled by swiping: no catalog request in nine swipes',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            [for (var i = 500; i < 550; i++) item(i)],
          ],
        },
      );
      await t.runAsync(
        () => _cache(db, [for (var i = 1; i <= 90; i++) item(i)]),
      );
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = _container(t);
      for (var n = 1; n <= 9; n++) {
        final choice = container
            .read(deckControllerProvider.notifier)
            .decide(Decision.notNow);
        await waitForDecisions(t, n);
        await choice;
      }
      expect(_discovers(gateway), 0);
      expect(container.read(deckControllerProvider).cards.length, 10);
    },
  );

  testWidgets('running low on unseen titles asks the catalog for more', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeGateway(
      pages: {
        MediaKind.anime: [
          [for (var i = 500; i < 550; i++) item(i)],
        ],
      },
    );
    await t.runAsync(() => _cache(db, [for (var i = 1; i <= 36; i++) item(i)]));
    await pumpCue(
      t,
      db: db,
      gateway: gateway,
      overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
    );
    await settle(t);
    final container = _container(t);
    expect(_discovers(gateway), 0);
    for (var n = 1; n <= 10; n++) {
      final choice = container
          .read(deckControllerProvider.notifier)
          .decide(Decision.notNow);
      await waitForDecisions(t, n);
      await choice;
    }
    expect(_discovers(gateway), greaterThan(0));
  });

  testWidgets('refills never overlap: a cycle in flight is not started again', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = _GatedGateway(
      pages: {
        MediaKind.anime: [
          [for (var i = 500; i < 520; i++) item(i)],
        ],
      },
    );
    await t.runAsync(() => _cache(db, [for (var i = 1; i <= 4; i++) item(i)]));
    await pumpCue(
      t,
      db: db,
      gateway: gateway,
      overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
    );
    for (var i = 0; i < 10; i++) {
      await _pause(t);
    }
    final first = gateway.started;
    expect(first, greaterThan(0));
    final notifier = _container(t).read(deckControllerProvider.notifier);
    for (var i = 0; i < 3; i++) {
      unawaited(notifier.redeal());
    }
    unawaited(notifier.decide(Decision.notNow));
    for (var i = 0; i < 10; i++) {
      await _pause(t);
    }
    expect(gateway.started, first);
    gateway.gate.complete();
    await settle(t);
  });

  testWidgets(
    'seeded recommendations that arrive later re-rank the deck without a swipe or a full retrieval',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = _GatedSeeds(
        pages: {
          MediaKind.anime: [
            [for (var i = 500; i < 520; i++) item(i)],
          ],
        },
      );
      gateway.recommendationLists['anilist:1'] = [item(900, score: 100)];
      await t.runAsync(() async {
        await _like(db, [for (var i = 1; i <= 6; i++) item(i)]);
        await _cache(db, [for (var i = 100; i < 160; i++) item(i, score: 55)]);
      });
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = _container(t);
      bool has900() => container
          .read(deckControllerProvider)
          .cards
          .any((c) => c.title.id == 'anilist:900');
      expect(container.read(deckControllerProvider).cards, isNotEmpty);
      expect(has900(), isFalse);
      gateway.gate.complete();
      for (var i = 0; i < 40 && !has900(); i++) {
        await _pause(t, 30);
      }
      expect(has900(), isTrue);
      expect(_discovers(gateway), 0);
    },
  );

  testWidgets('AI picks that arrive later re-rank the upcoming cards', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final source = _FakeSource();
    await t.runAsync(
      () => _cache(db, [
        for (var i = 100; i < 160; i++) item(i, score: i == 130 ? 45 : 60),
      ]),
    );
    await pumpCue(
      t,
      db: db,
      gateway: FakeGateway(
        pages: {
          MediaKind.anime: [
            [item(500)],
          ],
        },
      ),
      overrides: [
        deckFiltersProvider.overrideWith(_AnimeOnly.new),
        candidateSourcesProvider.overrideWithValue([source]),
      ],
    );
    await settle(t);
    final container = _container(t);
    bool hasPick() => container
        .read(deckControllerProvider)
        .cards
        .any((c) => c.title.id == 'anilist:130');
    expect(hasPick(), isFalse);
    final top = container.read(deckControllerProvider).top!.title.id;
    source.picks = {
      'anilist:130': const AiPick(
        'anilist:130',
        'Synthetic 1',
        'Shares a mood.',
      ),
    };
    source.added!();
    for (var i = 0; i < 40 && !hasPick(); i++) {
      await _pause(t, 30);
    }
    expect(hasPick(), isTrue);
    // The card being looked at does not move.
    expect(container.read(deckControllerProvider).top!.title.id, top);
  });

  testWidgets(
    'a thin deck after a refused catalog retries on its own, after Retry-After, and stops when disposed',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      final gateway = _Refusing(
        pages: {
          MediaKind.anime: [
            [for (var i = 500; i < 520; i++) item(i)],
          ],
        },
      )..retryAfter = const Duration(seconds: 40);
      await t.runAsync(
        () => _cache(db, [for (var i = 1; i <= 5; i++) item(i)]),
      );
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      await settle(t);
      final container = _container(t);
      expect(container.read(deckControllerProvider).cards, isNotEmpty);
      final first = gateway.refused;
      expect(first, greaterThan(0));
      // The plain backoff is 5 s; the provider asked for 40.
      await t.pump(const Duration(seconds: 20));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      expect(gateway.refused, first);
      await t.pump(const Duration(seconds: 30));
      for (var i = 0; i < 10; i++) {
        await _pause(t);
      }
      expect(gateway.refused, greaterThan(first));

      // Gone with the screen: no more attempts afterwards.
      await t.pumpWidget(const SizedBox());
      final settled = gateway.refused;
      await t.pump(const Duration(minutes: 5));
      expect(gateway.refused, settled);
    },
  );

  testWidgets('a thin deck recovers by itself once the catalog answers again', (
    t,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = _Refusing(
      pages: {
        MediaKind.anime: [
          [for (var i = 500; i < 540; i++) item(i)],
        ],
      },
    );
    await t.runAsync(() => _cache(db, [for (var i = 1; i <= 5; i++) item(i)]));
    await pumpCue(
      t,
      db: db,
      gateway: gateway,
      overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
    );
    await settle(t);
    final container = _container(t);
    expect(container.read(deckControllerProvider).cards.length, lessThan(8));
    gateway.refuse = false;
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(seconds: 10));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
    }
    await settle(t);
    expect(container.read(deckControllerProvider).cards.length, greaterThan(5));
  });

  testWidgets(
    'deals from 20,000 cached titles in bounded time with library titles left out',
    (t) async {
      final db = memoryDb();
      addTearDown(db.close);
      await t.runAsync(() async {
        await db.batch((b) {
          for (var i = 0; i < 20000; i++) {
            b.insert(
              db.catalogTitles,
              CatalogTitlesCompanion.insert(
                id: 'anilist:$i',
                mediaKind: 'anime',
                titleEn: Value('Synthetic $i'),
                year: Value(1995 + i % 30),
                country: const Value('JP'),
                format: const Value('TV'),
                episodes: const Value(12),
                genresJson: Value(jsonEncode(['Action', 'g${i % 12}'])),
                tagsJson: Value(jsonEncode(['t${i % 40}', 't${i % 13}'])),
                score: Value(30 + i % 70),
                updatedAt: DateTime(2026, 1, 1).add(Duration(seconds: i)),
              ),
            );
          }
        });
      });
      final gateway = FakeGateway(
        pages: {
          MediaKind.anime: [
            [item(50000)],
          ],
        },
      );
      final watch = Stopwatch()..start();
      await pumpCue(
        t,
        db: db,
        gateway: gateway,
        overrides: [deckFiltersProvider.overrideWith(_AnimeOnly.new)],
      );
      final container = _container(t);
      for (var i = 0; i < 400; i++) {
        if (container.read(deckControllerProvider).cards.length == 10) break;
        await _pause(t, 50);
      }
      watch.stop();
      expect(container.read(deckControllerProvider).cards.length, 10);
      // Generous for slow CI; the cap keeps this well under it.
      expect(watch.elapsed, lessThan(const Duration(seconds: 60)));
      expect(_discovers(gateway), 0);
    },
  );
}
