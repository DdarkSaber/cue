import 'models/deck_filters.dart';
import 'models/quick_mood.dart';
import 'models/title.dart';

/// Bounded local phrase rules, not general natural-language understanding.
class MoodParse {
  const MoodParse({
    this.kinds = const {},
    this.genres = const {},
    this.excludedKinds = const {},
    this.excludedGenres = const {},
    this.mood,
    this.shortOnly = false,
    this.era = EraFilter.any,
    this.status = StatusFilter.any,
    this.rewatches = false,
    this.understood = const [],
    this.unrecognised = const [],
  });

  final Set<MediaKind> kinds;
  final Set<String> genres;
  final Set<MediaKind> excludedKinds;
  final Set<String> excludedGenres;
  final QuickMood? mood;
  final bool shortOnly;
  final EraFilter era;
  final StatusFilter status;
  final bool rewatches;
  final List<String> understood;
  final List<String> unrecognised;
  bool get isEmpty => understood.isEmpty;

  String get feedback => [
    if (understood.isNotEmpty) 'Read locally: ${understood.join(', ')}.',
    if (unrecognised.isNotEmpty)
      'Not mapped to filters: ${unrecognised.join(' ')}.',
    'Mood and pace are preferences, not guarantees. Format, genre, duration and completion constraints use known catalog metadata.',
  ].join(' ');

  DeckFilters applyTo(DeckFilters f, String text) {
    final previous = parseMood(f.tellMe ?? '');
    return f.copyWith(
      kinds: kinds.isNotEmpty
          ? kinds
          : previous.kinds.isEmpty
          ? f.kinds
          : {},
      genres: {...f.genres.difference(previous.genres), ...genres},
      excludedKinds: {
        ...f.excludedKinds.difference(previous.excludedKinds),
        ...excludedKinds,
      },
      excludedGenres: {
        ...f.excludedGenres.difference(previous.excludedGenres),
        ...excludedGenres,
      },
      mood: rewatches
          ? QuickMood.revisit
          : mood ??
                (previous.mood != null || previous.rewatches
                    ? QuickMood.forYou
                    : f.mood),
      shortOnly: shortOnly || (f.shortOnly && !previous.shortOnly),
      era: era != EraFilter.any
          ? era
          : previous.era == EraFilter.any
          ? f.era
          : EraFilter.any,
      status: status != StatusFilter.any
          ? status
          : previous.status == StatusFilter.any
          ? f.status
          : StatusFilter.any,
      tellMe: text,
    );
  }
}

const moodGenres = <String, String>{
  'action': 'Action',
  'adventure': 'Adventure',
  'comedy': 'Comedy',
  'romance': 'Romance',
  'mystery': 'Mystery',
  'thriller': 'Thriller',
  'horror': 'Horror',
  'fantasy': 'Fantasy',
  'sports': 'Sports',
  'sci-fi': 'Sci-Fi',
  'slice of life': 'Slice of Life',
  'psychological': 'Psychological',
  'supernatural': 'Supernatural',
};

const _genres = <String, Set<String>>{
  'action': {'action'},
  'adventure': {'adventure'},
  'adventurous': {'adventure'},
  'comedy': {'comedy'},
  'comedies': {'comedy'},
  'funny': {'comedy'},
  'humor': {'comedy'},
  'humour': {'comedy'},
  'laugh': {'comedy'},
  'romance': {'romance'},
  'romantic': {'romance'},
  'rom com': {'romance', 'comedy'},
  'romcom': {'romance', 'comedy'},
  'romantic comedy': {'romance', 'comedy'},
  'romantic comedies': {'romance', 'comedy'},
  'mystery': {'mystery'},
  'mysteries': {'mystery'},
  'thriller': {'thriller'},
  'thrillers': {'thriller'},
  'horror': {'horror'},
  'scary': {'horror'},
  'fantasy': {'fantasy'},
  'sports': {'sports'},
  'sport': {'sports'},
  'science fiction': {'sci-fi'},
  'sci fi': {'sci-fi'},
  'scifi': {'sci-fi'},
  'slice of life': {'slice of life'},
  'psychological': {'psychological'},
  'supernatural': {'supernatural'},
};

const _kinds = <String, Set<MediaKind>>{
  'anime': {MediaKind.anime},
  'animes': {MediaKind.anime},
  'cartoon': {MediaKind.anime},
  'cartoons': {MediaKind.anime},
  'manhwa': {MediaKind.manhwa},
  'webtoon': {MediaKind.manhwa},
  'webtoons': {MediaKind.manhwa},
  'manhua': {MediaKind.manhua},
  'manga': {MediaKind.manga},
  'comic': {MediaKind.manga, MediaKind.manhwa, MediaKind.manhua},
  'comics': {MediaKind.manga, MediaKind.manhwa, MediaKind.manhua},
  'read': {MediaKind.manga, MediaKind.manhwa, MediaKind.manhua},
  'kdrama': {MediaKind.kdrama},
  'kdramas': {MediaKind.kdrama},
  'k drama': {MediaKind.kdrama},
  'k dramas': {MediaKind.kdrama},
  'korean drama': {MediaKind.kdrama},
  'korean dramas': {MediaKind.kdrama},
  'cdrama': {MediaKind.cdrama},
  'c drama': {MediaKind.cdrama},
  'chinese drama': {MediaKind.cdrama},
  'chinese dramas': {MediaKind.cdrama},
  'jdrama': {MediaKind.jdrama},
  'j drama': {MediaKind.jdrama},
  'japanese drama': {MediaKind.jdrama},
  'japanese dramas': {MediaKind.jdrama},
  'drama': {MediaKind.kdrama, MediaKind.cdrama, MediaKind.jdrama},
  'dramas': {MediaKind.kdrama, MediaKind.cdrama, MediaKind.jdrama},
  'series': {MediaKind.series},
  'tv series': {MediaKind.series},
  'show': {MediaKind.series},
  'shows': {MediaKind.series},
  'sitcom': {MediaKind.series},
  'movie': {MediaKind.movie},
  'movies': {MediaKind.movie},
  'film': {MediaKind.movie},
  'films': {MediaKind.movie},
};

const _moods = <String, QuickMood>{
  'hype': QuickMood.hype,
  'pumped': QuickMood.hype,
  'energetic': QuickMood.hype,
  'energy': QuickMood.hype,
  'adrenaline': QuickMood.hype,
  'epic': QuickMood.hype,
  'motivating': QuickMood.hype,
  'motivational': QuickMood.hype,
  'comfort': QuickMood.comfort,
  'cozy': QuickMood.comfort,
  'cosy': QuickMood.comfort,
  'chill': QuickMood.comfort,
  'relaxing': QuickMood.comfort,
  'relax': QuickMood.comfort,
  'lighthearted': QuickMood.comfort,
  'light hearted': QuickMood.comfort,
  'wholesome': QuickMood.comfort,
  'calm': QuickMood.comfort,
  'feel good': QuickMood.comfort,
  'tired': QuickMood.comfort,
  'gripping': QuickMood.gripping,
  'suspense': QuickMood.gripping,
  'suspenseful': QuickMood.gripping,
  'tense': QuickMood.gripping,
  'twists': QuickMood.gripping,
  'twisty': QuickMood.gripping,
  'feels': QuickMood.feels,
  'emotional': QuickMood.feels,
  'touching': QuickMood.feels,
  'tearjerker': QuickMood.feels,
  'sad': QuickMood.feels,
  'heartwarming': QuickMood.feels,
};
const _pace = {
  'fast',
  'fast paced',
  'quick paced',
  'high octane',
  'slow',
  'slow paced',
  'slow burn',
  'gentle',
  'snappy',
};
const _short = {
  'short',
  'short season',
  'short series',
  'few episodes',
  'mini series',
  'miniseries',
  'one season',
  'quick watch',
};
const _new = {'new', 'newer', 'recent', 'latest', 'fresh', 'new art'};
const _old = {'old', 'older', 'classic', 'retro', 'nostalgic', '90s', '2000s'};
const _finished = {'finished', 'completed', 'complete', 'ended'};
const _ongoing = {'ongoing', 'still airing', 'airing', 'unfinished'};
const _rewatch = {
  'rewatch',
  're watch',
  'reread',
  're read',
  'revisit',
  'again',
};
const _filler = {
  'i',
  'a',
  'an',
  'the',
  'some',
  'any',
  'something',
  'to',
  'me',
  'please',
  'would',
  'like',
  'feel',
  'feeling',
  'for',
  'of',
  'it',
  'that',
  'is',
  'are',
  'my',
  'in',
  'on',
  'can',
  'you',
};

MoodParse parseMood(String input) {
  if (RegExp(
    r'\b(not only|not necessarily|anything but|not too|not very|not really)\b',
    caseSensitive: false,
  ).hasMatch(input)) {
    return MoodParse(unrecognised: [input.trim()]);
  }
  final normal = input
      .toLowerCase()
      .replaceAll("don't", 'do not')
      .replaceAll('do not want', 'avoid')
      .replaceAll(RegExp(r'[-_]'), ' ')
      .replaceAll(RegExp(r'[.,;!?]'), ' | ')
      .replaceAll(RegExp(r'[^a-z0-9| ]'), ' ');
  final words = normal
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final phrases =
      {
          ..._kinds.keys,
          ..._genres.keys,
          ..._moods.keys,
          ..._pace,
          ..._short,
          ..._new,
          ..._old,
          ..._finished,
          ..._ongoing,
          ..._rewatch,
        }.toList()
        ..sort((a, b) => b.split(' ').length.compareTo(a.split(' ').length));
  final kinds = <MediaKind>{}, excludedKinds = <MediaKind>{};
  final genres = <String>{}, excludedGenres = <String>{};
  final understood = <String>{}, unknown = <String>[];
  QuickMood? mood;
  var short = false, revisit = false, negated = false;
  var positiveOr = false;
  var era = EraFilter.any, status = StatusFilter.any;
  for (var i = 0; i < words.length;) {
    final w = words[i];
    if ({'|', 'but', 'with', 'want', 'prefer', 'include'}.contains(w)) {
      negated = false;
      i++;
      continue;
    }
    if ({'no', 'not', 'without', 'avoid', 'exclude', 'never'}.contains(w)) {
      negated = true;
      i++;
      continue;
    }
    if ({'and', 'or'}.contains(w)) {
      if (w == 'or' && !negated) positiveOr = true;
      i++;
      continue;
    }
    String? found;
    for (final phrase in phrases) {
      final parts = phrase.split(' ');
      if (i + parts.length <= words.length &&
          words.sublist(i, i + parts.length).join(' ') == phrase) {
        found = phrase;
        break;
      }
    }
    if (found == null) {
      if (!_filler.contains(w)) {
        unknown.add(negated ? 'not $w' : w);
        negated = false;
      }
      i++;
      continue;
    }
    i += found.split(' ').length;
    if (_kinds.containsKey(found)) {
      (negated ? excludedKinds : kinds).addAll(_kinds[found]!);
    } else if (_genres.containsKey(found)) {
      (negated ? excludedGenres : genres).addAll(_genres[found]!);
    } else if (negated) {
      unknown.add('not $found');
    } else if (_pace.contains(found)) {
      understood.add('$found (pace preference)');
    } else if (_moods.containsKey(found)) {
      mood = _moods[found];
    } else if (_short.contains(found)) {
      short = true;
    } else if (_new.contains(found)) {
      era = EraFilter.newArt;
    } else if (_old.contains(found)) {
      era = EraFilter.classic;
    } else if (_finished.contains(found)) {
      status = StatusFilter.finished;
    } else if (_ongoing.contains(found)) {
      status = StatusFilter.ongoing;
    } else if (_rewatch.contains(found)) {
      revisit = true;
    }
  }
  if (positiveOr && genres.length > 1) {
    genres.clear();
    unknown.add(
      'genre alternatives with "or" (choose Genre filters explicitly)',
    );
  }
  if (kinds.isNotEmpty) {
    understood.add(
      kinds.length > 2 && kinds.every((k) => k.isReading)
          ? 'Something to read'
          : kinds.map((k) => k.label).join(', '),
    );
  }
  for (final k in excludedKinds) {
    understood.add('No ${k.label}');
  }
  for (final g in genres) {
    understood.add(moodGenres[g]!);
  }
  for (final g in excludedGenres) {
    understood.add('No ${moodGenres[g]}');
  }
  mood ??= genres.contains('comedy')
      ? QuickMood.comfort
      : genres.contains('romance')
      ? QuickMood.feels
      : genres.contains('mystery') || genres.contains('thriller')
      ? QuickMood.gripping
      : genres.contains('action') || genres.contains('sports')
      ? QuickMood.hype
      : null;
  if (mood != null) understood.add('${mood.label} (mood preference)');
  if (short) {
    understood.add('Short (up to 13 episodes / 60 chapters, or a film)');
  }
  if (era != EraFilter.any) {
    understood.add(era == EraFilter.newArt ? 'New art' : 'Classic');
  }
  if (status != StatusFilter.any) {
    understood.add(status == StatusFilter.finished ? 'Finished' : 'Ongoing');
  }
  if (revisit) understood.add('Revisit');
  return MoodParse(
    kinds: kinds,
    genres: genres,
    excludedKinds: excludedKinds,
    excludedGenres: excludedGenres,
    mood: mood,
    shortOnly: short,
    era: era,
    status: status,
    rewatches: revisit,
    understood: understood.toList(),
    unrecognised: unknown,
  );
}
