import 'package:cue/domain/models/deck_filters.dart';
import 'package:cue/domain/models/quick_mood.dart';
import 'package:cue/domain/models/title.dart';
import 'package:cue/domain/mood_rules.dart';
import 'package:cue/domain/ranker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('varied local format and genre synonyms use word boundaries', () {
    final cases = <String, (Set<MediaKind>, Set<String>)>{
      'funny Korean dramas': ({MediaKind.kdrama}, {'comedy'}),
      'a romantic comedy movie': ({MediaKind.movie}, {'romance', 'comedy'}),
      'science-fiction anime': ({MediaKind.anime}, {'sci-fi'}),
      'psychological mysteries in manga': (
        {MediaKind.manga},
        {'psychological', 'mystery'},
      ),
      'supernatural webtoons': ({MediaKind.manhwa}, {'supernatural'}),
      'slice-of-life Japanese drama': ({MediaKind.jdrama}, {'slice of life'}),
      'adventurous Chinese dramas': ({MediaKind.cdrama}, {'adventure'}),
    };
    for (final c in cases.entries) {
      final parsed = parseMood(c.key);
      expect(parsed.kinds, c.value.$1, reason: c.key);
      expect(parsed.genres, c.value.$2, reason: c.key);
    }
    expect(parseMood('showcase horrifying romanticism').kinds, isEmpty);
    expect(parseMood('showcase horrifying romanticism').genres, isEmpty);
  });

  test('pace differs from duration and moods are explicit preferences', () {
    for (final phrase in [
      'fast paced',
      'snappy',
      'slow burn',
      'gentle',
      'high octane',
    ]) {
      final p = parseMood('$phrase comedy k-drama');
      expect(p.shortOnly, isFalse, reason: phrase);
      expect(p.genres, {'comedy'});
      expect(p.understood.join(' '), contains('pace preference'));
      expect(p.feedback, contains('not guarantees'));
    }
    for (final phrase in [
      'few episodes',
      'miniseries',
      'quick watch',
      'short season',
    ]) {
      expect(parseMood('$phrase anime').shortOnly, isTrue, reason: phrase);
    }
    expect(parseMood('suspenseful film').mood, QuickMood.gripping);
    expect(parseMood('wholesome anime').mood, QuickMood.comfort);
    expect(parseMood('tearjerker series').mood, QuickMood.feels);
    expect(parseMood('energetic anime').mood, QuickMood.hype);
    expect(parseMood('completed anime').status, StatusFilter.finished);
    expect(parseMood('still airing webtoon').status, StatusFilter.ongoing);
  });

  test('bounded negation excludes genres and formats, not positive hints', () {
    final p = parseMood('comedy without horror or romance, but anime');
    expect(p.genres, {'comedy'});
    expect(p.excludedGenres, {'horror', 'romance'});
    expect(p.kinds, {MediaKind.anime});
    expect(p.mood, QuickMood.comfort);
    expect(parseMood("don't want movies; prefer manga").excludedKinds, {
      MediaKind.movie,
    });
    expect(parseMood('not slow anime').unrecognised, contains('not slow'));
    expect(parseMood('never rewatch').rewatches, isFalse);
    expect(parseMood('no cliffhanger anime').status, StatusFilter.any);
    expect(parseMood('not only comedy but romance').isEmpty, isTrue);
    expect(parseMood('comedy or romance anime').genres, isEmpty);
    expect(parseMood('comedy or romance anime').unrecognised, isNotEmpty);
  });

  test('unknown text is reported even in partially recognised phrases', () {
    final p = parseMood('funny anime with teleporting potatoes');
    expect(p.genres, {'comedy'});
    expect(p.unrecognised, ['teleporting', 'potatoes']);
    expect(p.feedback, contains('Not mapped to filters'));
    expect(parseMood('purple elephant').isEmpty, isTrue);
  });

  test(
    'editing Tell me removes its stale constraints, retaining manual ones',
    () {
      final first = parseMood('short comedy anime without horror').applyTo(
        const DeckFilters(countries: {'JP'}),
        'short comedy anime without horror',
      );
      final next = parseMood('ongoing fantasy manga')
          .applyTo(first, 'ongoing fantasy manga');
      expect(next.genres, {'fantasy'});
      expect(next.kinds, {MediaKind.manga});
      expect(next.excludedGenres, isEmpty);
      expect(next.shortOnly, isFalse);
      expect(next.status, StatusFilter.ongoing);
      expect(next.countries, {'JP'});
    },
  );

  test('negative genre constraints are hard, including unknown metadata', () {
    final f = parseMood('anime without horror')
        .applyTo(const DeckFilters(), 'anime without horror');
    final ranker = Ranker();
    bool allowed(List<String> genres) => ranker.eligible(
      Title(
        id: 'synthetic',
        titleEn: 'Invented',
        kind: MediaKind.anime,
        genres: genres,
      ),
      const ProfileSignals(),
      f,
      showAdult: false,
      enabledKinds: {MediaKind.anime},
    );
    expect(allowed(['Comedy']), isTrue);
    expect(allowed(['Comedy', 'Horror']), isFalse);
    expect(allowed([]), isFalse);
    final noMatches = ranker.explainEmpty(
      [
        const Title(
          id: 'synthetic',
          titleEn: 'Invented',
          kind: MediaKind.anime,
          genres: ['Horror'],
        ),
      ],
      const ProfileSignals(),
      f,
      showAdult: false,
      enabledKinds: {MediaKind.anime},
    );
    expect(noMatches.message, contains('excluded genres'));
  });
}
