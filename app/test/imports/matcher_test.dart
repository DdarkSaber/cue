import 'package:cue/data/catalog_repository.dart';
import 'package:cue/data/catalog_gateway.dart';
import 'package:cue/domain/models/library.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/imports/matcher.dart';
import 'package:cue/imports/records.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

NormalizedRecord rec(
  String title, {
  MediaKind? kind,
  int? year,
  List<String> alts = const [],
}) => NormalizedRecord(
  sourceEntryKey: 'k:$title',
  title: title,
  kind: kind,
  year: year,
  altTitles: alts,
  state: LibraryState.completed,
);

void main() {
  group('cleanQuery', () {
    test('straightens quotes and drops trailing parentheses', () {
      expect(
        cleanQuery('Academy’s Genius Swordmaster'),
        "Academy's Genius Swordmaster",
      );
      expect(cleanQuery('Overgeared (2020)'), 'Overgeared');
      expect(cleanQuery('Itaewon Class (webtoon)'), 'Itaewon Class');
      expect(cleanQuery('One Piece (live action)'), 'One Piece');
    });

    test('removes season, part, all-seasons and trilogy suffixes', () {
      expect(cleanQuery('Squid Game Season 2'), 'Squid Game');
      expect(cleanQuery('Gintama All Seasons'), 'Gintama');
      expect(cleanQuery('Kizumonogatari Trilogy'), 'Kizumonogatari');
      expect(cleanQuery('Detective Conan: Part 2'), 'Detective Conan');
    });

    test('a bare trailing number is only a sequel for shows', () {
      expect(
        cleanQuery('The Uncanny Counter 2', screen: true),
        'The Uncanny Counter',
      );
      expect(cleanQuery('Mob Psycho 100'), 'Mob Psycho 100');
      expect(
        cleanQuery('Blade Runner 2049', screen: false),
        'Blade Runner 2049',
      );
    });

    test('ordinal seasons and trailing punctuation are dropped', () {
      expect(cleanQuery('Some Show 2nd Season'), 'Some Show');
      expect(cleanQuery('Some Show Final Season'), 'Some Show');
      expect(cleanQuery('Some Show,'), 'Some Show');
    });

    test('never returns an empty query', () {
      expect(cleanQuery('(2020)'), '(2020)');
    });
  });

  group('similarity', () {
    test('identical, punctuation-only and apostrophe differences are 1', () {
      expect(
        similarity(
          'Trash of the Count’s Family',
          "trash of the count's family",
        ),
        1,
      );
      expect(similarity('Re:Zero', 're zero'), 1);
    });

    test('fan names score high, unrelated titles low', () {
      expect(
        similarity('Murim Login', 'Log-in Murim'),
        greaterThan(ImportMatcher.similarThreshold),
      );
      expect(
        similarity('Infinite Mage', 'The Infinite Mage'),
        greaterThan(ImportMatcher.similarThreshold),
      );
      expect(
        similarity('Demonic Evolution', 'The Devil Never Cries'),
        lessThan(ImportMatcher.similarThreshold),
      );
      expect(similarity('Bleach', 'Naruto'), lessThan(0.5));
    });

    test('a title that starts another at a word boundary is similar', () {
      expect(
        similarity('A Silent Voice', 'A Silent Voice: The Movie'),
        greaterThanOrEqualTo(0.9),
      );
    });
  });

  group('matching against a catalog', () {
    late FakeGateway gateway;
    late CatalogRepository catalog;
    setUp(() async {
      final db = memoryDb();
      addTearDown(db.close);
      gateway = FakeGateway();
      catalog = CatalogRepository(db, gateway);
    });

    Map<String, dynamic> hit(
      int id,
      String name, {
      String kind = 'anime',
      int? year,
    }) => {...item(id, kind: kind, year: year), 'titleEn': name};

    test('a franchise row matches despite a different year', () async {
      gateway.matchCatalog['bleach'] = [hit(1, 'Bleach', year: 2004)];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Bleach', kind: MediaKind.anime, year: 2001)])).single;
      expect(m.matchClass, MatchClass.suggested);
      expect(m.titleId, 'anilist:1');
    });

    test('two shows with one name are told apart by year', () async {
      gateway.matchCatalog['big mouth'] = [
        hit(10, 'Big Mouth', kind: 'series', year: 2017),
        hit(11, 'Big Mouth', kind: 'kdrama', year: 2022),
      ];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Big Mouth', kind: MediaKind.kdrama, year: 2022)])).single;
      expect(m.titleId, 'anilist:11');
    });

    test(
      'a similar title is offered, unticked, not linked or cached',
      () async {
        gateway.matchCatalog['murim login'] = [
          hit(5, 'Log-in Murim', kind: 'manhwa'),
        ];
        final m = (await ImportMatcher(
          catalog,
        ).match([rec('Murim Login', kind: MediaKind.manhwa)])).single;
        expect(m.matchClass, MatchClass.similar);
        expect(m.included, isFalse);
        expect(m.candidateName, 'Log-in Murim');
        expect(await catalog.titleById('anilist:5'), isNull);
      },
    );

    test('nothing close is unresolved, not a guess', () async {
      gateway.matchCatalog['demonic evolution'] = [
        hit(6, 'The Devil Never Cries', kind: 'manhua'),
      ];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Demonic Evolution', kind: MediaKind.manhua)])).single;
      expect(m.matchClass, MatchClass.unresolved);
      expect(m.unchecked, isFalse);
    });

    test(
      'a failed lookup is reported as not checked, never as no match',
      () async {
        gateway.offline = true;
        final m = (await ImportMatcher(
          catalog,
        ).match([rec('Anything', kind: MediaKind.anime)])).single;
        expect(m.matchClass, MatchClass.unresolved);
        expect(m.unchecked, isTrue);
      },
    );

    test('reading kinds match across mislabelled manga and manhwa', () async {
      gateway.matchCatalog['solo thing'] = [
        hit(7, 'Solo Thing', kind: 'manhwa'),
      ];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Solo Thing', kind: MediaKind.manga)])).single;
      expect(m.matchClass, MatchClass.suggested);
    });

    test('the search text is cleaned before it leaves the device', () async {
      gateway.matchCatalog['overgeared'] = [
        hit(8, 'Overgeared', kind: 'manhwa'),
      ];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Overgeared (2020)', kind: MediaKind.manhwa)])).single;
      expect(m.matchClass, MatchClass.suggested);
    });
  });

  group('harder titles', () {
    late FakeGateway gateway;
    late CatalogRepository catalog;
    setUp(() {
      final db = memoryDb();
      addTearDown(db.close);
      gateway = FakeGateway();
      catalog = CatalogRepository(db, gateway);
    });

    test('spacing differences still match exactly', () async {
      gateway.matchCatalog['konna ni kawaii'] = [
        {...item(1), 'titleEn': 'Konnani Kawaii'},
      ];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Konna ni Kawaii', kind: MediaKind.anime)])).single;
      expect(m.matchClass, MatchClass.suggested);
    });

    test('a long title is found from its first words', () async {
      gateway.matchCatalog['my gift lvl'] = [
        {...item(2), 'titleEn': 'My Gift Lvl 9999 Unlimited Gacha'},
      ];
      final m = (await ImportMatcher(catalog).match([
        rec(
          'My Gift Lvl 9999 Unlimited Gacha Clearing Hell Dungeon',
          kind: MediaKind.anime,
          alts: const ['My Gift Lvl'],
        ),
      ])).single;
      expect(m.resolved, isTrue);
    });

    test('adult-rated titles are reported hidden, never linked', () async {
      gateway.adultCatalog['some adult show'] = [
        {...item(3, adult: true), 'titleEn': 'Some Adult Show'},
      ];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Some Adult Show', kind: MediaKind.anime)])).single;
      expect(m.adultHidden, isTrue);
      expect(m.resolved, isFalse);
      expect(m.included, isFalse);
    });

    test('unconfirmed records arrive unticked', () async {
      gateway.matchCatalog['played show'] = [
        {...item(4), 'titleEn': 'Played Show'},
      ];
      final m = (await ImportMatcher(catalog).match([
        const NormalizedRecord(
          sourceEntryKey: 'k:Played Show',
          title: 'Played Show',
          state: LibraryState.partial,
          confirmed: false,
          screenOnly: true,
        ),
      ])).single;
      expect(m.resolved, isTrue);
      expect(m.included, isFalse);
    });

    test('MangaUpdates names resolve a comic nobody else lists', () async {
      gateway.mangaUpdatesCatalog['wo de shi jie'] = [
        AliasCandidateDto(
          names: ['Wo De Shi Jie', '我的世界'],
          lang: 'zh',
          item: CatalogItemDto({
            ...item(
              55,
              provider: 'mangaupdates',
              kind: 'manhua',
              country: 'CN',
            ),
            'titleEn': 'My World',
          }),
        ),
      ];
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Wo De Shi Jie', kind: MediaKind.manhua)])).single;
      expect(m.matchClass, MatchClass.suggested);
      expect(m.titleId, 'mangaupdates:55');
    });
  });

  group('many names for one comic', () {
    late FakeGateway gateway;
    late CatalogRepository catalog;
    setUp(() {
      final db = memoryDb();
      addTearDown(db.close);
      gateway = FakeGateway();
      catalog = CatalogRepository(db, gateway);
    });

    Map<String, dynamic> comic(
      int id,
      String name, {
      String kind = 'manhwa',
      List<String> synonyms = const [],
    }) => {
      ...item(id, kind: kind, country: kind == 'manhua' ? 'CN' : 'KR'),
      'titleEn': name,
      'synonyms': synonyms,
    };

    test(
      'an alternate name AniList lists as a synonym is an exact match',
      () async {
        gateway.matchCatalog['murim login'] = [
          comic(5, 'Log-in Murim', synonyms: ['Murim Login']),
        ];
        final m = (await ImportMatcher(
          catalog,
        ).match([rec('Murim Login', kind: MediaKind.manhwa)])).single;
        expect(m.matchClass, MatchClass.suggested);
        expect(m.titleId, 'anilist:5');
      },
    );

    test(
      'a name only another database knows is resolved through its AniList link',
      () async {
        gateway.aliasCatalog["trash of the count's family"] = [
          const AliasCandidateDto(
            names: [
              'Baekjakga ui Mangnani ga Doeeotda',
              'Trash of the Count’s Family',
            ],
            al: 9,
            lang: 'ko',
          ),
        ];
        gateway.aniListById[9] = comic(9, 'Lout of Count’s Family');
        final m = (await ImportMatcher(catalog).match([
          rec('Trash of the Count’s Family', kind: MediaKind.manhwa),
        ])).single;
        expect(m.matchClass, MatchClass.suggested);
        expect(m.titleId, 'anilist:9');
        expect(await catalog.titleById('anilist:9'), isNotNull);
      },
    );

    test('with no AniList link it falls back to the MyAnimeList id', () async {
      gateway.aliasCatalog['some fan name'] = [
        const AliasCandidateDto(names: ['Some Fan Name'], mal: 77, lang: 'ko'),
      ];
      gateway.malCatalog[77] = {...comic(12, 'Official Name'), 'idMal': 77};
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Some Fan Name', kind: MediaKind.manhwa)])).single;
      expect(m.titleId, 'anilist:12');
    });

    test(
      'a Chinese work is never offered for a manhwa, and the reverse',
      () async {
        gateway.aliasCatalog['cultivation thing'] = [
          const AliasCandidateDto(
            names: ['Cultivation Thing'],
            al: 3,
            lang: 'zh',
          ),
        ];
        gateway.aniListById[3] = comic(
          3,
          'Official Cultivation',
          kind: 'manhua',
        );
        final wrong = (await ImportMatcher(
          catalog,
        ).match([rec('Cultivation Thing', kind: MediaKind.manhwa)])).single;
        expect(wrong.matchClass, MatchClass.unresolved);
        final right = (await ImportMatcher(
          catalog,
        ).match([rec('Cultivation Thing', kind: MediaKind.manhua)])).single;
        expect(right.titleId, 'anilist:3');
      },
    );

    test('a different work with a similar name is not taken: the typed name must be one of its names', () async {
      gateway.aliasCatalog['demonic evolution'] = [
        const AliasCandidateDto(names: ['Wo, Jinhua, Emo'], al: 4, lang: 'zh'),
      ];
      gateway.aniListById[4] = comic(4, 'Me, Evolution, Emo', kind: 'manhua');
      final m = (await ImportMatcher(
        catalog,
      ).match([rec('Demonic Evolution', kind: MediaKind.manhua)])).single;
      expect(m.matchClass, MatchClass.unresolved);
    });

    test('alias lookups are only made for comics', () async {
      await ImportMatcher(catalog).match([
        rec('Nothing Here', kind: MediaKind.anime),
        rec('Nor Here', kind: MediaKind.kdrama),
      ]);
      expect(gateway.aliasCalls, 0);
    });

    test(
      'a failing alias lookup leaves the title in review, not an error',
      () async {
        gateway.matchCatalog['x'] = const [];
        final failing = _AliasFails(gateway);
        final c = CatalogRepository(catalog.db, failing);
        final m = (await ImportMatcher(
          c,
        ).match([rec('X', kind: MediaKind.manhwa)])).single;
        expect(m.matchClass, MatchClass.unresolved);
      },
    );
  });
}

/// A gateway whose alias service is down but whose catalog still answers.
class _AliasFails extends FakeGateway {
  _AliasFails(FakeGateway inner) {
    matchCatalog.addAll(inner.matchCatalog);
  }

  @override
  Future<List<List<AliasCandidateDto>>> aliases(
    List<String> names, {
    String source = 'mangadex',
  }) async => throw const CatalogUnavailable('offline');
}
