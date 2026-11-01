import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/catalog_gateway.dart';
import '../../domain/decisions.dart';
import '../../domain/models/deck_filters.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/quick_mood.dart';
import '../../domain/models/title.dart';
import '../../domain/mood/mood_engine.dart';
import '../../domain/mood/mood_features.dart';
import '../../domain/mood/sessions.dart' show sessionGap;
import '../../domain/ranker.dart';
import '../../domain/reasons.dart';

class DeckState {
  const DeckState({
    this.cards = const [],
    this.loading = true,
    this.emptyMessage,
    this.notice,
    this.canUndo = false,
    this.lastDecision,
    this.sessionDecisions = 0,
    this.error,
  });

  final List<RankedCard> cards;
  final bool loading;

  /// Set when there are no cards: says which filter or state caused it.
  final String? emptyMessage;

  /// Small non-blocking note, e.g. offline.
  final String? notice;
  final bool canUndo;
  final DecisionResult? lastDecision;
  final int sessionDecisions;

  /// A decision that could not be stored; the card stays.
  final String? error;

  RankedCard? get top => cards.isEmpty ? null : cards.first;

  DeckState copyWith({
    List<RankedCard>? cards,
    bool? loading,
    String? emptyMessage,
    bool clearEmpty = false,
    String? notice,
    bool clearNotice = false,
    bool? canUndo,
    DecisionResult? lastDecision,
    int? sessionDecisions,
    String? error,
    bool clearError = false,
  }) => DeckState(
    cards: cards ?? this.cards,
    loading: loading ?? this.loading,
    emptyMessage: clearEmpty ? null : (emptyMessage ?? this.emptyMessage),
    notice: clearNotice ? null : (notice ?? this.notice),
    canUndo: canUndo ?? this.canUndo,
    lastDecision: lastDecision ?? this.lastDecision,
    sessionDecisions: sessionDecisions ?? this.sessionDecisions,
    error: clearError ? null : (error ?? this.error),
  );
}

class DeckFiltersController extends Notifier<DeckFilters> {
  @override
  DeckFilters build() => const DeckFilters();

  void setMood(QuickMood mood) => state = state.copyWith(mood: mood);
  void apply(DeckFilters f) => state = f;
  void reset() => state = DeckFilters(mood: state.mood);
}

final deckFiltersProvider =
    NotifierProvider<DeckFiltersController, DeckFilters>(
      DeckFiltersController.new,
    );

/// The For you deck: deals from the local catalog, refills from the Worker,
/// writes decisions and undoes them.
class DeckController extends Notifier<DeckState> {
  final SessionMood _session = SessionMood();
  MoodEngine? _engine;
  String _typed = '';
  bool _dealing = false;
  bool _again = false;

  /// Titles being decided right now: a second tap on the same card is ignored.
  final Set<String> _inFlight = {};

  static const refillBelow = 4;

  @override
  DeckState build() {
    ref.watch(deckFiltersProvider);
    ref.watch(libraryVersionProvider);
    // Settings that change eligibility re-deal; motion or haptics do not.
    ref.watch(
      currentSettingsProvider.select(
        (s) => (
          s.showAdult,
          s.includeRewatches,
          Object.hashAllUnordered(s.defaultKinds),
        ),
      ),
    );
    Future.microtask(_deal);
    return const DeckState();
  }

  Future<String> get _profile => ref.read(profileIdProvider.future);

  /// The person corrected or renamed the mood: re-rank, keeping the top card.
  void moodChanged() => unawaited(_deal(keepTop: true));

  Set<MediaKind> get _enabledKinds {
    final s = ref.read(currentSettingsProvider);
    return s.defaultKinds.isEmpty
        ? {...MediaKind.discoverable}
        : s.defaultKinds;
  }

  /// Rebuilds the upcoming deck. The current top card is kept when it is
  /// still eligible, so filters never yank a card mid-look.
  Future<void> _deal({bool keepTop = false}) async {
    if (_dealing) {
      _again = true;
      return;
    }
    _dealing = true;
    try {
      do {
        _again = false;
        await _dealOnce(keepTop: keepTop);
      } while (_again);
    } finally {
      _dealing = false;
    }
  }

  /// The mood learner, with a session open. A new session starts after a
  /// 45-minute gap or when the typed "Tell me" text changes.
  Future<MoodEngine?> _mood(DeckFilters f, List<Title> pool) async {
    final MoodEngine e;
    try {
      e = await ref.read(moodEngineProvider.future);
    } on Object {
      return null;
    }
    final now = DateTime.now();
    final text = f.tellMe ?? '';
    final last = e.lastActivity;
    final stale = last != null && now.difference(last) > sessionGap;
    if (!e.inSession || stale || text != _typed) {
      await e.endSession();
      e.startSession(now: now, text: text, hints: await _hints(e, text, pool));
      _typed = text;
    }
    return _engine = e;
  }

  /// Genre words understood without AI ("fast" leans to action).
  static const _genreWords = [
    'comedy',
    'romance',
    'action',
    'horror',
    'mystery',
    'drama',
    'fantasy',
    'sci-fi',
    'slice of life',
    'sports',
    'thriller',
    'adventure',
    'isekai',
    'psychological',
    'supernatural',
    'shounen',
    'school',
  ];

  /// Hints for typed text: plain genre words always, plus AI suggestions
  /// when Smarter mood text is on. Any AI failure just means fewer hints.
  Future<(List<String>, List<String>)?> _hints(
    MoodEngine e,
    String text,
    List<Title> pool,
  ) async {
    final lower = text.toLowerCase();
    if (lower.trim().isEmpty) return null;
    final local = <String>{
      for (final g in _genreWords)
        if (lower.contains(g)) g,
      if (lower.contains('fast')) 'action',
    };
    var ai = (<String>[], <String>[]);
    if (ref.read(currentSettingsProvider).smartMoodText) {
      try {
        ai = await ref
            .read(catalogGatewayProvider)
            .moodHints(
              text,
              e.allowedFeatures({for (final t in pool) ...moodFeatures(t)}),
            );
      } on Object {
        // Local words still apply.
      }
    }
    final features = {...local, ...ai.$1}.toList();
    if (features.isEmpty && ai.$2.isEmpty) return null;
    return (features, ai.$2);
  }

  Future<void> _dealOnce({required bool keepTop}) async {
    final profileId = await _profile;
    await ref.read(settingsProvider.future);
    final filters = ref.read(deckFiltersProvider);
    final settings = ref.read(currentSettingsProvider);
    final catalog = ref.read(catalogRepositoryProvider);
    final library = ref.read(libraryRepositoryProvider);
    final ranker = ref.read(rankerProvider);
    final kinds = filters.kinds.isEmpty ? _enabledKinds : filters.kinds;

    var signals = await library.signals(profileId);
    var pool = await _pool(filters, kinds, signals);
    String? notice;

    int eligibleCount() => pool
        .where(
          (t) => ranker.eligible(
            t,
            signals,
            filters,
            showAdult: settings.showAdult,
            enabledKinds: _enabledKinds,
            includeRewatchesDefault: settings.includeRewatches,
          ),
        )
        .length;

    if (!filters.isRevisit && eligibleCount() < Ranker.deckSize * 2) {
      notice = await _refill(kinds, filters);
      signals = await library.signals(profileId);
      pool = await _pool(filters, kinds, signals);
    }

    final byId = {for (final t in pool) t.id: t};
    // Rated titles may not be in this pool; reasons need them.
    final ratedIds = signals.library.values
        .where((e) => e.rating != null)
        .map((e) => e.titleId)
        .where((id) => !byId.containsKey(id));
    for (final t in await catalog.titlesByIds(ratedIds)) {
      byId[t.id] = t;
    }

    final mood = await _mood(filters, pool);
    final target = filters.mood == QuickMood.forYou ? mood?.target : null;
    ref.read(moodReadProvider.notifier).set(target ?? MoodTarget.none);

    final keep = keepTop ? state.top : null;
    final dealt = ranker.deal(
      pool,
      signals,
      filters,
      showAdult: settings.showAdult,
      enabledKinds: _enabledKinds,
      titlesById: byId,
      includeRewatchesDefault: settings.includeRewatches,
      session: _session,
      target: target,
      skip: {if (keep != null) keep.title.id},
    );
    final cards = diversify(
      dealt,
      (target?.confidence ?? 0) > 0.4 ? mood?.secondMode : null,
    );
    final keepStill =
        keep != null &&
        ranker.eligible(
          keep.title,
          signals,
          filters,
          showAdult: settings.showAdult,
          enabledKinds: _enabledKinds,
          includeRewatchesDefault: settings.includeRewatches,
        );
    final next = [if (keepStill) keep, ...cards];
    state = state.copyWith(
      cards: next,
      loading: false,
      emptyMessage: next.isEmpty
          ? ranker
                .explainEmpty(
                  pool,
                  signals,
                  filters,
                  showAdult: settings.showAdult,
                  enabledKinds: _enabledKinds,
                )
                .message
          : null,
      clearEmpty: next.isNotEmpty,
      // "Showing saved stories" only when there are saved stories to show.
      notice: pool.isEmpty ? null : notice,
      clearNotice: notice == null || pool.isEmpty,
      canUndo: await ref.read(decisionServiceProvider).canUndo(profileId),
    );
  }

  Future<List<Title>> _pool(
    DeckFilters filters,
    Set<MediaKind> kinds,
    ProfileSignals signals,
  ) async {
    final catalog = ref.read(catalogRepositoryProvider);
    if (filters.isRevisit) {
      final cutoff = DateTime.now().subtract(const Duration(days: 3 * 365));
      final ids = signals.library.values
          .where(
            (e) =>
                (e.rating?.isRewatch ?? false) ||
                (e.actualWatchedAt?.isBefore(cutoff) ?? false),
          )
          .map((e) => e.titleId);
      return catalog.titlesByIds(ids);
    }
    return catalog.pool(kinds);
  }

  /// Pulls one more page for each kind that is running low. Returns a
  /// notice when the network is unavailable.
  Future<String?> _refill(Set<MediaKind> kinds, DeckFilters filters) async {
    final catalog = ref.read(catalogRepositoryProvider);
    final mood = switch (filters.mood) {
      QuickMood.hype => 'hype',
      QuickMood.comfort => 'comfort',
      QuickMood.gripping => 'gripping',
      QuickMood.feels => 'feels',
      _ => null,
    };
    var offline = false;
    var gotAny = false;
    await Future.wait([
      for (final k in kinds)
        if (!catalog.unavailableKinds.contains(k))
          () async {
            try {
              final n = await catalog.fetchNext(k, mood: mood);
              if (n > 0) gotAny = true;
            } on CatalogUnavailable catch (e) {
              if (e.code == 'offline') offline = true;
            }
          }(),
    ]);
    if (offline && !gotAny) return 'Offline. Showing saved stories.';
    return null;
  }

  /// Records a decision on the top card. The card leaves the deck at once;
  /// if storing fails it comes back with a message.
  Future<DecisionResult?> decide(
    Decision d, {
    DeckContext context = DeckContext.deck,
    Duration? defer,
  }) async {
    final card = state.top;
    if (card == null || !_inFlight.add(card.title.id)) return null;
    final filters = ref.read(deckFiltersProvider);
    final rest = state.cards.skip(1).toList();
    state = state.copyWith(cards: rest, clearError: true);
    try {
      final profileId = await _profile;
      final result = await ref
          .read(decisionServiceProvider)
          .decide(
            profileId,
            card.title,
            d,
            context: filters.isRevisit ? DeckContext.revisit : context,
            mood: filters.mood == QuickMood.forYou ? null : filters.mood.name,
            defer: defer,
          );
      _session.record(card.title.features, switch (d) {
        Decision.willTry => 0.6,
        Decision.notInterested => -0.6,
        Decision.notNow => -0.2,
        Decision.watched => 0.1,
      });
      // The session may have closed while the app was hidden.
      final engine = _engine;
      if (engine != null && !engine.inSession) {
        engine.startSession(now: DateTime.now(), text: _typed);
      }
      engine?.onSwipe(card.title, d);
      final count = state.sessionDecisions + 1;
      state = state.copyWith(
        canUndo: true,
        lastDecision: result,
        sessionDecisions: count,
      );
      ref.read(decisionVersionProvider.notifier).bump();
      final total = await ref
          .read(libraryRepositoryProvider)
          .decisionCount(profileId);
      if (total % 10 == 0) {
        await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
      }
      // Re-rank every few swipes so a change of mood shows up quickly.
      if (state.cards.length < refillBelow || count % 3 == 0) {
        unawaited(_deal(keepTop: true));
      }
      return result;
    } on DecisionFailed {
      state = state.copyWith(
        cards: [card, ...state.cards],
        error: 'Could not save that. Try again.',
      );
      return null;
    } finally {
      _inFlight.remove(card.title.id);
    }
  }

  /// Undoes the last decision and puts its card back on top. Returns the
  /// decision it reversed, so the card can return from that side.
  Future<UndoResult?> undo() async {
    final profileId = await _profile;
    final undone = await ref.read(decisionServiceProvider).undoLast(profileId);
    if (undone == null) {
      state = state.copyWith(canUndo: false);
      return null;
    }
    final titleId = undone.titleId;
    _engine?.undo(titleId);
    final title = await ref.read(catalogRepositoryProvider).titleById(titleId);
    final canUndo = await ref.read(decisionServiceProvider).canUndo(profileId);
    if (title == null) {
      state = state.copyWith(canUndo: canUndo);
      return undone;
    }
    final signals = await ref
        .read(libraryRepositoryProvider)
        .signals(profileId);
    final card = RankedCard(
      title,
      1,
      reasonFor(
        title,
        signals,
        ref.read(deckFiltersProvider),
        titlesById: {title.id: title},
      ),
    );
    state = state.copyWith(
      cards: [card, ...state.cards.where((c) => c.title.id != titleId)],
      canUndo: canUndo,
      clearEmpty: true,
    );
    ref.read(decisionVersionProvider.notifier).bump();
    return undone;
  }

  /// How many cached titles a draft of filters would allow ("Show N picks").
  Future<int> countFor(DeckFilters f) async {
    final profileId = await _profile;
    final settings = ref.read(currentSettingsProvider);
    final signals = await ref
        .read(libraryRepositoryProvider)
        .signals(profileId);
    final kinds = f.kinds.isEmpty ? _enabledKinds : f.kinds;
    final pool = await _pool(f, kinds, signals);
    final ranker = ref.read(rankerProvider);
    final franchises = <String>{};
    for (final t in pool) {
      if (ranker.eligible(
        t,
        signals,
        f,
        showAdult: settings.showAdult,
        enabledKinds: _enabledKinds,
        includeRewatchesDefault: settings.includeRewatches,
      )) {
        franchises.add(t.franchiseKey);
      }
    }
    return franchises.length;
  }

  /// Re-deals after filters change, keeping the current card if eligible.
  Future<void> redeal() => _deal(keepTop: true);

  void clearError() => state = state.copyWith(clearError: true);
}

final deckControllerProvider = NotifierProvider<DeckController, DeckState>(
  DeckController.new,
);
