/// A personal rating. Unrated is null, never a low score.
enum Rating {
  favourite('favourite', 'Favourite', 3),
  rewatched('rewatched', 'Rewatched', 3),
  wouldRewatch('would_rewatch', 'Would rewatch', 2),
  once('once', 'Once was enough', 1.5),
  okay('okay', 'Okay', 0.5),
  disliked('disliked', 'Disliked', -1),
  dropped('dropped', 'Dropped', -1.5);

  const Rating(this.code, this.label, this.weight);
  final String code;
  final String label;

  /// Taste evidence per the ranker rules.
  final double weight;

  bool get isRewatch => this == rewatched || this == wouldRewatch;

  static Rating? parse(String? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// Library state. "Seen" is not "completed".
enum LibraryState {
  none('none', 'No status'),
  watching('watching', 'Watching'),
  reading('reading', 'Reading'),
  completed('completed', 'Completed'),
  seen('seen', 'Seen'),
  onHold('on_hold', 'On hold'),
  dropped('dropped', 'Dropped'),
  planned('planned', 'Planned'),
  caughtUp('caught_up', 'Caught up'),
  partial('partial', 'Partly seen');

  const LibraryState(this.code, this.label);
  final String code;
  final String label;

  /// States that take a title out of unseen discovery.
  bool get isSeen =>
      this == completed ||
      this == seen ||
      this == dropped ||
      this == caughtUp ||
      this == watching ||
      this == reading ||
      this == partial ||
      this == onHold;

  static LibraryState parse(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => LibraryState.none);
}

/// The four quick moods plus nostalgia, used for rewatch moods.
enum RewatchMood {
  hype('hype', 'Hype'),
  comfort('comfort', 'Comfort'),
  gripping('gripping', 'Gripping'),
  feels('feels', 'Feels'),
  nostalgia('nostalgia', 'Nostalgia');

  const RewatchMood(this.code, this.label);
  final String code;
  final String label;

  static RewatchMood? parse(String? code) {
    final c = code?.toLowerCase();
    for (final m in values) {
      if (m.code == c) return m;
    }
    return null;
  }
}

/// One row of the personal library, as the domain sees it.
class LibraryEntry {
  const LibraryEntry({
    required this.titleId,
    this.state = LibraryState.none,
    this.rating,
    this.rewatchMood,
    this.actualWatchedAt,
    this.progressUnit,
    this.progressValue,
    this.latestKnown,
  });

  final String titleId;
  final LibraryState state;
  final Rating? rating;
  final RewatchMood? rewatchMood;
  final DateTime? actualWatchedAt;
  final String? progressUnit;
  final double? progressValue;
  final double? latestKnown;
}
