import '../domain/learning/learned_taste.dart';
import '../domain/learning/replay.dart';
import '../domain/learning/swipe_model.dart';
import '../domain/models/decision.dart';
import '../domain/models/title.dart';
import 'card_signal_repository.dart';
import 'catalog_repository.dart';
import 'outcome_stats_repository.dart';

/// Rebuilds the swipe model from what is already on the device: the deck
/// decisions and how each card was looked at. Nothing is stored for the
/// model itself, so an undo, an import or a restore can never leave it out
/// of step with the history; it is simply built again.
class LearnedTasteRepository {
  LearnedTasteRepository(this.outcomes, this.signals, this.catalog);

  final OutcomeStatsRepository outcomes;
  final CardSignalRepository signals;
  final CatalogRepository catalog;

  /// A card that was looked at closely but not answered with Will try or
  /// Not interested still says something. A rejected card's details were
  /// opened to decide against it, and a saved card already counts in full.
  static ({double label, double weight})? implicit(CardSignal s) {
    final d = s.decision == null ? null : Decision.parse(s.decision!);
    if (d == Decision.willTry || d == Decision.notInterested) return null;
    return implicitLabel(
      dwell: Duration(milliseconds: s.dwellMs),
      openedDetails: s.openedDetails,
      heldPoster: s.heldPoster,
    );
  }

  /// Every lesson in time order: decisions, then weaker implicit signals.
  Future<List<ReplayEvent>> lessons(String profileId) async {
    final events = await outcomes.replayEvents(profileId);
    final seen = await signals.recent(profileId);
    final weak = [
      for (final s in seen)
        if (implicit(s) != null) s,
    ];
    final titles = {
      for (final t in await catalog.titlesByIds(
        weak.map((s) => s.titleId).toSet(),
      ))
        t.id: t,
    };
    return [
      ...events,
      for (final s in weak)
        if (titles[s.titleId] case final t?)
          ReplayEvent(
            t,
            implicit(s)!.label,
            weight: implicit(s)!.weight,
            at: s.shownAt,
          ),
    ]..sort((a, b) => a.at.compareTo(b.at));
  }

  /// The model trained on this profile's history. [pool] fixes how rare
  /// each tag is; [seeded] marks titles a liked title's list recommended.
  Future<LearnedTaste> build(
    String profileId, {
    required Iterable<Title> pool,
    Set<String> seeded = const {},
  }) async {
    final taste = LearnedTaste(
      SwipeModel(),
      idf: featureIdf(pool),
      seeded: seeded,
    );
    for (final e in await lessons(profileId)) {
      taste.learn(e.title, e.label, e.weight);
    }
    return taste;
  }
}

/// The swipe model as a replay subject: how well it would have ranked each
/// card just before the person answered it.
class SwipeModelScorer implements ReplayScorer {
  SwipeModelScorer({Map<String, double> idf = const {}})
    : _taste = LearnedTaste(SwipeModel(), idf: idf);

  final LearnedTaste _taste;

  @override
  double predict(Title t) => _taste.model.predict(_taste.vector(t));

  @override
  void learn(Title t, double label, double weight) =>
      _taste.learn(t, label, weight);
}
