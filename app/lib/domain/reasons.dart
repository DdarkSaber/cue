import 'models/deck_filters.dart';
import 'models/library.dart';
import 'models/quick_mood.dart';
import 'models/title.dart';
import 'mood_tags.dart';
import 'ranker.dart';

const maxReasonLength = 60;

String _fit(String s) => s.length <= maxReasonLength
    ? s
    : '${s.substring(0, maxReasonLength - 1).trimRight()}…';

/// One true, templated line. Never claims personalisation it does not have.
String reasonFor(
  Title t,
  ProfileSignals s,
  DeckFilters f, {
  required Map<String, Title> titlesById,
  DateTime? now,
}) {
  final entry = s.library[t.id];

  if (f.isRevisit && entry?.rating != null) {
    final mood = entry!.rewatchMood?.label;
    if (entry.rating == Rating.rewatched) {
      return _fit(
        mood == null
            ? 'You rewatched this.'
            : 'You rewatched this. Your $mood pick.',
      );
    }
    return _fit(
      mood == null
          ? 'You said you would rewatch it.'
          : 'Would rewatch. Your $mood pick.',
    );
  }

  if (t.kind.isReading &&
      entry?.state == LibraryState.caughtUp &&
      entry?.progressValue != null) {
    return _fit(
      'You are caught up at chapter ${entry!.progressValue!.round()}.',
    );
  }

  // Taste-seeded: a provider's "more like this" list for a title you liked.
  for (final seedId in s.becauseOf[t.id] ?? const <String>[]) {
    final seed = titlesById[seedId];
    if (seed == null || seed.id == t.id) continue;
    const lead = 'Because you liked ';
    const room = maxReasonLength - lead.length - 1;
    var name = seed.displayTitle;
    if (name.length > room) {
      name = '${name.substring(0, room - 1).trimRight()}…';
    }
    return _fit('$lead$name.');
  }

  // A highly rated title that shares at least two features.
  if (s.evidenceTitles > 0) {
    final features = t.features;
    Title? best;
    var bestOverlap = 1;
    Rating? bestRating;
    for (final e in s.library.values) {
      final r = e.rating;
      if (r == null || r.weight < 2) continue;
      final other = titlesById[e.titleId];
      if (other == null || other.id == t.id) continue;
      if (other.franchiseKey == t.franchiseKey) continue;
      final overlap = other.features.intersection(features).length;
      if (overlap > bestOverlap) {
        best = other;
        bestOverlap = overlap;
        bestRating = r;
      }
    }
    if (best != null) {
      final mood = _dominantMood(features);
      final verb = switch (bestRating!) {
        Rating.rewatched => 'which you rewatched',
        Rating.favourite => 'a favourite of yours',
        Rating.enjoyed => 'which you enjoyed',
        _ => 'which you would rewatch',
      };
      final lead = mood == null ? 'Like' : '${mood.label} like';
      final room = maxReasonLength - lead.length - verb.length - 4;
      var name = best.displayTitle;
      if (name.length > room && room > 8) {
        name = '${name.substring(0, room - 1).trimRight()}…';
      }
      return _fit('$lead $name, $verb.');
    }
  }

  if (f.mood != QuickMood.forYou && f.mood != QuickMood.revisit) {
    final hits = t.features.intersection(moodTags[f.mood]!).toList()..sort();
    if (hits.isNotEmpty) {
      return _fit('${f.mood.label} pick: ${hits.take(2).join(', ')}.');
    }
  }

  if (s.tasteConfidence > 0 &&
      s.weakHistoryIds.any((id) {
        final other = titlesById[id];
        return other != null &&
            other.id != t.id &&
            other.features.intersection(t.features).length >= 2;
      })) {
    return _fit('Shares themes with your imports; not a confirmed like.');
  }

  // Cold start: describe the work, not the person.
  final genres = t.genres.take(2).map((g) => g.toLowerCase()).toList();
  if (genres.isNotEmpty) {
    final scoreNote = t.score != null && t.score! >= 80 ? 'Highly rated ' : '';
    return _fit(
      '$scoreNote${genres.join(' and ')} ${t.kind.label.toLowerCase()}.'
          .replaceFirstMapped(RegExp('^[a-z]'), (m) => m[0]!.toUpperCase()),
    );
  }
  return _fit('A ${t.kind.label.toLowerCase()} to discover.');
}

QuickMood? _dominantMood(Set<String> features) {
  QuickMood? best;
  var hits = 0;
  for (final e in moodTags.entries) {
    final n = features.where(e.value.contains).length;
    if (n > hits) {
      hits = n;
      best = e.key;
    }
  }
  return best;
}
