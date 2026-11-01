import 'models/deck_filters.dart';
import 'models/quick_mood.dart';
import 'models/title.dart';

/// What the local "Tell me" rules understood from a sentence.
class MoodParse {
  const MoodParse({
    this.kinds = const {},
    this.genres = const {},
    this.mood,
    this.shortOnly = false,
    this.era = EraFilter.any,
    this.rewatches = false,
    this.understood = const [],
  });

  final Set<MediaKind> kinds;
  final Set<String> genres;
  final QuickMood? mood;
  final bool shortOnly;
  final EraFilter era;
  final bool rewatches;

  /// Plain-language pieces, shown back to the person ("Comfort", "Short").
  final List<String> understood;

  bool get isEmpty => understood.isEmpty;

  DeckFilters applyTo(DeckFilters f, String text) => f.copyWith(
    kinds: kinds.isEmpty ? f.kinds : kinds,
    genres: genres.isEmpty ? f.genres : genres,
    mood: rewatches ? QuickMood.revisit : (mood ?? f.mood),
    shortOnly: shortOnly || f.shortOnly,
    era: era == EraFilter.any ? f.era : era,
    tellMe: text,
  );
}

const moodGenres = <String, String>{
  'action': 'Action',
  'comedy': 'Comedy',
  'romance': 'Romance',
  'mystery': 'Mystery',
  'thriller': 'Thriller',
  'horror': 'Horror',
  'fantasy': 'Fantasy',
  'sports': 'Sports',
};

const _kindWords = <String, Set<MediaKind>>{
  'anime': {MediaKind.anime},
  'cartoon': {MediaKind.anime},
  'manhwa': {MediaKind.manhwa},
  'webtoon': {MediaKind.manhwa},
  'manhua': {MediaKind.manhua},
  'manga': {MediaKind.manga},
  'comic': {MediaKind.manga, MediaKind.manhwa, MediaKind.manhua},
  'read': {MediaKind.manga, MediaKind.manhwa, MediaKind.manhua},
  'kdrama': {MediaKind.kdrama},
  'k-drama': {MediaKind.kdrama},
  'korean drama': {MediaKind.kdrama},
  'cdrama': {MediaKind.cdrama},
  'c-drama': {MediaKind.cdrama},
  'chinese drama': {MediaKind.cdrama},
  'jdrama': {MediaKind.jdrama},
  'j-drama': {MediaKind.jdrama},
  'japanese drama': {MediaKind.jdrama},
  'drama': {MediaKind.kdrama, MediaKind.cdrama, MediaKind.jdrama},
  'series': {MediaKind.series},
  'show': {MediaKind.series},
  'sitcom': {MediaKind.series},
  'movie': {MediaKind.movie},
  'film': {MediaKind.movie},
};

const _moodWords = <QuickMood, List<String>>{
  QuickMood.hype: [
    'hype',
    'pumped',
    'energy',
    'energetic',
    'action',
    'sports',
    'fight',
    'battle',
    'motivat',
    'adrenaline',
    'epic',
  ],
  QuickMood.comfort: [
    'comfort',
    'cozy',
    'cosy',
    'chill',
    'relax',
    'light',
    'funny',
    'comedy',
    'laugh',
    'tired',
    'wholesome',
    'calm',
    'easy',
    'feel good',
    'feel-good',
  ],
  QuickMood.gripping: [
    'gripping',
    'thrill',
    'mystery',
    'crime',
    'dark',
    'twist',
    'suspense',
    'mind',
    'detective',
    'intense',
    'smart',
  ],
  QuickMood.feels: [
    'feels',
    'romance',
    'romantic',
    'love',
    'cry',
    'sad',
    'emotional',
    'heart',
    'tears',
    'touching',
  ],
};

/// Local keyword rules for "Tell me what you feel like". No network.
MoodParse parseMood(String input) {
  final text =
      ' ${input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\- ]'), ' ')} ';
  final understood = <String>[];

  final kinds = <MediaKind>{};
  // Longest phrases first so "korean drama" wins over "drama".
  final phrases = _kindWords.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  var rest = text;
  for (final p in phrases) {
    final re = RegExp('[ ]${RegExp.escape(p)}s?[ ]');
    if (re.hasMatch(rest)) {
      kinds.addAll(_kindWords[p]!);
      rest = rest.replaceAll(re, ' ');
    }
  }
  if (kinds.isNotEmpty) {
    understood.add(
      kinds.length > 2 && kinds.every((k) => k.isReading)
          ? 'Something to read'
          : kinds.map((k) => k.label).join(', '),
    );
  }

  final genres = <String>{
    for (final g in moodGenres.keys)
      if (RegExp('\\b${RegExp.escape(g)}\\b').hasMatch(text)) g,
    if (RegExp(r'\b(funny|laugh|humour|humor)\b').hasMatch(text)) 'comedy',
    if (RegExp(r'\b(romcom|rom-com|rom com)\b').hasMatch(text)) ...{
      'romance',
      'comedy',
    },
  };
  if (genres.isNotEmpty) {
    understood.addAll(genres.map((g) => moodGenres[g]!));
  }

  QuickMood? mood;
  var bestHits = 0;
  for (final e in _moodWords.entries) {
    final hits = e.value.where(text.contains).length;
    if (hits > bestHits) {
      bestHits = hits;
      mood = e.key;
    }
  }
  if (mood != null) understood.add(mood.label);

  final shortOnly = RegExp(
    r'\b(short|quick|mini|few episodes|one season|weekend|binge)\b',
  ).hasMatch(text);
  if (shortOnly) understood.add('Short');

  var era = EraFilter.any;
  if (RegExp(r'\b(new|newer|recent|latest|fresh|this year|202[3-9])\b')
      .hasMatch(text)) {
    era = EraFilter.newArt;
    understood.add('New art');
  } else if (RegExp(r'\b(old|older|classic|retro|90s|2000s|nostalgi)')
      .hasMatch(text)) {
    era = EraFilter.classic;
    understood.add('Classic');
  }

  final rewatches = RegExp(r'\b(rewatch|again|re-watch|reread|re-read)\b')
      .hasMatch(text);
  if (rewatches) understood.add('Revisit');

  return MoodParse(
    kinds: kinds,
    genres: genres,
    mood: mood,
    shortOnly: shortOnly,
    era: era,
    rewatches: rewatches,
    understood: understood,
  );
}
