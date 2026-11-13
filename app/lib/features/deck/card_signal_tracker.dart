import '../../data/card_signal_repository.dart';
import '../../domain/models/decision.dart';
import '../../domain/ranker.dart' show RankedCard;

/// Measures how the card on top of the deck is looked at: how long it
/// stays there, and whether its details or whole poster were opened.
/// Holds one card at a time and stores nothing itself.
class CardSignalTracker {
  CardSignalTracker({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// Longest dwell stored for one card.
  static const maxDwell = Duration(minutes: 5);

  static const exploreReason = 'Exploring another eligible theme or format.';

  String? _profileId;
  String? _titleId;
  DateTime? _shownAt;
  String _slot = '';
  bool _details = false;
  bool _held = false;

  // Dwell counts only while a card is on top and the app is in front.
  Duration _counted = Duration.zero;
  DateTime? _countingSince;
  bool _paused = false;
  bool _hidden = false;

  /// The title being measured, if any.
  String? get titleId => _titleId;
  String? get profileId => _profileId;

  /// Which ranking slot produced [card].
  static String slotOf(RankedCard card) => card.becauseOf.isNotEmpty
      ? 'seeded'
      : card.reason.trim() == exploreReason
      ? 'explore'
      : 'familiar';

  void _sync() {
    final counting = _titleId != null && !_paused && !_hidden;
    final since = _countingSince;
    if (counting && since == null) {
      _countingSince = _now();
    } else if (!counting && since != null) {
      _counted += _now().difference(since);
      _countingSince = null;
    }
  }

  /// Starts measuring [card]. The same title again keeps its running dwell.
  void show(String profileId, RankedCard card) {
    if (_titleId != card.title.id || _profileId != profileId) {
      _titleId = null;
      _sync();
      _profileId = profileId;
      _titleId = card.title.id;
      _shownAt = _now();
      _slot = slotOf(card);
      _details = false;
      _held = false;
      _counted = Duration.zero;
    }
    _hidden = false;
    _sync();
  }

  /// The card is briefly off screen (the deck is being dealt again). Dwell
  /// stops until the same title is shown again.
  void hide() {
    _hidden = true;
    _sync();
  }

  void detailsOpened(String titleId) {
    if (titleId == _titleId) _details = true;
  }

  void posterHeld(String titleId) {
    if (titleId == _titleId) _held = true;
  }

  /// The app went to the background: dwell stops counting.
  void pause() {
    _paused = true;
    _sync();
  }

  /// The app is back: dwell counts again.
  void resume() {
    _paused = false;
    _sync();
  }

  /// Ends the current card and returns what was measured, or null when no
  /// card was being measured.
  CardSignal? finish({Decision? decision, String? decisionEventId}) {
    final titleId = _titleId;
    final profileId = _profileId;
    final shownAt = _shownAt;
    if (titleId == null || profileId == null || shownAt == null) return null;
    _titleId = null;
    _sync();
    final dwell = _counted;
    _profileId = null;
    _shownAt = null;
    _counted = Duration.zero;
    _hidden = false;
    return CardSignal(
      profileId: profileId,
      titleId: titleId,
      shownAt: shownAt,
      dwellMs: dwell.isNegative
          ? 0
          : dwell > maxDwell
          ? maxDwell.inMilliseconds
          : dwell.inMilliseconds,
      openedDetails: _details,
      heldPoster: _held,
      slot: _slot,
      decision: decision?.code,
      decisionEventId: decisionEventId,
    );
  }
}
