import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/library_repository.dart';
import 'package:cue/data/profile_repository.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:cue/imports/adapters/xlsx_import.dart';
import 'package:cue/imports/import_service.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';

import '../imports/xlsx_test.dart' show buildXlsx;
import '../support/fakes.dart';

// Titles from the person's own history must never come back as new picks:
// unconfirmed plays, merged seasons, and the same story in another format.
void main() {
  bool eligible(Title t, ProfileSignals s) => Ranker().eligible(
    t,
    s,
    const DeckFilters(),
    showAdult: false,
    enabledKinds: {...MediaKind.discoverable},
  );

  test('merged seasons in a spreadsheet each count as watched', () {
    final p = XlsxImportAdapter().parse(
      buildXlsx({
        'Anime': [
          [
            'Title',
            'Romaji / other name',
            'Status',
            'Rating',
            'Seasons / films merged',
          ],
          [
            'Show A',
            'Show A Romaji',
            'Finished',
            'Favourite',
            'Show A Season 2; Show A Romaji; Show A: The Movie',
          ],
        ],
      }),
    );
    expect(p.records.map((r) => r.title), [
      'Show A',
      'Show A Season 2',
      'Show A: The Movie',
    ]);
    final extra = p.records.skip(1);
    expect(extra.every((r) => r.kind == MediaKind.anime), isTrue);
    expect(extra.every((r) => r.state == LibraryState.completed), isTrue);
    expect(extra.every((r) => r.rating == null), isTrue);
    expect(p.records.map((r) => r.sourceEntryKey).toSet(), hasLength(3));
  });

  test('a title an import named but did not add is never dealt', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final catalog = CatalogRepository(db, FakeGateway());
    await catalog.upsert([
      CatalogItemDto(item(1, kind: 'movie', provider: 'tmdb', title: 'Played')),
      CatalogItemDto(item(2, kind: 'movie', provider: 'tmdb', title: 'Other')),
    ]);
    final profile = (await ProfileRepository(db).ensureActive()).id;
    final service = ImportService(db, catalog);
    final staged = await service.stage(
      profile,
      const ParsedImport(
        sourceType: 'xlsx',
        adapterVersion: '1',
        records: [
          NormalizedRecord(
            sourceEntryKey: 'played',
            title: 'Played 1',
            state: LibraryState.partial,
            confirmed: false,
            screenOnly: true,
          ),
        ],
      ),
      offlineOnly: true,
    );
    expect(staged.matched.single.titleId, isNotNull);
    expect(staged.matched.single.included, isFalse);
    await service.commit(profile, staged);
    final s = await LibraryRepository(db).signals(profile);
    final played = (await catalog.titleById(staged.matched.single.titleId!))!;
    expect(s.library, isEmpty); // not added: unconfirmed
    expect(s.known, {played.id});
    expect(eligible(played, s), isFalse);
    final other = (await catalog.pool({MediaKind.movie}))
        .firstWhere((t) => t.id != played.id);
    expect(eligible(other, s), isTrue);
  });

  test('another entry of the same story is hidden only in its own medium', () {
    const anime = Title(
      id: 'anilist:1',
      kind: MediaKind.anime,
      titleEn: 'A Silent Voice',
    );
    // Watching the anime says nothing about reading the manga.
    const manga = Title(
      id: 'anilist:2',
      kind: MediaKind.manga,
      titleEn: 'A Silent Voice',
    );
    const remake = Title(
      id: 'anilist:3',
      kind: MediaKind.anime,
      titleEn: 'A Silent Voice (2016)',
    );
    const unrelated = Title(
      id: 'anilist:4',
      kind: MediaKind.anime,
      titleEn: 'A Silent Voice of the Sea',
    );
    final s = ProfileSignals(
      library: {
        anime.id: const LibraryEntry(
          titleId: 'anilist:1',
          state: LibraryState.completed,
        ),
      },
      seenNames: workNames(anime).toSet(),
    );
    expect(eligible(manga, s), isTrue);
    expect(eligible(remake, s), isFalse);
    expect(eligible(unrelated, s), isTrue);
  });

  test('a trailing year does not hide the same story', () {
    expect(workName('Hunter x Hunter (2011)'), workName('HUNTER x HUNTER'));
    expect(workName('Hunter x Hunter (2011)'), 'hunterxhunter');
    expect(workName('Fruits Basket (2019)'), 'fruitsbasket');
    expect(workName('86'), '86');
  });

  test('names from the import file itself are never dealt', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final catalog = CatalogRepository(db, FakeGateway());
    final profile = (await ProfileRepository(db).ensureActive()).id;
    final service = ImportService(db, catalog);
    // Unresolved offline: nothing cached, so it waits in review.
    await service.commit(
      profile,
      await service.stage(
        profile,
        const ParsedImport(
          sourceType: 'mal_api',
          adapterVersion: '1',
          records: [
            NormalizedRecord(
              sourceEntryKey: 'x',
              title: 'Bleach: Sennen Kessen-hen',
              kind: MediaKind.anime,
              state: LibraryState.completed,
            ),
          ],
        ),
        offlineOnly: true,
      ),
    );
    final s = await LibraryRepository(db).signals(profile);
    const later = Title(
      id: 'anilist:9',
      kind: MediaKind.anime,
      titleEn: 'BLEACH: Thousand-Year Blood War',
      titleRomaji: 'BLEACH: Sennen Kessen-hen',
    );
    expect(eligible(later, s), isFalse);
  });

  test('the format rated most leads instead of being held back', () {
    const s = ProfileSignals(
      kindRatings: {MediaKind.anime: 300, MediaKind.manhwa: 30},
    );
    expect(kindAffinity(s, MediaKind.anime), 1);
    expect(
      kindAffinity(s, MediaKind.anime),
      greaterThan(kindAffinity(s, MediaKind.manhwa)),
    );
    expect(
      kindAffinity(s, MediaKind.manhwa),
      greaterThan(kindAffinity(s, MediaKind.movie)),
    );
    expect(kindAffinity(const ProfileSignals(), MediaKind.movie), 0.5);
  });

  test('reading taste comes from reading history, not only from anime', () {
    const romance = Title(
      id: 'anilist:10',
      kind: MediaKind.manhwa,
      titleEn: 'Webtoon A',
      genres: ['Romance', 'Slice of Life'],
      year: 2024,
      score: 80,
    );
    const action = Title(
      id: 'anilist:11',
      kind: MediaKind.manhwa,
      titleEn: 'Webtoon B',
      genres: ['Action', 'Fantasy'],
      year: 2024,
      score: 80,
    );
    // Rom-com anime favourites dominate overall taste...
    const overall = {'romance': 30.0, 'slice of life': 20.0, 'action': 5.0};
    const animeOnly = ProfileSignals(weights: overall, evidenceTitles: 50);
    final ranker = Ranker();
    double score(Title t, ProfileSignals s) =>
        ranker.score(t, s, const DeckFilters());
    expect(score(romance, animeOnly), greaterThan(score(action, animeOnly)));
    // ...but what this person reads is action and fantasy.
    const withReading = ProfileSignals(
      weights: overall,
      evidenceTitles: 50,
      mediumWeights: {
        true: {'action': 8.0, 'fantasy': 6.0},
      },
    );
    expect(
      score(action, withReading),
      greaterThan(score(romance, withReading)),
    );
  });
}
