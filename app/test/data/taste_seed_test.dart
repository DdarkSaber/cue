import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/db/database.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/domain/reasons.dart';
import 'package:cue/domain/recommendation_context.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  group('selectTasteSeeds', () {
    test(
      'strongest ratings first, then imported history; never weak or negative',
      () {
        final s = ProfileSignals(
          library: {
            'okay': const LibraryEntry(titleId: 'okay', rating: Rating.okay),
            'bad': const LibraryEntry(titleId: 'bad', rating: Rating.disliked),
            'enjoyed': const LibraryEntry(
              titleId: 'enjoyed',
              rating: Rating.enjoyed,
            ),
            'fav-old': LibraryEntry(
              titleId: 'fav-old',
              rating: Rating.favourite,
              actualWatchedAt: DateTime(2020),
            ),
            'fav-new': LibraryEntry(
              titleId: 'fav-new',
              rating: Rating.favourite,
              actualWatchedAt: DateTime(2025),
            ),
            'watching': const LibraryEntry(
              titleId: 'watching',
              state: LibraryState.watching,
            ),
            'done': const LibraryEntry(
              titleId: 'done',
              state: LibraryState.completed,
            ),
            'planned': const LibraryEntry(
              titleId: 'planned',
              state: LibraryState.planned,
            ),
          },
          weakHistoryIds: const {'watching', 'done'},
        );
        expect(selectTasteSeeds(s), [
          'fav-new',
          'fav-old',
          'enjoyed',
          'done',
          'watching',
        ]);
        expect(selectTasteSeeds(s, limit: 2), ['fav-new', 'fav-old']);
      },
    );
  });

  test('seeded retrieval caches "more like this" titles, tags them with the seed and skips fresh seeds', () async {
    final db = memoryDb();
    addTearDown(db.close);
    var now = DateTime.utc(2026, 1, 1);
    final gateway = FakeGateway();
    gateway.recommendationLists['anilist:1'] = [
      item(10),
      item(11),
      item(12, adult: true),
      {...item(13), 'format': 'NOVEL'},
    ];
    gateway.recommendationLists['anilist:2'] = [item(11), item(1)];
    gateway.recommendationLists['tmdb:7'] = [
      item(20, provider: 'tmdb', providerKind: 'tv', kind: 'kdrama'),
    ];
    final catalog = CatalogRepository(db, gateway, clock: () => now);
    final library = LibraryRepository(db, clock: () => now);
    final profile = (await ProfileRepository(db).ensureActive()).id;
    await catalog.upsert([
      CatalogItemDto(item(1)),
      CatalogItemDto(item(2)),
      CatalogItemDto(
        item(7, provider: 'tmdb', providerKind: 'tv', kind: 'kdrama'),
      ),
      // No provider list exists for this one; it is simply skipped.
      CatalogItemDto(item(8, provider: 'tvmaze', kind: 'series')),
    ]);
    for (final (id, rating) in [
      ('anilist:1', 'favourite'),
      ('anilist:2', 'enjoyed'),
      ('tmdb:tv:7', 'enjoyed'),
      ('tvmaze:8', 'favourite'),
    ]) {
      await db
          .into(db.userTitles)
          .insert(
            UserTitlesCompanion.insert(
              profileId: profile,
              titleId: id,
              rating: Value(rating),
              state: const Value('completed'),
              updatedAt: now,
            ),
          );
    }
    var signals = await library.signals(profile);
    expect(signals.tasteSeeds.first, isIn(['anilist:1', 'tvmaze:8']));
    final stored = await catalog.fetchSeeded(signals.tasteSeeds);
    // 10 and 11 from seed 1; 11 from seed 2 (1 is the seed itself, kept
    // as a title but never an edge to itself... it is seed 1, a library
    // title, so the ranker excludes it anyway); 20 from the TMDB seed.
    expect(stored, 5);
    expect(gateway.recommendationCalls.toSet(), {
      'anilist:1',
      'anilist:2',
      'tmdb:7',
    });
    expect(await catalog.titleById('anilist:12'), isNull);
    expect(await catalog.titleById('anilist:13'), isNull);
    signals = await library.signals(profile);
    expect(signals.becauseOf['anilist:10'], ['anilist:1']);
    expect(signals.becauseOf['anilist:11'], ['anilist:1', 'anilist:2']);
    expect(signals.becauseOf['tmdb:tv:20'], ['tmdb:tv:7']);
    expect(signals.becauseOf['anilist:1'], ['anilist:2']);

    // Asked within a week: not asked again.
    await catalog.fetchSeeded(signals.tasteSeeds);
    expect(gateway.recommendationCalls, hasLength(3));
    now = now.add(const Duration(days: 8));
    await catalog.fetchSeeded(signals.tasteSeeds);
    expect(gateway.recommendationCalls, hasLength(6));

    // Ranking: agreement between liked seeds earns a modest boost, the
    // reason names the seed, and the card exposes it for other surfaces.
    final ranker = Ranker();
    final pool = await catalog.pool({MediaKind.anime, MediaKind.kdrama});
    final byId = {for (final t in pool) t.id: t};
    const f = DeckFilters();
    final s10 = ranker.score(byId['anilist:10']!, signals, f);
    final s11 = ranker.score(byId['anilist:11']!, signals, f);
    expect(s11 - s10, closeTo(Ranker.seedBoost(1), 1e-9));
    expect(Ranker.seedBoost(0), 0);
    expect(Ranker.seedBoost(9), 0.12);
    final cards = ranker.deal(
      pool,
      signals,
      f,
      showAdult: false,
      enabledKinds: {MediaKind.anime, MediaKind.kdrama},
      titlesById: byId,
      explorePreference: 0,
    );
    final eleven = cards.firstWhere((c) => c.title.id == 'anilist:11');
    expect(eleven.becauseOf, ['anilist:1', 'anilist:2']);
    expect(eleven.reason, 'Because you liked Synthetic 1.');
    // Library titles stay excluded even when a seed recommends them.
    expect(cards.map((c) => c.title.id), isNot(contains('anilist:1')));
    expect(
      reasonFor(byId['tmdb:tv:20']!, signals, f, titlesById: byId),
      'Because you liked Synthetic 7.',
    );
  });
}
