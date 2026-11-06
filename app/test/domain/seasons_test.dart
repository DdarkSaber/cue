import 'dart:math';

import 'package:cue/data/anilist_client.dart';
import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/ranker.dart';
import 'package:flutter_test/flutter_test.dart';

Title show(
  String id, {
  List<int> continues = const [],
  String? franchise,
  String format = 'TV',
}) => Title(
  id: id,
  kind: MediaKind.anime,
  titleEn: 'Invented show $id',
  format: format,
  status: 'finished',
  year: 2015,
  genres: const ['Comedy'],
  continues: continues,
  franchiseId: franchise,
);

void main() {
  final ranker = Ranker(random: Random(1));
  final all = {...MediaKind.discoverable};
  bool ok(Title t, ProfileSignals s, [DeckFilters f = const DeckFilters()]) =>
      ranker.eligible(t, s, f, showAdult: false, enabledKinds: all);

  group('AniList season links', () {
    Map<String, Object?> edge(String type, int id, [String t = 'ANIME']) => {
      'relationType': type,
      'node': {'id': id, 'type': t},
    };

    test('a later season continues its prequel; adaptations do not count', () {
      final j = AniListClient.normalize({
        'id': 30,
        'type': 'ANIME',
        'relations': {
          'edges': [
            edge('PREQUEL', 20),
            edge('SEQUEL', 40),
            edge('ADAPTATION', 5, 'MANGA'),
          ],
        },
      }).json;
      expect(j['continues'], [20]);
      expect(j['franchiseKey'], 'anilist:20');
    });

    test('films share the main series as their franchise', () {
      final j = AniListClient.normalize({
        'id': 900,
        'type': 'ANIME',
        'format': 'MOVIE',
        'relations': {
          'edges': [edge('PREQUEL', 800), edge('PARENT', 21)],
        },
      }).json;
      expect(j['continues'], containsAll([800, 21]));
      expect(j['franchiseKey'], 'anilist:21');
    });

    test('an OVA prequel does not make a TV series a sequel', () {
      final j = AniListClient.normalize({
        'id': 11111,
        'type': 'ANIME',
        'format': 'TV',
        'relations': {
          'edges': [
            {
              'relationType': 'PREQUEL',
              'node': {'id': 1, 'type': 'ANIME', 'format': 'OVA'},
            },
          ],
        },
      }).json;
      expect(j['continues'], isEmpty);
    });

    test('a standalone title continues nothing', () {
      final j = AniListClient.normalize({
        'id': 7,
        'type': 'ANIME',
        'relations': {'edges': <Object>[]},
      }).json;
      expect(j['continues'], isEmpty);
    });
  });

  group('season 1 is the way in', () {
    final season3 = show('s3', continues: [20]);

    test('a later season is not dealt cold', () {
      expect(ok(season3, const ProfileSignals()), isFalse);
      expect(ok(show('s1'), const ProfileSignals()), isTrue);
    });

    test('it is dealt once what it follows was seen', () {
      expect(ok(season3, const ProfileSignals(seenAnilist: {20})), isTrue);
    });

    test('a film of an unseen series waits too', () {
      final film = show('film', continues: [21], format: 'MOVIE');
      expect(ok(film, const ProfileSignals()), isFalse);
      expect(ok(film, const ProfileSignals(seenAnilist: {21})), isTrue);
    });
  });

  test('a franchise already dealt this session is skipped', () {
    final pool = [
      for (var i = 0; i < 4; i++) show('op$i', franchise: 'anilist:21'),
      for (var i = 0; i < 12; i++) show('other$i'),
    ];
    final deck = ranker.deal(
      pool,
      const ProfileSignals(),
      const DeckFilters(),
      showAdult: false,
      enabledKinds: all,
      titlesById: const {},
      skipFranchises: {'anilist:21'},
    );
    expect(deck, isNotEmpty);
    expect(deck.where((c) => c.title.id.startsWith('op')), isEmpty);
  });
}
