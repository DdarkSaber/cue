import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/data/catalog_repository.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/imports/matcher.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Synthetic names only. The chain under test: AniList, then MyAnimeList's
/// search, then Wikipedia's name for the work (asked of AniList and MAL
/// again), and only then the review queue.
NormalizedRecord rec(
  String title, {
  MediaKind? kind,
  bool confirmed = true,
  bool screenOnly = false,
}) => NormalizedRecord(
  sourceEntryKey: 'k:$title',
  title: title,
  kind: kind,
  state: LibraryState.completed,
  confirmed: confirmed,
  screenOnly: screenOnly,
);

Map<String, dynamic> anilist(
  int id,
  String name, {
  String kind = 'anime',
  int? idMal,
  bool adult = false,
}) => {...item(id, kind: kind, idMal: idMal, adult: adult), 'titleEn': name};

Map<String, dynamic> mal(
  int id,
  String name, {
  String type = 'anime',
  String? kind,
  List<String> synonyms = const [],
}) => {
  ...item(
    id,
    provider: 'mal',
    providerKind: type,
    kind: kind ?? type,
    idMal: id,
  ),
  'titleEn': name,
  'synonyms': synonyms,
};

/// A gateway whose Worker predates the fallback routes.
class _OldWorker extends FakeGateway {
  @override
  Future<List<List<CatalogItemDto>>> malSearch(List<MalQuery> items) async {
    lookupLog.add('mal-missing');
    throw const CatalogUnavailable('not_found');
  }

  @override
  Future<List<List<WikiNameDto>>> canonicalNames(
    List<String> names, {
    MediaKind? kind,
  }) async {
    lookupLog.add('wiki-missing');
    throw const CatalogUnavailable('not_found');
  }
}

void main() {
  late FakeGateway gateway;
  late CatalogRepository catalog;

  void useGateway(FakeGateway g) {
    final db = memoryDb();
    addTearDown(db.close);
    gateway = g;
    catalog = CatalogRepository(db, g);
  }

  setUp(() => useGateway(FakeGateway()));

  Future<MatchedRecord> one(NormalizedRecord r) async =>
      (await ImportMatcher(catalog).match([r])).single;

  test('an AniList hit never reaches MAL or Wikipedia', () async {
    gateway.matchCatalog['plain show'] = [anilist(1, 'Plain Show')];
    final m = await one(rec('Plain Show', kind: MediaKind.anime));
    expect(m.matchClass, MatchClass.suggested);
    expect(gateway.lookupLog, isEmpty);
  });

  test(
    'AniList misses, MAL knows the name: linked to the AniList entry by MAL id',
    () async {
      gateway.malSearchAnime['fan name'] = [
        mal(501, 'Official Name', synonyms: ['Fan Name']),
      ];
      gateway.malCatalog[501] = anilist(11, 'Official Name', idMal: 501);
      final m = await one(rec('Fan Name', kind: MediaKind.anime));
      expect(m.matchClass, MatchClass.suggested);
      expect(m.titleId, 'anilist:11');
      expect(m.included, isTrue);
      expect(gateway.lookupLog, ['mal-anime:Fan Name']);
    },
  );

  test('a MAL work AniList does not list keeps MAL\'s own card', () async {
    gateway.malSearchManga['only on mal'] = [
      mal(502, 'Only On Mal', type: 'manga', kind: 'manhwa'),
    ];
    final m = await one(rec('Only On Mal', kind: MediaKind.manhwa));
    expect(m.matchClass, MatchClass.suggested);
    expect(m.titleId, 'mal:manga:502');
  });

  test('a merely similar MAL name is offered unticked', () async {
    gateway.malSearchAnime['the frozen player returns'] = [
      mal(503, 'Return of the Frozen Player'),
    ];
    gateway.malCatalog[503] = anilist(
      13,
      'Return of the Frozen Player',
      idMal: 503,
    );
    final m = await one(
      rec('The Frozen Player Returns', kind: MediaKind.anime),
    );
    expect(m.matchClass, MatchClass.similar);
    expect(m.included, isFalse);
    expect(m.candidate!.titleId, 'anilist:13');
  });

  test('an adult AniList entry found through MAL stays hidden', () async {
    gateway.malSearchAnime['quiet name'] = [mal(504, 'Quiet Name')];
    gateway.malCatalog[504] = anilist(
      14,
      'Quiet Name',
      idMal: 504,
      adult: true,
    );
    final m = await one(rec('Quiet Name', kind: MediaKind.anime));
    expect(m.resolved, isFalse);
    expect(m.adultHidden, isTrue);
    expect(m.included, isFalse);
  });

  test('a novel found through MAL is never linked', () async {
    gateway.malSearchManga['wordy tale'] = [
      {...mal(505, 'Wordy Tale', type: 'manga'), 'format': 'NOVEL'},
    ];
    final m = await one(rec('Wordy Tale', kind: MediaKind.manga));
    expect(m.resolved, isFalse);
  });

  test('AniList and MAL miss: Wikipedia\'s article lists the name, its title finds the work', () async {
    gateway.wikiCatalog['translated title'] = [
      const WikiNameDto('Canonical Work', ['Translated Title', 'Genbun']),
    ];
    gateway.matchCatalog['canonical work'] = [anilist(21, 'Canonical Work')];
    final m = await one(rec('Translated Title', kind: MediaKind.anime));
    expect(m.matchClass, MatchClass.suggested);
    expect(m.titleId, 'anilist:21');
    expect(m.included, isTrue);
    // MAL was asked first with the typed name; Wikipedia only after.
    expect(gateway.lookupLog, [
      'mal-anime:Translated Title',
      'wiki:Translated Title',
    ]);
  });

  test('a Wikipedia name AniList lacks is tried in MAL too', () async {
    gateway.wikiCatalog['messy name'] = [
      const WikiNameDto('Proper Name', ['Messy Name']),
    ];
    gateway.malSearchManga['proper name'] = [
      mal(506, 'Proper Name', type: 'manga'),
    ];
    gateway.malCatalog[506] = anilist(
      22,
      'Proper Name',
      kind: 'manga',
      idMal: 506,
    );
    final m = await one(rec('Messy Name', kind: MediaKind.manga));
    expect(m.matchClass, MatchClass.suggested);
    expect(m.titleId, 'anilist:22');
    expect(gateway.lookupLog, [
      'mal-manga:Messy Name',
      'wiki:Messy Name',
      'mal-manga:Proper Name',
    ]);
  });

  test('an article found by search alone is a guess: its match is offered unticked', () async {
    gateway.wikiCatalog['vague words'] = [const WikiNameDto('Some Article')];
    gateway.matchCatalog['some article'] = [anilist(23, 'Some Article')];
    final m = await one(rec('Vague Words', kind: MediaKind.anime));
    expect(m.matchClass, MatchClass.similar);
    expect(m.included, isFalse);
    expect(m.candidate!.titleId, 'anilist:23');
  });

  test('only when every source misses does the title go to review', () async {
    final m = await one(rec('Nowhere At All', kind: MediaKind.anime));
    expect(m.matchClass, MatchClass.unresolved);
    expect(m.unchecked, isFalse);
    expect(gateway.lookupLog, [
      'mal-anime:Nowhere At All',
      'wiki:Nowhere At All',
    ]);
  });

  test('an unlabelled record is searched in both MAL lists', () async {
    await one(rec('Unlabelled Name'));
    expect(gateway.lookupLog, [
      'mal-anime:Unlabelled Name',
      'mal-manga:Unlabelled Name',
      'wiki:Unlabelled Name',
    ]);
  });

  test('a Netflix play is searched as anime only, never in Wikipedia, and stays unticked', () async {
    gateway.malSearchAnime['played anime'] = [mal(507, 'Played Anime')];
    gateway.malCatalog[507] = anilist(24, 'Played Anime', idMal: 507);
    final m = await one(
      rec('Played Anime', confirmed: false, screenOnly: true),
    );
    expect(m.titleId, 'anilist:24');
    expect(m.included, isFalse);
    await one(rec('Played Drama', confirmed: false, screenOnly: true));
    expect(gateway.lookupLog, [
      'mal-anime:Played Anime',
      'mal-anime:Played Drama',
    ]);
  });

  test('dramas, series and films never use the anime fallbacks', () async {
    await ImportMatcher(catalog).match([
      rec('Some Drama', kind: MediaKind.kdrama),
      rec('Some Film', kind: MediaKind.movie),
    ]);
    expect(gateway.lookupLog, isEmpty);
  });

  test('names are sent in batches of eight', () async {
    await ImportMatcher(catalog).match([
      for (var i = 0; i < 10; i++)
        rec('Missing Title $i', kind: MediaKind.anime),
    ]);
    expect(gateway.lookupLog.where((l) => l.startsWith('mal-')), hasLength(10));
    expect(
      gateway.lookupLog.where((l) => l.startsWith('wiki:')),
      hasLength(10),
    );
  });

  test(
    'an offline catalog leaves titles unchecked and skips the fallbacks',
    () async {
      gateway.offline = true;
      final m = await one(rec('Anything', kind: MediaKind.anime));
      expect(m.unchecked, isTrue);
      expect(gateway.lookupLog, isEmpty);
    },
  );

  test(
    'an older Worker without the routes is asked once, then skipped',
    () async {
      useGateway(_OldWorker());
      final out = await ImportMatcher(catalog).match([
        for (var i = 0; i < 10; i++)
          rec('Old Worker $i', kind: MediaKind.anime),
      ]);
      expect(out.every((m) => m.matchClass == MatchClass.unresolved), isTrue);
      expect(gateway.lookupLog, ['mal-missing', 'wiki-missing']);
    },
  );
}
