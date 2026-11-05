import 'package:cue/domain/models/title.dart';
import 'package:flutter_test/flutter_test.dart';

Title _t(
  MediaKind kind, {
  int? episodes,
  int? chapters,
  List<Season> seasons = const [],
  String status = 'finished',
}) => Title(
  id: 'x',
  kind: kind,
  episodes: episodes,
  chapters: chapters,
  seasons: seasons,
  status: status,
);

void main() {
  group('reading', () {
    for (final kind in [MediaKind.manga, MediaKind.manhwa, MediaKind.manhua]) {
      test('${kind.label}: finished, ongoing and unknown chapter counts', () {
        expect(_t(kind, chapters: 120).lengthLabel, '120 chapters');
        expect(_t(kind, chapters: 1).lengthLabel, '1 chapter');
        expect(
          _t(kind, chapters: 120, status: 'ongoing').lengthLabel,
          'Ongoing · 120+ chapters',
        );
        expect(_t(kind).lengthLabel, 'Chapters unknown');
        expect(
          _t(kind, status: 'ongoing').lengthLabel,
          'Ongoing · chapters unknown',
        );
      });
    }

    test('episodes never stand in for chapters', () {
      expect(
        _t(MediaKind.manhwa, episodes: 12).lengthLabel,
        'Chapters unknown',
      );
    });
  });

  group('watching', () {
    const three = [
      Season(number: 1, episodes: 24),
      Season(number: 2, episodes: 24),
      Season(number: 3, episodes: 16),
    ];

    for (final kind in [
      MediaKind.anime,
      MediaKind.kdrama,
      MediaKind.cdrama,
      MediaKind.jdrama,
      MediaKind.series,
    ]) {
      test('${kind.label}: seasons and episodes', () {
        expect(
          _t(kind, seasons: three, episodes: 24).lengthLabel,
          '3 seasons · 64 episodes',
        );
        expect(_t(kind, episodes: 24).lengthLabel, '24 episodes');
        expect(_t(kind, episodes: 1).lengthLabel, '1 episode');
      });
    }

    test('one listed season reads as its episodes', () {
      expect(
        _t(
          MediaKind.anime,
          episodes: 12,
          seasons: const [Season(number: 1, episodes: 12)],
        ).lengthLabel,
        '12 episodes',
      );
    });

    test('a season with an unknown count drops the total, not the seasons', () {
      expect(
        _t(
          MediaKind.series,
          episodes: 10,
          seasons: const [Season(number: 1, episodes: 10), Season(number: 2)],
        ).lengthLabel,
        '2 seasons',
      );
    });

    test('unknown length: airing says so, otherwise nothing', () {
      expect(_t(MediaKind.anime, status: 'airing').lengthLabel, 'Airing');
      expect(_t(MediaKind.anime).lengthLabel, isNull);
    });
  });

  test('movies have no length (the catalog has no runtime)', () {
    expect(_t(MediaKind.movie, episodes: 1).lengthLabel, isNull);
  });
}
