import 'quick_mood.dart';
import 'title.dart';

enum EraFilter { any, newArt, classic }

enum StatusFilter { any, finished, ongoing }

/// Contextual filters from the sheet and the mood rail. Temporary: they
/// never change saved settings.
class DeckFilters {
  const DeckFilters({
    this.kinds = const {},
    this.mood = QuickMood.forYou,
    this.shortOnly = false,
    this.era = EraFilter.any,
    this.status = StatusFilter.any,
    this.countries = const {},
    this.includeRewatches = false,
    this.tellMe,
  });

  /// Empty means "every kind enabled in Settings".
  final Set<MediaKind> kinds;
  final QuickMood mood;

  /// 13 episodes or fewer (or a film).
  final bool shortOnly;
  final EraFilter era;
  final StatusFilter status;

  /// ISO country codes; empty means any.
  final Set<String> countries;
  final bool includeRewatches;

  /// The sentence the person typed, kept for the summary only.
  final String? tellMe;

  bool get isRevisit => mood == QuickMood.revisit;

  /// Count of constraints beyond the mood, for the filter badge.
  int get activeCount =>
      (kinds.isEmpty ? 0 : 1) +
      (shortOnly ? 1 : 0) +
      (era == EraFilter.any ? 0 : 1) +
      (status == StatusFilter.any ? 0 : 1) +
      (countries.isEmpty ? 0 : 1) +
      (includeRewatches ? 1 : 0);

  DeckFilters copyWith({
    Set<MediaKind>? kinds,
    QuickMood? mood,
    bool? shortOnly,
    EraFilter? era,
    StatusFilter? status,
    Set<String>? countries,
    bool? includeRewatches,
    String? tellMe,
    bool clearTellMe = false,
  }) => DeckFilters(
    kinds: kinds ?? this.kinds,
    mood: mood ?? this.mood,
    shortOnly: shortOnly ?? this.shortOnly,
    era: era ?? this.era,
    status: status ?? this.status,
    countries: countries ?? this.countries,
    includeRewatches: includeRewatches ?? this.includeRewatches,
    tellMe: clearTellMe ? null : (tellMe ?? this.tellMe),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckFilters &&
      other.mood == mood &&
      other.shortOnly == shortOnly &&
      other.era == era &&
      other.status == status &&
      other.includeRewatches == includeRewatches &&
      // The typed text feeds the mood learner, so a new sentence re-deals.
      other.tellMe == tellMe &&
      other.kinds.length == kinds.length &&
      other.kinds.containsAll(kinds) &&
      other.countries.length == countries.length &&
      other.countries.containsAll(countries);

  @override
  int get hashCode => Object.hash(
    mood,
    shortOnly,
    era,
    status,
    includeRewatches,
    tellMe,
    Object.hashAllUnordered(kinds),
    Object.hashAllUnordered(countries),
  );
}
