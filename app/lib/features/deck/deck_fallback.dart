import '../../domain/models/deck_filters.dart';
import '../../domain/models/title.dart';
import '../../domain/mood_rules.dart' show moodGenres;
import '../../domain/ranker.dart';

/// Which step of the fallback ladder put a card in the deck.
///
/// The deck tries [exact] first. Later steps are only reached when the
/// earlier ones cannot fill it, and every card they add says why it is here.
enum DeckRung {
  /// Matches every filter.
  exact,

  /// Matches everything except Short season; nearest known length first.
  longer,

  /// Misses one or more explicit filters; fewest misses first.
  outsideFilter,

  /// Hidden with Not now in an earlier session; nothing newer qualifies.
  backFromNotNow,
}

/// One explicit filter a card does not satisfy.
class FilterMiss {
  const FilterMiss(this.label, this.clear);

  /// Short human name of the filter, e.g. "Comedy" or "Finished".
  final String label;

  /// The same filters without this constraint.
  final DeckFilters Function(DeckFilters) clear;
}

/// Short season, the one soft length preference the ladder relaxes first.
final shortSeasonMiss = FilterMiss(
  'Short season',
  (x) => x.copyWith(shortOnly: false),
);

/// Why a relaxed card is in the deck, shown on the card and in the chip.
class DeckRelaxation {
  const DeckRelaxation(this.rung, this.label, {this.misses = const []});

  final DeckRung rung;

  /// Short honest label, e.g. "Outside your filter: Comedy".
  final String label;

  /// The explicit filters this card misses (empty for Not now returns).
  final List<FilterMiss> misses;

  /// The filters with every constraint this card misses removed.
  DeckFilters clearedFrom(DeckFilters f) {
    var next = f;
    for (final m in misses) {
      next = m.clear(next);
    }
    return next;
  }

  /// Filter names for the inline chip.
  String get filterNames => misses.map((m) => m.label).join(', ');
}

/// The cards for one deal, plus the reason for every relaxed card.
class LadderResult {
  const LadderResult(this.cards, this.relaxed);
  final List<RankedCard> cards;
  final Map<String, DeckRelaxation> relaxed;

  bool get hasExact => cards.any((c) => !relaxed.containsKey(c.title.id));

  /// No exact match was dealt and the deck is the nearest-length fallback.
  bool get lengthFallback =>
      cards.isNotEmpty &&
      !hasExact &&
      relaxed.values.every((r) => r.rung == DeckRung.longer);
}

/// Every hard exclusion still applies; only the person's explicit filters
/// (and Short season) are ever relaxed, and only with a label.
DeckFilters openFilters(DeckFilters f) =>
    DeckFilters(mood: f.mood, tellMe: f.tellMe);

/// Explicit filters [t] fails. [passes] must be the ranker's eligibility
/// check for [t] (with every hard exclusion) under the given filters.
List<FilterMiss> filterMisses(
  Title t,
  DeckFilters f,
  bool Function(DeckFilters) passes,
) {
  final open = openFilters(f);
  final misses = <FilterMiss>[];
  void check(DeckFilters only, FilterMiss miss) {
    if (!passes(only)) misses.add(miss);
  }

  if (f.kinds.isNotEmpty) {
    check(
      open.copyWith(kinds: f.kinds),
      FilterMiss(
        '${(f.kinds.toList()..sort((a, b) => a.index.compareTo(b.index))).map((k) => k.label).join(' / ')} only',
        (x) => x.copyWith(kinds: const {}),
      ),
    );
  }
  for (final g in f.genres) {
    check(
      open.copyWith(genres: {g}),
      FilterMiss(
        _genreLabel(g),
        (x) => x.copyWith(genres: {...x.genres}..remove(g)),
      ),
    );
  }
  if (f.shortOnly) {
    check(open.copyWith(shortOnly: true), shortSeasonMiss);
  }
  if (f.era != EraFilter.any) {
    check(
      open.copyWith(era: f.era),
      FilterMiss(
        f.era == EraFilter.newArt ? 'New art (2023+)' : 'Classic (before 2010)',
        (x) => x.copyWith(era: EraFilter.any),
      ),
    );
  }
  if (f.status != StatusFilter.any) {
    check(
      open.copyWith(status: f.status),
      FilterMiss(
        f.status == StatusFilter.finished ? 'Finished' : 'Still airing',
        (x) => x.copyWith(status: StatusFilter.any),
      ),
    );
  }
  if (f.countries.isNotEmpty) {
    check(
      open.copyWith(countries: f.countries),
      FilterMiss(
        'Country: ${(f.countries.toList()..sort()).map((c) => _countries[c] ?? c).join(' / ')}',
        (x) => x.copyWith(countries: const {}),
      ),
    );
  }
  for (final k in f.excludedKinds) {
    check(
      open.copyWith(excludedKinds: {k}),
      FilterMiss(
        'No ${k.label}',
        (x) => x.copyWith(excludedKinds: {...x.excludedKinds}..remove(k)),
      ),
    );
  }
  if (f.excludedGenres.isNotEmpty) {
    if (t.genres.isEmpty) {
      // Unknown genres cannot prove "without horror".
      misses.add(
        FilterMiss(
          'Genres unknown',
          (x) => x.copyWith(excludedGenres: const {}),
        ),
      );
    } else {
      for (final g in f.excludedGenres) {
        check(
          open.copyWith(excludedGenres: {g}),
          FilterMiss(
            'No ${_genreLabel(g)}',
            (x) => x.copyWith(excludedGenres: {...x.excludedGenres}..remove(g)),
          ),
        );
      }
    }
  }
  return misses;
}

/// "Longer than requested - 24 episodes", or null when the length is not
/// known (unknown lengths are never presented as nearly short).
String? longerLabel(Title t) {
  final length = knownLength(t);
  if (length == null) return null;
  return 'Longer than requested - ${t.lengthLabel ?? '$length'}';
}

/// Episodes or chapters when known, for nearest-length ordering.
int? knownLength(Title t) {
  if (t.kind == MediaKind.movie) return null;
  if (t.kind.isReading) return t.chapters;
  if (t.seasons.length > 1) {
    final total = t.seasons.fold<int>(0, (n, s) => n + (s.episodes ?? 0));
    return total > 0 ? total : null;
  }
  return t.episodes;
}

String outsideLabel(List<FilterMiss> misses) => misses.isEmpty
    ? ''
    : 'Outside your filter${misses.length > 1 ? 's' : ''}: '
          '${misses.map((m) => m.label).join(', ')}';

/// Prefixes a card's reason with its honest relaxation label.
RankedCard labelled(RankedCard c, DeckRelaxation r) =>
    RankedCard(c.title, c.score, '${r.label}. ${c.reason}'.trim());

/// Deals [pool] under [filters]; supplied by the controller so every step
/// shares the same taste, mood and session ranking.
typedef LadderDealer = List<RankedCard> Function(
  List<Title> pool,
  DeckFilters filters, {
  required int size,
  bool shortestFirst,
  ProfileSignals? using,
});

/// Eligibility with every hard exclusion (library, Not interested,
/// novels/music, franchise exclusions, adult setting, enabled formats).
typedef LadderEligible = bool Function(
  Title t,
  ProfileSignals s,
  DeckFilters f,
);

/// Fills the deck below [exact] with the nearest honest alternatives:
/// longer titles, then titles missing the fewest explicit filters, then
/// older Not now titles. Never fabricates and never relaxes hard exclusions.
LadderResult runLadder({
  required List<RankedCard> exact,
  required List<Title> pool,
  required ProfileSignals signals,
  required DeckFilters filters,
  required LadderEligible eligible,
  required LadderDealer deal,
  required int size,
  Set<String> taken = const {},
  Set<String> shown = const {},
}) {
  final cards = [...exact];
  final relaxed = <String, DeckRelaxation>{};
  final ids = {...taken, for (final c in exact) c.title.id};
  final franchises = {for (final c in exact) c.title.franchiseKey};
  int remaining() => size - cards.length;

  List<Title> fresh(Iterable<Title> candidates) {
    final list = candidates
        .where(
          (t) => !ids.contains(t.id) && !franchises.contains(t.franchiseKey),
        )
        .toList();
    final unseen = list.where((t) => !shown.contains(t.id)).toList();
    return unseen.isEmpty ? list : unseen;
  }

  void add(RankedCard c, DeckRelaxation r) {
    if (remaining() <= 0 || !ids.add(c.title.id)) return;
    if (!franchises.add(c.title.franchiseKey)) return;
    relaxed[c.title.id] = r;
    cards.add(labelled(c, r));
  }

  // Short season is a length preference: nearest known lengths first.
  var longerDealt = false;
  if (remaining() > 0 && filters.shortOnly) {
    final nearby = filters.copyWith(shortOnly: false);
    final candidates = fresh(
      pool.where(
        (t) =>
            longerLabel(t) != null &&
            eligible(t, signals, nearby) &&
            !eligible(t, signals, filters),
      ),
    );
    final dealt = deal(
      candidates,
      nearby,
      size: remaining(),
      shortestFirst: true,
    );
    for (final c in _byLength(dealt)) {
      longerDealt = true;
      add(
        c,
        DeckRelaxation(
          DeckRung.longer,
          longerLabel(c.title)!,
          misses: [shortSeasonMiss],
        ),
      );
    }
  }

  // Explicit filters exclude everything: nearest matches, labelled. Format
  // and genre filters stay strict while any match (or longer pick) exists.
  final open = openFilters(filters);
  List<FilterMiss> missesOf(Title t, ProfileSignals s) =>
      filterMisses(t, filters, (only) => eligible(t, s, only));
  if (cards.isEmpty && remaining() > 0 && filters.activeCount > 0) {
    final groups = <int, List<Title>>{};
    final missesById = <String, List<FilterMiss>>{};
    for (final t in fresh(pool.where((t) => eligible(t, signals, open)))) {
      final misses = missesOf(t, signals);
      if (misses.isEmpty) continue;
      // Unknown lengths are never presented as nearly short while known
      // longer titles are available.
      if (longerDealt &&
          misses.length == 1 &&
          identical(misses.single, shortSeasonMiss)) {
        continue;
      }
      missesById[t.id] = misses;
      (groups[misses.length] ??= []).add(t);
    }
    for (final n in groups.keys.toList()..sort()) {
      if (remaining() <= 0) break;
      for (final c in deal(groups[n]!, open, size: remaining())) {
        final misses = missesById[c.title.id]!;
        add(
          c,
          DeckRelaxation(
            DeckRung.outsideFilter,
            outsideLabel(misses),
            misses: misses,
          ),
        );
      }
    }
  }

  // Last resort: titles set aside with Not now before this session.
  if (cards.isEmpty && remaining() > 0 && signals.deferred.isNotEmpty) {
    final returning = withoutDeferred(signals);
    final candidates = pool
        .where(
          (t) =>
              signals.deferred.contains(t.id) &&
              !shown.contains(t.id) &&
              !ids.contains(t.id) &&
              !franchises.contains(t.franchiseKey) &&
              eligible(t, returning, open),
        )
        .toList();
    for (final c in deal(
      candidates,
      open,
      size: remaining(),
      using: returning,
    )) {
      final misses = missesOf(c.title, returning);
      add(
        c,
        DeckRelaxation(
          DeckRung.backFromNotNow,
          [
            'Back from Not now',
            if (misses.isNotEmpty) outsideLabel(misses),
          ].join('. '),
          misses: misses,
        ),
      );
    }
  }
  return LadderResult(cards, relaxed);
}

/// The same signals with Not now deferrals lifted (never exclusions).
ProfileSignals withoutDeferred(ProfileSignals s) => ProfileSignals(
  excluded: s.excluded,
  excludedFranchises: s.excludedFranchises,
  shortlisted: s.shortlisted,
  library: s.library,
  weights: s.weights,
  evidenceTitles: s.evidenceTitles,
  evidenceStrength: s.evidenceStrength,
  weakHistoryIds: s.weakHistoryIds,
  kindRatings: s.kindRatings,
);

/// Relaxation for one title outside the exact request (used by Undo), or
/// null when a hard exclusion still applies.
DeckRelaxation? relaxationFor(
  Title t,
  ProfileSignals signals,
  DeckFilters filters,
  LadderEligible eligible,
) {
  if (eligible(t, signals, filters)) return null;
  if (!eligible(t, signals, openFilters(filters))) return null;
  final misses = filterMisses(t, filters, (f) => eligible(t, signals, f));
  final longer = longerLabel(t);
  if (misses.length == 1 &&
      misses.single.label == 'Short season' &&
      longer != null) {
    return DeckRelaxation(DeckRung.longer, longer, misses: [shortSeasonMiss]);
  }
  return DeckRelaxation(
    DeckRung.outsideFilter,
    outsideLabel(misses),
    misses: misses,
  );
}

List<RankedCard> _byLength(List<RankedCard> cards) {
  final indexed = [for (var i = 0; i < cards.length; i++) (i, cards[i])];
  indexed.sort((a, b) {
    final byLength = (knownLength(a.$2.title) ?? 1 << 30).compareTo(
      knownLength(b.$2.title) ?? 1 << 30,
    );
    return byLength != 0 ? byLength : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

String _genreLabel(String g) =>
    moodGenres[g] ??
    g
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

const _countries = {
  'JP': 'Japan',
  'KR': 'Korea',
  'CN': 'China',
  'TW': 'Taiwan',
  'US': 'United States',
  'GB': 'United Kingdom',
  'IN': 'India',
};
