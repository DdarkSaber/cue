import 'dart:convert';

import '../../data/db/database.dart';

/// What a title is. Reading kinds use "Read it" instead of "Watched".
enum MediaKind {
  anime('Anime'),
  manga('Manga'),
  manhwa('Manhwa'),
  manhua('Manhua'),
  kdrama('K-drama'),
  cdrama('C-drama'),
  jdrama('J-drama'),
  series('Series'),
  movie('Movie'),
  unknown('Unknown');

  const MediaKind(this.label);
  final String label;

  bool get isReading => this == manga || this == manhwa || this == manhua;

  /// Kinds the catalog can discover (unknown is import-only).
  static const discoverable = [
    anime,
    manhwa,
    manhua,
    manga,
    kdrama,
    cdrama,
    jdrama,
    series,
    movie,
  ];

  static MediaKind parse(String? raw) => MediaKind.values.firstWhere(
    (k) => k.name == raw,
    orElse: () => MediaKind.unknown,
  );
}

class Season {
  const Season({required this.number, this.episodes, this.year});
  final int number;
  final int? episodes;
  final int? year;

  factory Season.fromJson(Map<String, dynamic> j) => Season(
    number: (j['number'] as num).toInt(),
    episodes: (j['episodes'] as num?)?.toInt(),
    year: (j['year'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'episodes': episodes,
    'year': year,
  };
}

/// A catalog title as the domain sees it. Unknown values stay null.
class Title {
  const Title({
    required this.id,
    required this.kind,
    this.titleEn,
    this.titleRomaji,
    this.titleNative,
    this.year,
    this.country,
    this.format,
    this.status = 'unknown',
    this.episodes,
    this.chapters,
    this.seasons = const [],
    this.genres = const [],
    this.tags = const [],
    this.score,
    this.posterUrl,
    this.backdropUrl,
    this.synopsis,
    this.franchiseId,
    this.continues = const [],
    this.adult = false,
    this.detailed = false,
  });

  final String id;
  final MediaKind kind;
  final String? titleEn;
  final String? titleRomaji;
  final String? titleNative;
  final int? year;
  final String? country;
  final String? format;
  final String status;
  final int? episodes;
  final int? chapters;
  final List<Season> seasons;
  final List<String> genres;
  final List<String> tags;
  final int? score;
  final String? posterUrl;
  final String? backdropUrl;
  final String? synopsis;
  final String? franchiseId;

  /// AniList ids of what this entry follows: an earlier season, or the main
  /// series of a film/special. Empty when unknown or standalone.
  final List<int> continues;
  final bool adult;
  final bool detailed;

  String get displayTitle =>
      titleEn ?? titleRomaji ?? titleNative ?? 'Untitled';

  /// Romaji or native title when it differs from the display title.
  String? get altTitle {
    for (final t in [titleRomaji, titleNative]) {
      if (t != null && t.trim().isNotEmpty && t != displayTitle) return t;
    }
    return null;
  }

  /// Lower-cased genres and tags: the vocabulary the ranker scores on.
  Set<String> get features => {
    for (final g in genres) g.toLowerCase(),
    for (final t in tags) t.toLowerCase(),
  };

  /// "New art" for 2023 and later; "Classic" before 2010; else nothing.
  String? get artEra {
    if (year == null) return null;
    if (year! >= 2023) return 'New art';
    if (year! < 2010) return 'Classic';
    return null;
  }

  /// How long the title is, for the card meta and the details sheet.
  ///
  /// Reading: "120 chapters"; while releasing the count is only the latest
  /// known one, so "Ongoing · 120+ chapters"; "Chapters unknown" without a
  /// count. Watching: "3 seasons · 64 episodes" when several seasons are
  /// listed (episodes only when every season's count is known), else
  /// "24 episodes" / "1 episode"; "Airing" or null when unknown. Movies:
  /// null (no runtime in the catalog).
  String? get lengthLabel {
    if (kind == MediaKind.movie) return null;
    if (kind.isReading) {
      final ongoing = status == 'ongoing';
      final count = chapters;
      if (count == null) {
        return ongoing ? 'Ongoing · chapters unknown' : 'Chapters unknown';
      }
      if (ongoing) return 'Ongoing · $count+ chapters';
      return _count(count, 'chapter');
    }
    if (seasons.length > 1) {
      final perSeason = [for (final s in seasons) s.episodes];
      final total = perSeason.contains(null)
          ? null
          : perSeason.fold<int>(0, (n, e) => n + e!);
      return [
        '${seasons.length} seasons',
        if (total != null && total > 0) _count(total, 'episode'),
      ].join(' · ');
    }
    if (episodes != null) return _count(episodes!, 'episode');
    return status == 'airing' ? 'Airing' : null;
  }

  static String _count(int n, String noun) =>
      n == 1 ? '1 $noun' : '$n ${noun}s';

  /// Franchise grouping: the provider hint, else a normalised base title.
  String get franchiseKey {
    if (franchiseId != null) return franchiseId!;
    final base = displayTitle
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'(season|part|cour|the movie|movie|2nd|3rd|\d+th|final)\b.*$',
          ),
          '',
        )
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return '${kind.isReading ? 'r' : 'w'}:$base';
  }

  factory Title.fromRow(CatalogTitle r) => Title(
    id: r.id,
    kind: MediaKind.parse(r.mediaKind),
    titleEn: r.titleEn,
    titleRomaji: r.titleRomaji,
    titleNative: r.titleNative,
    year: r.year,
    country: r.country,
    format: r.format,
    status: r.status,
    episodes: r.episodes,
    chapters: r.chapters,
    seasons: [
      for (final s in jsonDecode(r.seasonsJson) as List)
        Season.fromJson(s as Map<String, dynamic>),
    ],
    genres: List<String>.from(jsonDecode(r.genresJson) as List),
    tags: List<String>.from(jsonDecode(r.tagsJson) as List),
    score: r.score,
    posterUrl: r.posterUrl,
    backdropUrl: r.backdropUrl,
    synopsis: r.synopsis,
    franchiseId: r.franchiseId,
    continues: r.continuesJson == null
        ? const []
        : List<int>.from(jsonDecode(r.continuesJson!) as List),
    adult: r.adult,
    detailed: r.detailed,
  );
}
