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

    test(
      'conflicting supplied aliases stay ambiguous both locally and remotely',
      () async {
        final works = [
          {...item(81), 'titleEn': 'Invented Alias Alpha'},
          {...item(82), 'titleEn': 'Invented Alias Beta'},
        ];
        gateway.matchCatalog['invented alias alpha'] = [works.first];
        gateway.matchCatalog['invented alias beta'] = [works.last];
        var result = (await ImportMatcher(catalog).match([
          rec(
            'Invented Missing Name',
            kind: MediaKind.anime,
            alts: ['Invented Alias Alpha', 'Invented Alias Beta'],
          ),
        ])).single;
        expect(result.included, isFalse);
        expect(result.matchClass, MatchClass.similar);
        result = (await ImportMatcher(catalog).match([
          rec(
            'Invented Alias Alpha',
            kind: MediaKind.anime,
            alts: ['Invented Alias Beta'],
          ),
        ])).single;
        expect(result.included, isFalse);
        expect(result.matchClass, MatchClass.similar);
        await catalog.upsert(works.map(CatalogItemDto.new).toList());
        result = (await ImportMatcher(catalog).match([
          rec(
            'Invented Alias Alpha',
            kind: MediaKind.anime,
            alts: ['Invented Alias Beta'],
          ),
        ], offlineOnly: true)).single;
        expect(result.included, isFalse);
        expect(result.resolved, isFalse);
      },
    );

    test(
      'offline title matching cannot reintroduce cached adult or novel entries',
      () async {
        await catalog.upsert([
          CatalogItemDto({
            ...item(83, adult: true),
            'titleEn': 'Invented Hidden Work',
          }),
          CatalogItemDto({
            ...item(84, kind: 'manga'),
            'titleEn': 'Invented Novel',
            'format': 'NOVEL',
          }),
        ]);
        final results = await ImportMatcher(catalog).match([
          rec('Invented Hidden Work', kind: MediaKind.anime),
          rec('Invented Novel', kind: MediaKind.manga),
        ], offlineOnly: true);
        expect(results.map((m) => m.included), everyElement(isFalse));
        expect(results.map((m) => m.resolved), everyElement(isFalse));
      },
    );

    test('seasons, parts and adaptations are never silently collapsed for anime or movies', () async {
      for (final (kind, imported) in [
        (MediaKind.anime, 'Invented Explorer Season 2'),
        (MediaKind.anime, 'Invented Explorer (Final Season)'),
        (MediaKind.movie, 'Invented Explorer Part 2'),
      ]) {
        gateway.matchCatalog
          ..clear()
          ..[imported.toLowerCase()] = [
            {...item(61, kind: kind.name), 'titleEn': 'Invented Explorer'},
          ];
        final result = (await ImportMatcher(
          catalog,
        ).match([rec(imported, kind: kind)])).single;
        expect(result.included, isFalse);
        expect(result.matchClass, isNot(MatchClass.suggested));
      }
    });

    test(
      'multiple aliases of the same identity still auto-resolve once',
      () async {
        final same = {
          ...item(44),
          'titleEn': 'Invented Official Name',
          'synonyms': ['Invented Fan Name', 'Invented Other Name'],
        };
        gateway.matchCatalog['invented fan name'] = [same, same];
        final result = (await ImportMatcher(catalog).match([
          rec(
            'Invented Fan Name',
            kind: MediaKind.anime,
            alts: ['Invented Other Name'],
          ),
        ])).single;
        expect(result.matchClass, MatchClass.suggested);
        expect(result.included, isTrue);
        expect(result.titleId, 'anilist:44');
      },
    );

    test(
      'an ambiguous comic is not arbitrarily resolved by a later alias source',
      () async {
        gateway.matchCatalog['invented shared comic'] = [
          {...item(41, kind: 'manhwa'), 'titleEn': 'Invented Shared Comic'},
          {...item(42, kind: 'manhwa'), 'titleEn': 'Invented Shared Comic'},
        ];
        gateway.aliasCatalog['invented shared comic'] = [
          const AliasCandidateDto(
            names: ['Invented Shared Comic'],
            al: 41,
            lang: 'ko',
          ),
        ];
        gateway.aniListById[41] = {
          ...item(41, kind: 'manhwa'),
          'titleEn': 'Invented Shared Comic',
        };
        final result = (await ImportMatcher(
          catalog,
        ).match([rec('Invented Shared Comic', kind: MediaKind.manhwa)])).single;
        expect(result.matchClass, MatchClass.similar);
        expect(result.included, isFalse);
      },
    );

    test('unlabelled comics can resolve through verified alias IDs', () async {
      gateway.aliasCatalog['invented obscure alias'] = [
        const AliasCandidateDto(names: ['Invented Obscure Alias'], al: 70),
      ];
      gateway.aniListById[70] = {
        ...item(70, kind: 'manhwa'),
        'titleEn': 'Invented Official Comic',
      };
      for (final kind in [null, MediaKind.unknown]) {
        final result = (await ImportMatcher(
          catalog,
        ).match([rec('Invented Obscure Alias', kind: kind)])).single;
        expect(result.matchClass, MatchClass.suggested);
        expect(result.titleId, 'anilist:70');
      }
    });

    test(
      'uncached AniList IDs resolve before title search for anime and comics',
      () async {
        gateway.aniListById[31] = {
          ...item(31),
          'titleEn': 'Invented official anime',
        };
        gateway.aniListById[32] = {
          ...item(32, kind: 'manhwa'),
          'titleEn': 'Invented official comic',
        };
        final matches = await ImportMatcher(catalog).match([
          const NormalizedRecord(
            sourceEntryKey: 'anime-id',
            title: 'Unsearchable alias',
            kind: MediaKind.anime,
            anilistId: 31,
            confirmed: false,
          ),
          const NormalizedRecord(
            sourceEntryKey: 'comic-id',
            title: 'Another unsearchable alias',
            kind: MediaKind.manga,
            anilistId: 32,
          ),
        ]);
        expect(
          matches.map((m) => m.matchClass),
          everyElement(MatchClass.exactId),
        );
        expect(matches.map((m) => m.titleId), ['anilist:31', 'anilist:32']);
        expect(matches.first.included, isFalse);
        expect(gateway.matchCalls, 0);
      },
    );

    test(
      'MAL anime and manga IDs never collide in the local catalog',
      () async {
        await catalog.upsert([
          CatalogItemDto({...item(1, idMal: 55), 'titleEn': 'Invented anime'}),
          CatalogItemDto({
            ...item(2, idMal: 55, kind: 'manhwa'),
            'titleEn': 'Invented comic',
          }),
        ]);
        final matches = await ImportMatcher(catalog).match([
          const NormalizedRecord(
            sourceEntryKey: 'a',
            title: 'Imported alias',
            kind: MediaKind.anime,
            malId: 55,
          ),
          const NormalizedRecord(
            sourceEntryKey: 'b',
            title: 'Imported alias',
            kind: MediaKind.manhwa,
            malId: 55,
          ),
        ]);
        expect(matches.map((m) => m.titleId), ['anilist:1', 'anilist:2']);
      },
    );

    test(
      'later supplied aliases are searched, not just the first one',
      () async {
        gateway.matchCatalog['invented third alias'] = [
          {...item(6), 'titleEn': 'Invented third alias'},
        ];
        final result = (await ImportMatcher(catalog).match([
          rec(
            'Invented unlisted name',
            kind: MediaKind.anime,
            alts: [
              'Invented first alias',
              'Invented second alias',
              'Invented third alias',
            ],
          ),
        ])).single;
        expect(result.titleId, 'anilist:6');
        expect(result.matchClass, MatchClass.suggested);
      },
    );

    test(
      'a unique exact hit beyond the compact batch is recovered by full search',
      () async {
        gateway.searchResults['invented hidden exact title'] = [
          {...item(25), 'titleEn': 'Invented Hidden Exact Title'},
        ];
        final result = (await ImportMatcher(catalog).match([
          rec('Invented Hidden Exact Title', kind: MediaKind.anime),
        ])).single;
        expect(result.matchClass, MatchClass.suggested);
        expect(result.included, isTrue);
        expect(result.titleId, 'anilist:25');
      },
    );

    test(
      'same-name works without a unique year stay unticked, local or remote',
      () async {
        final items = [
          {...item(11, year: 2000), 'titleEn': 'Invented Shared Name'},
          {...item(12, year: 2020), 'titleEn': 'Invented Shared Name'},
        ];
        gateway.matchCatalog['invented shared name'] = items;
        var result = (await ImportMatcher(
          catalog,
        ).match([rec('Invented Shared Name', kind: MediaKind.anime)])).single;
        expect(result.matchClass, MatchClass.similar);
        expect(result.included, isFalse);
        await catalog.upsert(items.map(CatalogItemDto.new).toList());
        result = (await ImportMatcher(
          catalog,
        ).match([rec('Invented Shared Name', kind: MediaKind.anime)])).single;
        expect(result.matchClass, MatchClass.similar);
        expect(result.included, isFalse);
      },
    );

    test('novels and the wrong medium do not make comic or anime matches ambiguous', () async {
      final items = [
        {
          ...item(61, kind: 'manga'),
          'titleEn': 'Invented Shared Medium',
          'format': 'NOVEL',
        },
        {
          ...item(62, kind: 'manga'),
          'titleEn': 'Invented Shared Medium',
          'format': 'MANGA',
        },
        {...item(63), 'titleEn': 'Invented Shared Medium', 'format': 'TV'},
      ];
      gateway.matchCatalog['invented shared medium'] = items;
      for (final cached in [false, true]) {
        if (cached) {
          await catalog.upsert(items.map(CatalogItemDto.new).toList());
        }
        for (final (kind, id) in [
          (MediaKind.manga, 'anilist:62'),
          (MediaKind.anime, 'anilist:63'),
        ]) {
          final match = (await ImportMatcher(catalog).match([
            rec('Invented Shared Medium', kind: kind),
          ], offlineOnly: cached)).single;
          expect(match.titleId, id);
          expect(match.included, isTrue);
          expect(match.matchClass, isNot(MatchClass.similar));
        }
      }
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

    test('AniList and MAL alias links for the same canonical comic are not ambiguous', () async {
      gateway.aliasCatalog['invented canonical alias'] = [
        const AliasCandidateDto(names: ['Invented Canonical Alias'], al: 97),
        const AliasCandidateDto(names: ['Invented Canonical Alias'], mal: 98),
      ];
      final work = {...comic(97, 'Invented Official Name'), 'idMal': 98};
      gateway.aniListById[97] = work;
      gateway.malCatalog[98] = work;
      final result = (await ImportMatcher(catalog).match([
        rec('Invented Canonical Alias', kind: MediaKind.manhwa),
      ])).single;
      expect(result.titleId, 'anilist:97');
      expect(result.included, isTrue);
      expect(result.matchClass, MatchClass.suggested);
    });

    test(
      'ambiguous alias identities cannot be bypassed by another provider',
      () async {
        gateway.aliasCatalog['invented shared alias'] = [
          const AliasCandidateDto(names: ['Invented Shared Alias'], al: 91),
          const AliasCandidateDto(names: ['Invented Shared Alias'], al: 92),
        ];
        gateway.mangaUpdatesCatalog['invented shared alias'] = [
          AliasCandidateDto(
            names: ['Invented Shared Alias'],
            item: CatalogItemDto(comic(93, 'Invented Shared Alias')),
          ),
        ];
        gateway.searchResults['invented shared alias'] = [
          comic(91, 'Invented Shared Alias'),
        ];
        final result = (await ImportMatcher(
          catalog,
        ).match([rec('Invented Shared Alias', kind: MediaKind.manhwa)])).single;
        expect(result.included, isFalse);
        expect(result.resolved, isFalse);
        expect(await catalog.titleById('anilist:93'), isNull);
      },
    );

    test('a linked novel is not accepted as a comic', () async {
      gateway.aliasCatalog['invented novel alias'] = [
        const AliasCandidateDto(names: ['Invented Novel Alias'], al: 94),
      ];
      gateway.aniListById[94] = {
        ...comic(94, 'Invented Novel Alias'),
        'format': 'NOVEL',
      };
      final result = (await ImportMatcher(
        catalog,
      ).match([rec('Invented Novel Alias', kind: MediaKind.manhwa)])).single;
      expect(result.included, isFalse);
      expect(result.resolved, isFalse);
    });

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
