import 'package:cue/data/catalog_repository.dart';
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
}
