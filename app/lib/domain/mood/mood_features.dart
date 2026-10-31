import '../models/title.dart';
import 'vec.dart';

/// short | mid | long, or null when the length is unknown.
String? lenBucket(Title t) {
  if (t.kind == MediaKind.movie) return 'short';
  if (t.kind.isReading) {
    final c = t.chapters;
    if (c == null) return null;
    return c <= 60 ? 'short' : (c <= 200 ? 'mid' : 'long');
  }
  final fromSeasons = t.seasons.fold<int>(0, (s, x) => s + (x.episodes ?? 0));
  final eps = fromSeasons > 0 ? fromSeasons : t.episodes;
  if (eps == null) return null;
  return eps <= 13 ? 'short' : (eps <= 50 ? 'mid' : 'long');
}

/// What the mood learner sees of a title: its genres and tags plus derived
/// facts (kind, length, quality band, era, country). Derived names carry a
/// prefix so they never clash with genre names.
Set<String> moodFeatures(Title t) {
  final len = lenBucket(t);
  final s = t.score;
  final y = t.year;
  return {
    ...t.features,
    'kind:${t.kind.name}',
    if (len != null) 'len:$len',
    if (s != null) 'q:${s >= 80 ? 'high' : (s >= 65 ? 'mid' : 'low')}',
    if (y != null) 'era:${y >= 2018 ? 'new' : (y >= 2008 ? 'mid' : 'classic')}',
    if (t.country != null) 'cc:${t.country}',
  };
}

/// Derived features are useful for matching but not for labels.
bool isDerivedFeature(String f) => f.contains(':');

/// Derived facts (kind, length, ...) are shared by very different titles,
/// so they count half as much as genres and tags.
const derivedWeight = 0.5;

Vec featureVec(Set<String> features) => {
  for (final f in features) f: isDerivedFeature(f) ? derivedWeight : 1.0,
};
