import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'candidate_sources.dart';
import 'card_signal_tracker.dart';
import '../../data/card_signal_repository.dart';
import '../../data/catalog_gateway.dart';
import '../../data/catalog_repository.dart'
    show CatalogPageState, CatalogRepository, RequestBudget;
import '../../domain/ai_taste.dart' show AiPick;
import '../../domain/decisions.dart';
import '../../domain/models/settings.dart' show AppSettings;
import '../../domain/models/deck_filters.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/quick_mood.dart';
import '../../domain/models/title.dart';
import '../../domain/mood/mood_engine.dart';
import '../../domain/mood/mode_model.dart' show Mode;
import '../../domain/mood/mood_features.dart';
import '../../domain/mood/sessions.dart' show sessionGap;
import '../../domain/learning/learned_taste.dart';
import '../../domain/learning/swipe_model.dart';
import '../../data/learned_taste_repository.dart';
import '../../domain/ranker.dart';
import '../../domain/mood_rules.dart';
import '../../domain/reasons.dart';
import '../../domain/recommendation_context.dart';
import 'deck_fallback.dart';

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
    this.directionSuggestion = false,
    this.catalogPending = false,
    this.lengthFallback = false,
    this.relaxed = const {},
    this.refreshing = false,
    this.offline = false,
  });

  final List<RankedCard> cards;
  final bool loading;

  /// Set only when no eligible title exists anywhere (for example offline
  /// with an empty cache): a friendly retry message, never a dead end.
  final String? emptyMessage;

  /// Small non-blocking note, e.g. offline.
  final String? notice;
  final bool canUndo;
  final DecisionResult? lastDecision;
  final int sessionDecisions;

  /// A decision that could not be stored; the card stays.
  final String? error;
  final bool directionSuggestion;
  final bool catalogPending;

  /// No exact match is dealt: the deck is the nearest-length fallback.
  final bool lengthFallback;

  /// Cards outside the exact request, by title id, with their honest label.
  final Map<String, DeckRelaxation> relaxed;

  /// Cards are shown from the cache while the catalog is still searched.
  final bool refreshing;

  /// The last catalog refill failed because the device is offline.
  final bool offline;

  RankedCard? get top => cards.isEmpty ? null : cards.first;

  /// Why the top card is here when it is not an exact match.
  DeckRelaxation? get topRelaxation =>
      top == null ? null : relaxed[top!.title.id];

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
    bool? directionSuggestion,
    bool? catalogPending,
    bool? lengthFallback,
    Map<String, DeckRelaxation>? relaxed,
    bool? refreshing,
    bool? offline,
  }) => DeckState(
    cards: cards ?? this.cards,
    loading: loading ?? this.loading,
    emptyMessage: clearEmpty ? null : (emptyMessage ?? this.emptyMessage),
    notice: clearNotice ? null : (notice ?? this.notice),
    canUndo: canUndo ?? this.canUndo,
    lastDecision: lastDecision ?? this.lastDecision,
    sessionDecisions: sessionDecisions ?? this.sessionDecisions,
    error: clearError ? null : (error ?? this.error),
    directionSuggestion: directionSuggestion ?? this.directionSuggestion,
    catalogPending: catalogPending ?? this.catalogPending,
    lengthFallback: lengthFallback ?? this.lengthFallback,
    relaxed: relaxed ?? this.relaxed,
    refreshing: refreshing ?? this.refreshing,
    offline: offline ?? this.offline,
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

  /// Titles saved this session whose "more like this" lists steer the
  /// upcoming cards; see [_seedFromSave].
  final SessionSeeds _saved = SessionSeeds();
  DateTime? _lastSaveFetch;
  int _saveFetches = 0;
  int _saveEpoch = 0;

  /// A save asks the catalog about the saved title at most this often, and
  /// at most [maxSaveFetches] times per session.
  static const saveFetchEvery = Duration(seconds: 20);
  static const maxSaveFetches = 6;

  void _clearSessionSeeds() {
    _saved.clear();
    _lastSaveFetch = null;
    _saveFetches = 0;
    _saveEpoch++;
  }

  late final _temporary = RecommendationSession(clock: ref.read(clockProvider));
  bool _wantRetrieval = true;
  bool _skipCurrent = false;
  int _retrievalRound = 0;
  int poolSize = 0;
  String? _dealtProfile;
  String? _visibleId;
  List<InterestCluster> clusters = const [];
  double get exploration => _temporary.exploration;
  int get surpriseRemaining => _temporary.surpriseRemaining;
  bool get repeatedNotNow => _temporary.repeatedNotNow;
  void _activate(String id) {
    if (_temporary.activate(id)) {
      _session.bias.clear();
      _clearSessionSeeds();
      _visibleId = null;
      _wantRetrieval = true;
    }
  }

  MoodEngine? _engine;
  String _typed = '';
  bool _usedSmartText = false;
  String? _aiNotice;
  bool _dealing = false;
  bool _again = false;

  /// Titles being decided right now: a second tap on the same card is ignored.
  final Set<String> _inFlight = {};

  /// Prefetch while the person still has cards, not when the deck is empty.
  static const refillBelow = 8;
  static const maxRefillRounds = 4;

  /// The catalog is asked for more only when fewer than this many unseen,
  /// eligible titles are cached for the current filters. Above it, swiping
  /// never costs a provider request.
  static const eligibleWatermark = 30;

  /// A missing format (nothing eligible cached for it) is looked for again
  /// no more often than this, so an empty format cannot ask on every swipe.
  static const missingKindEvery = Duration(minutes: 2);

  /// Longest wait a provider's Retry-After can add to the retry backoff.
  static const retryAfterMax = Duration(minutes: 10);

  /// Background searches for exact matches while relaxed cards are shown.
  static const maxContinuations = 3;

  /// Automatic retries after an offline refill: 5 s doubling to a minute.
  static const retryBase = Duration(seconds: 5);
  static const retryMax = Duration(minutes: 1);

  /// Provider requests one refill cycle may make, and the separate share
  /// background continuations of one filter set split between them.
  static const refillRequestBudget = 12;
  static const continuationRequestBudget = 12;

  int _continuations = 0;
  bool _continueNext = false;
  bool _continuing = false;
  RequestBudget _continuationBudget = RequestBudget(
    limit: continuationRequestBudget,
  );
  DeckFilters? _continuedFor;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _seeding = false;
  DateTime? _missingKindAt;
  bool _pruned = false;

  // How each card on the main deck was looked at. Kept on this device only,
  // and never allowed to block or break a swipe.
  /// What this profile's own swipes have taught, rebuilt from the stored
  /// history whenever it may be stale (another profile, an undo).
  LearnedTaste? _taste;
  String? _tasteProfile;

  Future<LearnedTaste?> _learnedTaste(
    String profileId,
    List<Title> pool,
    ProfileSignals signals,
  ) async {
    if (_taste != null && _tasteProfile == profileId) return _taste;
    try {
      final built = await ref
          .read(learnedTasteRepositoryProvider)
          .build(profileId, pool: pool, seeded: signals.becauseOf.keys.toSet());
      _taste = built;
      _tasteProfile = profileId;
      return built;
    } on Object {
      // Ranking falls back to the hand-tuned score alone.
      return null;
    }
  }

  late final _signals = CardSignalTracker(clock: ref.read(clockProvider));
  CardSignalRepository? _signalStore;
  bool _signalsPruned = false;

  /// The details of the top card were opened.
  void signalDetailsOpened(String titleId) => _signals.detailsOpened(titleId);

  /// The top card was held to see its whole poster.
  void signalPosterHeld(String titleId) => _signals.posterHeld(titleId);

  /// Follows the top card: a new title on the main deck starts measuring,
  /// and the one it replaced is stored as left undecided.
  void _trackTop(DeckState next) {
    try {
      final profileId = _dealtProfile;
      if (profileId == null || ref.read(deckFiltersProvider).isRevisit) {
        _storeSignal(_signals.finish());
        return;
      }
      final top = next.top;
      // An empty deck between two deals is not the card leaving.
      if (top == null) return _signals.hide();
      if (top.title.id != _signals.titleId || profileId != _signals.profileId) {
        _storeSignal(_signals.finish());
      }
      _signals.show(profileId, top);
    } on Object {
      // Signals are best effort.
    }
  }

  void _storeSignal(CardSignal? signal) {
    final store = _signalStore;
    if (signal == null || store == null) return;
    final prune = !_signalsPruned;
    _signalsPruned = true;
    unawaited(() async {
      try {
        await store.record(signal);
        if (prune) await store.prune(signal.profileId);
      } on Object {
        // Signals are best effort.
      }
    }());
  }

  @override
  DeckState build() {
    try {
      _signalStore = ref.read(cardSignalRepositoryProvider);
    } on Object {
      _signalStore = null;
    }
    listenSelf((_, next) => _trackTop(next));
    final profile = ref.watch(profileIdProvider);
    final settingsLoading = ref.watch(
      settingsProvider.select((s) => s.isLoading),
    );
    ref.watch(deckFiltersProvider);
    ref.watch(libraryVersionProvider);
    // Settings that change eligibility re-deal; motion or haptics do not.
    ref.watch(
      currentSettingsProvider.select(
        (s) => (
          s.showAdult,
          s.includeRewatches,
          s.smartMoodText,
          Object.hashAllUnordered(s.defaultKinds),
        ),
      ),
    );
    final life = AppLifecycleListener(
      onResume: _retryNowIfOffline,
      onHide: _signals.pause,
      onShow: _signals.resume,
    );
    ref.onDispose(() {
      life.dispose();
      _retryTimer?.cancel();
      _retryTimer = null;
    });
    if (!profile.isLoading && !settingsLoading) Future.microtask(_deal);
    return const DeckState();
  }

  /// Back in the app after being offline: look again straight away.
  void _retryNowIfOffline() {
    if (!ref.mounted || !state.offline) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _wantRetrieval = true;
    unawaited(_deal(keepTop: true, quiet: true));
  }

  /// Retries an offline refill automatically with a capped backoff, so the
  /// deck recovers as soon as the connection does.
  void _scheduleRetry({Duration? retryAfter}) {
    if (_retryTimer != null) return;
    final seconds = retryBase.inSeconds * (1 << _retryAttempt.clamp(0, 4));
    var delay = Duration(seconds: seconds) > retryMax
        ? retryMax
        : Duration(seconds: seconds);
    // A provider that said how long to wait is believed, within reason.
    if (retryAfter != null && retryAfter > delay) {
      delay = retryAfter > retryAfterMax ? retryAfterMax : retryAfter;
    }
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!ref.mounted) return;
      _wantRetrieval = true;
      unawaited(_deal(keepTop: true, quiet: true));
    });
  }

  Future<String> get _profile => ref.read(profileIdProvider.future);

  /// The person corrected or renamed the mood: re-rank, keeping the top card.
  void moodChanged() => unawaited(_deal(keepTop: true));

  /// More/Less does not call the persistent decision or mood engines.
  Future<void> temporaryFeedback(bool more) async {
    final card = state.top;
    if (card == null) return;
    final id = await _profile;
    if (id != _dealtProfile) throw StateError('library_changed');
    _activate(id);
    _temporary.feedback(card.title, more: more);
    _wantRetrieval = true;
    await _deal(keepTop: true);
  }

  Future<void> setExploration(double value) async {
    _activate(await _profile);
    _temporary.explore(value);
    _wantRetrieval = true;
    await _deal(keepTop: true);
  }

  Future<void> moreOfTrait(
    String profileId,
    Title title,
    String feature,
  ) async {
    if (await _profile != profileId) throw StateError('library_changed');
    _activate(profileId);
    _temporary.trait(title, feature);
    _wantRetrieval = true;
    await _deal(keepTop: true);
  }

  Future<void> immediateInterest(
    String profileId,
    Title title,
    String eventId,
  ) async {
    if (await _profile != profileId) throw StateError('library_changed');
    _activate(profileId);
    _temporary.immediateInterest(title, eventId);
    _wantRetrieval = true;
    await _deal(keepTop: true);
  }

  Future<void> undoImmediateInterest(String profileId, String eventId) async {
    if (!ref.mounted || await _profile != profileId || !ref.mounted) return;
    _activate(profileId);
    _temporary.undoInterest(eventId);
    _wantRetrieval = true;
    await _deal(keepTop: true);
  }

  Future<void> surprise() async {
    _activate(await _profile);
    _temporary.surprise();
    _wantRetrieval = true;
    _skipCurrent = true;
    await _deal();
  }

  Future<void> differentDirection() async {
    _activate(await _profile);
    _temporary.differentDirection();
    _session.bias.clear();
    _clearSessionSeeds();
    _wantRetrieval = true;
    _skipCurrent = true;
    await _deal();
  }

  void dismissDirectionSuggestion() =>
      state = state.copyWith(directionSuggestion: false);

  Future<void> resetSession() async {
    _temporary.reset();
    _session.bias.clear();
    _clearSessionSeeds();
    _wantRetrieval = true;
    await _deal();
  }

  Future<void> recordVisible(Title title) async {
    final id = await _profile;
    if (id != _dealtProfile) return;
    _activate(id);
    if (_visibleId == title.id) return;
    _visibleId = title.id;
    _temporary.shown.add(title.id);
    if (_temporary.shown.length > 200) {
      _temporary.shown.remove(_temporary.shown.first);
    }
    final f = ref.read(deckFiltersProvider);
    final signals = await ref.read(libraryRepositoryProvider).signals(id);
    if (!ref.mounted) return;
    // A labelled fallback card is disclosed, so it is not a filter leak.
    final valid =
        state.relaxed.containsKey(title.id) ||
        ref
            .read(rankerProvider)
            .eligible(
              title,
              signals,
              f,
              showAdult: ref.read(currentSettingsProvider).showAdult,
              enabledKinds: _enabledKinds,
            );
    try {
      await ref
          .read(recommendationRepositoryProvider)
          .present(
            id,
            {title.id},
            kinds: {title.kind.name},
            leaks: valid ? 0 : 1,
          );
      if (!ref.mounted) return;
      ref.read(recommendationMeasuresVersionProvider.notifier).bump();
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        error: 'Local recommendation measures could not be saved.',
      );
    }
  }

  Set<MediaKind> get _enabledKinds {
    final s = ref.read(currentSettingsProvider);
    return s.defaultKinds.isEmpty
        ? {...MediaKind.discoverable}
        : s.defaultKinds;
  }

  /// Rebuilds the upcoming deck. The current top card is kept when it is
  /// still eligible, so filters never yank a card mid-look. [quiet] keeps a
  /// friendly retry message on screen during an automatic retry.
  Future<void> _deal({bool keepTop = false, bool quiet = false}) async {
    if (!ref.mounted) return;
    if (_dealing) {
      _again = true;
      return;
    }
    _dealing = true;
    if (state.cards.isEmpty && !(quiet && state.emptyMessage != null)) {
      state = state.copyWith(loading: true, clearEmpty: true);
    }
    try {
      do {
        _again = false;
        final keep = keepTop || _continueNext;
        _continuing = _continueNext;
        _continueNext = false;
        await _dealOnce(keepTop: keep);
      } while (_again);
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        refreshing: false,
        catalogPending: true,
        error: 'Could not prepare recommendations. Try again.',
        emptyMessage: state.cards.isEmpty
            ? 'Cue could not read the titles saved on this device. Try again in a moment.'
            : null,
      );
    } finally {
      _dealing = false;
    }
  }

  /// The mood learner, with a session open. A new session starts after a
  /// 45-minute gap or when the typed "Tell me" text changes.
  Future<MoodEngine?> _mood(
    DeckFilters f,
    List<Title> pool,
    String profileId,
  ) async {
    final MoodEngine e;
    try {
      e = await ref.read(moodEngineProvider.future);
    } on Object {
      return null;
    }
    if (!ref.mounted ||
        e.profileId != profileId ||
        ref.read(deckFiltersProvider) != f) {
      return null;
    }
    final now = DateTime.now();
    final text = f.tellMe ?? '';
    final smart = ref.read(currentSettingsProvider).smartMoodText;
    final last = e.lastActivity;
    final stale = last != null && now.difference(last) > sessionGap;
    if (!e.inSession || stale || text != _typed || smart != _usedSmartText) {
      await e.endSession();
      if (!ref.mounted) return null;
      final hints = await _hints(e, text, pool);
      if (!ref.mounted ||
          await _profile != profileId ||
          !ref.mounted ||
          ref.read(deckFiltersProvider) != f ||
          ref.read(currentSettingsProvider).smartMoodText != smart) {
        return null;
      }
      e.startSession(now: now, text: text, hints: hints);
      _typed = text;
      _usedSmartText = smart;
    }
    return _engine = e;
  }

  /// Hints for typed text: plain genre words always, plus AI suggestions
  /// when Smarter mood text is on. Any AI failure just means fewer hints.
  Future<(List<String>, List<String>)?> _hints(
    MoodEngine e,
    String text,
    List<Title> pool,
  ) async {
    final lower = text.toLowerCase();
    _aiNotice = null;
    if (lower.trim().isEmpty) return null;
    final parsed = parseMood(text);
    final local = parsed.genres;
    var ai = (<String>[], <String>[]);
    if (ref.read(currentSettingsProvider).smartMoodText) {
      try {
        ai = await ref
            .read(catalogGatewayProvider)
            .moodHints(
              text,
              e.allowedFeatures({for (final t in pool) ...moodFeatures(t)}),
            );
        _aiNotice = ai.$1.isEmpty && ai.$2.isEmpty
            ? 'Smarter mood text returned no usable hints. Local filters still apply.'
            : 'Smarter mood text supplied preference hints, not recommendation titles.';
      } on Object {
        _aiNotice = 'Smarter mood text unavailable. Using local filters and preferences; no AI success claimed.';
      }
    }
    final features = {
      ...local,
      ...ai.$1,
    }.where((g) => !parsed.excludedGenres.contains(g.toLowerCase())).toList();
    if (features.isEmpty && ai.$2.isEmpty) return null;
    return (features, {...ai.$2, ...parsed.excludedGenres}.toList());
  }

  Future<void> _dealOnce({required bool keepTop}) async {
    final libraryEpoch = ref.read(libraryVersionProvider);
    final decisionEpoch = ref.read(decisionVersionProvider);
    final profileId = await _profile;
    if (!ref.mounted) return;
    _activate(profileId);
    await ref.read(settingsProvider.future);
    if (!ref.mounted) return;
    final filters = ref.read(deckFiltersProvider);
    final settings = ref.read(currentSettingsProvider);
    final catalog = ref.read(catalogRepositoryProvider);
    final library = ref.read(libraryRepositoryProvider);
    final ranker = ref.read(rankerProvider);
    final kinds = filters.kinds.isEmpty ? _enabledKinds : filters.kinds;
    if (_continuedFor != filters) {
      _continuations = 0;
      _continuedFor = filters;
      _continuationBudget = RequestBudget(limit: continuationRequestBudget);
    }

    var signals = await library.signals(profileId);
    if (!ref.mounted) return;
    for (final source in ref.read(candidateSourcesProvider)) {
      source.refill(
        profileId,
        signals,
        _enabledKinds,
        settings,
        onAdded: _rerankUpcoming,
      );
    }
    if (!_pruned) {
      _pruned = true;
      unawaited(
        catalog
            .pruneRecommendations(signals.tasteSeeds.take(24))
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    var pool = await _pool(filters, kinds, signals, settings);
    if (!ref.mounted) return;
    final history = signals.library.values.toList()
      ..sort(
        (a, b) => (b.rating?.weight ?? 0).compareTo(a.rating?.weight ?? 0),
      );
    // All of the history (bounded): unrated reading history sorts last and
    // would otherwise never reach the reading clusters.
    final related = await catalog.titlesByIds({
      ...history.take(1500).map((e) => e.titleId),
      ...signals.shortlisted.take(64),
    });
    if (!ref.mounted) return;
    // Interest clusters come from the medium being dealt: what someone reads
    // is not what they watch. A mixed deck keeps the two strongest of each.
    final known = {
      for (final t in [...pool, ...related]) t.id: t,
    };
    final media = {for (final k in kinds) k.isReading};
    clusters = media.length == 1
        ? interestClusters(signals, known, reading: media.single)
        : [
            ...interestClusters(signals, known, reading: false, maxGroups: 2),
            ...interestClusters(signals, known, reading: true, maxGroups: 2),
          ];
    String? notice;
    var catalogPending = false;
    var refilled = false;
    var offline = false;
    var failed = false;
    var advanced = false;
    var transient = false;
    Duration? retryAfter;

    int unseenCount() => pool
        .where(
          (t) =>
              !_temporary.shown.contains(t.id) &&
              ranker.eligible(
                t,
                signals,
                filters,
                showAdult: settings.showAdult,
                enabledKinds: _enabledKinds,
                includeRewatchesDefault: settings.includeRewatches,
              ),
        )
        .length;

    final missingKinds = {
      for (final kind in kinds)
        if (!pool.any(
          (t) =>
              t.kind == kind &&
              ranker.eligible(
                t,
                signals,
                filters,
                showAdult: settings.showAdult,
                enabledKinds: _enabledKinds,
              ),
        ))
          kind,
    };
    // Demand driven: ask the catalog only when the cache is running thin for
    // these filters, never on a swipe count.
    final thin = unseenCount() < eligibleWatermark;
    final missingDue =
        filters.activeCount == 0 &&
        missingKinds.isNotEmpty &&
        (_missingKindAt == null ||
            ref.read(clockProvider)().difference(_missingKindAt!) >=
                missingKindEvery);
    final needsRefill = !filters.isRevisit && (thin || missingDue);
    if (needsRefill && !thin) {
      _missingKindAt = ref.read(clockProvider)();
    }
    // Taste changed but the cache is deep: only the cheap seed lookup runs,
    // in the background, and re-ranks the deck if it brings anything.
    if (!needsRefill && _wantRetrieval && !filters.isRevisit) {
      _seedInBackground(catalog, signals);
      _wantRetrieval = false;
    }

    // Instant open: deal from the cache now and look further meanwhile.
    if (needsRefill && state.cards.isEmpty) {
      final engine = _engine;
      final early = await _compose(
        profileId: profileId,
        filters: filters,
        signals: signals,
        pool: pool,
        target:
            filters.mood == QuickMood.forYou && engine?.profileId == profileId
            ? engine?.target
            : null,
        keepTop: false,
      );
      if (!ref.mounted) return;
      // Only exact matches open the deck early. Near matches from outside
      // the filters (anime under "Manhwa only") wait until the catalog has
      // been asked; until then the loading card shows.
      final exactEarly = [
        for (final c in early.cards)
          if (!early.relaxed.containsKey(c.title.id)) c,
      ];
      if (exactEarly.isNotEmpty &&
          state.cards.isEmpty &&
          await _profile == profileId &&
          ref.mounted &&
          ref.read(deckFiltersProvider) == filters) {
        _dealtProfile = profileId;
        state = state.copyWith(
          cards: exactEarly,
          relaxed: const {},
          lengthFallback: false,
          loading: false,
          refreshing: true,
          clearEmpty: true,
        );
        keepTop = true;
      }
      if (!ref.mounted) return;
    }

    if (needsRefill) {
      final budget = _continuing
          ? _continuationBudget
          : RequestBudget(limit: refillRequestBudget);
      final refillKinds = (thin ? kinds : missingKinds).difference(
        filters.excludedKinds,
      );
      final routes = thin
          ? retrievalPlan(
              kinds.difference(filters.excludedKinds),
              [
                ...clusters,
                if (_temporary.bias.bias.values.any((v) => v > 0))
                  InterestCluster(
                    _temporary.bias.bias.entries
                        .where((e) => e.value > 0)
                        .take(8)
                        .map((e) => e.key)
                        .toSet(),
                    0.2,
                  ),
              ],
              signals.kindRatings,
              _retrievalRound,
              explicitMood: switch (filters.mood) {
                QuickMood.hype => 'hype',
                QuickMood.comfort => 'comfort',
                QuickMood.gripping => 'gripping',
                QuickMood.feels => 'feels',
                _ => null,
              },
            )
          : null;
      // Taste-seeded retrieval: "more like this" for the strongest likes.
      // A bonus route; its failure never blocks the broad refill below.
      if (thin && signals.tasteSeeds.isNotEmpty && !_seeding) {
        _seeding = true;
        try {
          await catalog.fetchSeeded(signals.tasteSeeds, budget: budget);
        } on CatalogUnavailable {
          // Retried on a later retrieval.
        } finally {
          _seeding = false;
        }
        if (!ref.mounted) return;
      }
      for (var round = 0; round < maxRefillRounds; round++) {
        final result = await _refill(
          refillKinds,
          routes: routes,
          budget: budget,
        );
        refilled = true;
        notice = result.notice;
        catalogPending = result.pending;
        offline = result.offline;
        failed = result.failed;
        advanced = result.advanced;
        transient = result.transient;
        retryAfter = result.retryAfter ?? retryAfter;
        if (!ref.mounted) return;
        signals = await library.signals(profileId);
        if (!ref.mounted) return;
        pool = await _pool(filters, kinds, signals, settings);
        if (!ref.mounted) return;
        if (ref.read(deckFiltersProvider) != filters ||
            await _profile != profileId) {
          _again = true;
          return;
        }
        if (unseenCount() >= eligibleWatermark ||
            !result.pending ||
            result.failed ||
            !result.advanced) {
          break;
        }
      }
      _retrievalRound++;
      _wantRetrieval = false;
    }

    if (!ref.mounted) return;
    final activeProfile = await _profile;
    if (!ref.mounted) return;
    if (activeProfile != profileId) {
      _again = true;
      return;
    }
    if (ref.read(deckFiltersProvider) != filters) {
      _again = true;
      return;
    }
    final mood = await _mood(filters, pool, profileId);
    if (!ref.mounted) return;
    final target = filters.mood == QuickMood.forYou ? mood?.target : null;
    ref.read(moodReadProvider.notifier).set(target ?? MoodTarget.none);

    final composed = await _compose(
      profileId: profileId,
      filters: filters,
      signals: signals,
      pool: pool,
      target: target,
      secondMode: (target?.confidence ?? 0) > 0.4 ? mood?.secondMode : null,
      keepTop: keepTop,
    );
    if (!ref.mounted) return;
    final next = composed.cards;
    final notices = [?notice, ?_aiNotice];
    final canUndo = await ref.read(decisionServiceProvider).canUndo(profileId);
    if (!ref.mounted) return;
    final liveId = await _profile;
    if (!ref.mounted) return;
    final liveSettings = ref.read(currentSettingsProvider);
    if (liveId != profileId ||
        libraryEpoch != ref.read(libraryVersionProvider) ||
        decisionEpoch != ref.read(decisionVersionProvider) ||
        ref.read(deckFiltersProvider) != filters ||
        liveSettings.showAdult != settings.showAdult ||
        liveSettings.smartMoodText != settings.smartMoodText ||
        Object.hashAllUnordered(liveSettings.defaultKinds) !=
            Object.hashAllUnordered(settings.defaultKinds)) {
      _again = true;
      return;
    }
    _dealtProfile = profileId;
    _skipCurrent = false;

    // Relaxed or no cards while more pages remain: keep searching for exact
    // matches in the background, a bounded number of times.
    final searching =
        !filters.isRevisit &&
        catalogPending &&
        advanced &&
        !failed &&
        (next.isEmpty || composed.relaxed.isNotEmpty) &&
        _continuations < maxContinuations;
    if (composed.relaxed.isEmpty && next.isNotEmpty) {
      _continuations = 0;
      _continuationBudget = RequestBudget(limit: continuationRequestBudget);
    }
    // Nothing eligible is left; was anything cached at all? (The pool holds
    // only dealable titles, so an empty one does not mean an empty cache.)
    final cachedAny = next.isNotEmpty || pool.isNotEmpty
        ? true
        : await catalog.hasCached(kinds);
    if (!ref.mounted) return;
    final isOffline = refilled ? offline : state.offline;
    // A refused catalog (429, upstream error) is not a recovery: keep the
    // backoff growing instead of asking again every five seconds.
    if (refilled && !offline && !failed) {
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
    }
    // A thin deck after a refused catalog (429, 5xx) retries on its own.
    final thinAfterRefusal = refilled && transient && next.length < refillBelow;
    if (isOffline ||
        thinAfterRefusal ||
        (next.isEmpty && !searching && !filters.isRevisit)) {
      _scheduleRetry(retryAfter: transient ? retryAfter : null);
    }
    state = state.copyWith(
      cards: next,
      relaxed: composed.relaxed,
      loading: false,
      refreshing: searching,
      offline: isOffline,
      catalogPending: catalogPending,
      lengthFallback: composed.lengthFallback,
      emptyMessage: next.isEmpty && !searching
          ? _emptyMessage(
              filters,
              pool,
              signals,
              offline: isOffline,
              cachedAny: cachedAny,
            )
          : null,
      clearEmpty: next.isNotEmpty || searching,
      notice: notices.isEmpty ? null : notices.join(' '),
      clearNotice: notices.isEmpty,
      canUndo: canUndo,
    );
    if (searching) {
      _continuations++;
      _continueNext = true;
      _again = true;
    }
  }

  /// The only non-card state: no eligible title exists anywhere Cue can
  /// reach right now. Friendly, and retried automatically.
  String _emptyMessage(
    DeckFilters filters,
    List<Title> pool,
    ProfileSignals signals, {
    required bool offline,
    required bool cachedAny,
  }) {
    if (filters.isRevisit) {
      return ref
          .read(rankerProvider)
          .explainEmpty(
            pool,
            signals,
            filters,
            showAdult: ref.read(currentSettingsProvider).showAdult,
            enabledKinds: _enabledKinds,
          )
          .message;
    }
    if (offline) {
      return !cachedAny
          ? "You're offline, and nothing is saved on this device yet. Cue will try again on its own as soon as you're back online."
          : "You're offline, and you've seen everything saved on this device. Cue will look for more as soon as you're back online.";
    }
    return !cachedAny
        ? "Cue couldn't reach the catalog just now. It will keep trying, or you can try again."
        : "You've been through everything Cue has checked so far. It will keep looking, or you can try again.";
  }

  /// Ranks the deck: exact matches first, then the fallback ladder, so a card
  /// is dealt whenever any eligible real title is cached.
  Future<LadderResult> _compose({
    required String profileId,
    required DeckFilters filters,
    required ProfileSignals signals,
    required List<Title> pool,
    required bool keepTop,
    MoodTarget? target,
    Mode? secondMode,
  }) async {
    final catalog = ref.read(catalogRepositoryProvider);
    final ranker = ref.read(rankerProvider);
    final settings = ref.read(currentSettingsProvider);
    final byId = {for (final t in pool) t.id: t};
    // Rated titles may not be in this pool; reasons need them.
    final ratedIds = signals.library.values
        .where(
          (e) => e.rating != null || signals.weakHistoryIds.contains(e.titleId),
        )
        .map((e) => e.titleId)
        .followedBy([...signals.shortlisted, ...signals.tasteSeeds])
        .where((id) => !byId.containsKey(id));
    for (final t in await catalog.titlesByIds(ratedIds)) {
      byId[t.id] = t;
    }
    if (!ref.mounted) return const LadderResult([], {});
    final union = {..._enabledKinds, ...filters.kinds};
    bool eligible(Title t, ProfileSignals s, DeckFilters f) => ranker.eligible(
      t,
      s,
      f,
      showAdult: settings.showAdult,
      enabledKinds: union,
      includeRewatchesDefault: settings.includeRewatches,
    );
    final exposures =
        (await ref.read(recommendationRepositoryProvider).exposures(profileId))
            .keys
            .toSet();
    if (!ref.mounted) return const LadderResult([], {});
    final swipeTaste = await _learnedTaste(profileId, pool, signals);
    if (!ref.mounted) return const LadderResult([], {});
    List<RankedCard> dealer(
      List<Title> candidates,
      DeckFilters f, {
      required int size,
      bool shortestFirst = false,
      ProfileSignals? using,
      Set<String> skip = const {},
      Set<String> skipFranchises = const {},
    }) => ranker.deal(
      candidates,
      using ?? signals,
      f,
      showAdult: settings.showAdult,
      enabledKinds: union,
      titlesById: byId,
      includeRewatchesDefault: settings.includeRewatches,
      session: _session,
      target: target,
      size: size,
      shortestFirst: shortestFirst,
      temporary: _temporary.bias,
      preferShorter: _temporary.preferShorter,
      clusters: clusters,
      recentExposures: exposures,
      explorePreference: _temporary.effectiveExploration,
      swipeTaste: swipeTaste,
      sessionSeeds: _saved,
      skip: skip,
      skipFranchises: skipFranchises,
    );

    final previous = keepTop ? state.top : null;
    final keep = previous != null && eligible(previous.title, signals, filters)
        ? previous
        : null;
    poolSize = pool.length;
    final exactPool = pool.where((t) => eligible(t, signals, filters)).toList();
    final unseenEligible = exactPool.any(
      (t) => !_temporary.shown.contains(t.id),
    );
    final exactSkip = {
      if (keep != null) keep.title.id,
      if (_skipCurrent && exactPool.length > 1 && _visibleId != null)
        _visibleId!,
      if (unseenEligible) ..._temporary.shown,
    };
    // One card per franchise for the whole session (not just per deal), so
    // six One Piece films or every Gintama season do not take turns. Only
    // while other franchises remain, so the deck never runs dry over it.
    final shownFranchises = {
      if (keep != null) keep.title.franchiseKey,
      for (final id in _temporary.shown)
        if (id != keep?.title.id) ?byId[id]?.franchiseKey,
    };
    final franchiseSkip =
        exactPool.any(
          (t) =>
              !exactSkip.contains(t.id) &&
              !shownFranchises.contains(t.franchiseKey),
        )
        ? shownFranchises
        : const <String>{};
    // AI picks mix into exact matches only (still hard-filtered by the
    // ranker); the relaxed ladder steps below never use them.
    final aiPicks = await _sourcePicks(profileId, settings);
    if (!ref.mounted) return const LadderResult([], {});
    final dealt = dealWithPicks(
      (dealPool, dealSize) => dealer(
        dealPool,
        filters,
        size: dealSize,
        skip: exactSkip,
        skipFranchises: franchiseSkip,
      ),
      pool,
      aiPicks,
      size: keep == null ? Ranker.deckSize : Ranker.deckSize - 1,
    );
    final exact = [?keep, ...diversify(dealt, secondMode)];
    if (filters.isRevisit || exact.length >= Ranker.deckSize) {
      return LadderResult(exact, const {});
    }

    // The card on screen stays while no exact match replaces it.
    RankedCard? keptRelaxed;
    DeckRelaxation? keptRelaxation;
    if (previous != null && keep == null && exact.isEmpty) {
      final before = state.relaxed[previous.title.id];
      final now = relaxationFor(previous.title, signals, filters, eligible);
      if (now != null) {
        keptRelaxation = now;
        keptRelaxed = before?.label == now.label
            ? previous
            : RankedCard(
                previous.title,
                previous.score,
                '${now.label}. ${reasonFor(previous.title, signals, filters, titlesById: byId)}',
              );
      }
    }
    final wide = filters.kinds.isEmpty
        ? pool
        : await _candidates(catalog, filters, union, signals, settings);
    if (!ref.mounted) return const LadderResult([], {});
    final ladder = runLadder(
      exact: exact,
      pool: wide,
      signals: signals,
      filters: filters,
      eligible: eligible,
      deal: dealer,
      size: keptRelaxed == null ? Ranker.deckSize : Ranker.deckSize - 1,
      taken: {?keptRelaxed?.title.id},
      shown: _temporary.shown,
    );
    if (keptRelaxed == null) return ladder;
    return LadderResult(
      [keptRelaxed, ...ladder.cards],
      {keptRelaxed.title.id: keptRelaxation!, ...ladder.relaxed},
    );
  }

  Future<Map<String, AiPick>> _sourcePicks(
    String profileId,
    AppSettings settings,
  ) async => {
    for (final source in ref.read(candidateSourcesProvider))
      ...await source.provenance(profileId, settings),
  };

  Future<List<Title>> _pool(
    DeckFilters filters,
    Set<MediaKind> kinds,
    ProfileSignals signals, [
    AppSettings? settings,
  ]) async {
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
    return _candidates(catalog, filters, kinds, signals, settings);
  }

  /// Dealable cached titles with the hard exclusions applied in the query.
  /// Filters narrow the set themselves, so a filtered deal loads all of it.
  Future<List<Title>> _candidates(
    CatalogRepository catalog,
    DeckFilters filters,
    Set<MediaKind> kinds,
    ProfileSignals signals,
    AppSettings? settings,
  ) {
    final AppSettings live = settings ?? ref.read(currentSettingsProvider);
    return catalog.candidatePool(
      kinds,
      excludeIds: {
        ...signals.excluded,
        ...signals.known,
        ...signals.deferred,
        ...signals.shortlisted,
        ...signals.library.keys,
      },
      excludeFranchises: signals.excludedFranchises,
      showAdult: live.showAdult,
      limit: filters.activeCount == 0 ? CatalogRepository.candidateLimit : null,
    );
  }

  /// Asks about taste seeds without blocking the deck; a result re-ranks it.
  void _seedInBackground(CatalogRepository catalog, ProfileSignals signals) {
    if (_seeding || signals.tasteSeeds.isEmpty) return;
    _seeding = true;
    unawaited(() async {
      try {
        final stored = await catalog.fetchSeeded(
          signals.tasteSeeds,
          budget: RequestBudget(limit: 1),
        );
        if (stored > 0) _rerankUpcoming();
      } on Object {
        // A refused or offline catalog is retried by a later lookup.
      } finally {
        _seeding = false;
      }
    }());
  }

  /// A card was saved: its "more like this" list becomes a temporary seed,
  /// so the next cards follow from it. Stored edges are reused; otherwise
  /// one background lookup (only the title's AniList id is sent), at most
  /// every [saveFetchEvery] and [maxSaveFetches] times a session, at seed
  /// priority. Never blocks the swipe; any failure just means no steer.
  void _seedFromSave(Title title) {
    if (_saved.has(title.id)) return;
    final epoch = _saveEpoch;
    final catalog = ref.read(catalogRepositoryProvider);
    final now = ref.read(clockProvider)();
    unawaited(() async {
      try {
        var edges = await catalog.seedEdges(title.id);
        if (edges.isEmpty) {
          final last = _lastSaveFetch;
          if (epoch != _saveEpoch ||
              _saveFetches >= maxSaveFetches ||
              (last != null && now.difference(last) < saveFetchEvery)) {
            return;
          }
          _lastSaveFetch = now;
          _saveFetches++;
          await catalog.fetchSeeded(
            [title.id],
            budget: RequestBudget(limit: 1),
            anilistOnly: true,
          );
          edges = await catalog.seedEdges(title.id);
        }
        if (!ref.mounted || edges.isEmpty || epoch != _saveEpoch) return;
        _saved.add(title.id, edges);
        _rerankUpcoming();
      } on Object {
        // Offline or refused: the deck simply is not steered by this save.
      }
    }());
  }

  /// New candidates arrived (AI picks, seeded recommendations): rank the
  /// cards not yet shown again. The top card stays where it is.
  void _rerankUpcoming() {
    if (!ref.mounted) return;
    unawaited(_deal(keepTop: true));
  }

  /// One bounded pass; only a provider's final page proves exhaustion.
  Future<
    ({
      String? notice,
      bool pending,
      bool failed,
      bool advanced,
      bool offline,
      bool transient,
      Duration? retryAfter,
    })
  >
  _refill(
    Set<MediaKind> kinds, {
    List<RetrievalRequest>? routes,
    RequestBudget? budget,
  }) async {
    final catalog = ref.read(catalogRepositoryProvider);
    var offline = false;
    var gotAny = false;
    var pending = false;
    var advanced = false;
    var limited = false;
    var transient = false;
    Duration? retryAfter;
    final failedKinds = <MediaKind>{
      ...catalog.unavailableKinds.intersection(kinds),
    };
    await Future.wait([
      for (final request
          in routes ?? [for (final k in kinds) RetrievalRequest(k, 'broad')])
        () async {
          final before = await catalog.pageState(
            request.kind,
            mood: request.mood,
          );
          final broad = request.mood == null;
          if (before == CatalogPageState.exhausted) return;
          if (before == CatalogPageState.limited) {
            if (broad) pending = limited = true;
            return;
          }
          if (before == CatalogPageState.unavailable) {
            if (broad) pending = true;
            return;
          }
          // Budget spent: more pages exist, but this cycle asks no more.
          if (budget != null && budget.spent) {
            if (broad) pending = true;
            return;
          }
          try {
            final n = await catalog.fetchNext(
              request.kind,
              mood: request.mood,
              budget: budget,
            );
            advanced = true;
            if (n > 0) gotAny = true;
            if (broad &&
                await catalog.pageState(request.kind, mood: request.mood) !=
                    CatalogPageState.exhausted) {
              if (broad) pending = true;
            }
          } on CatalogUnavailable catch (e) {
            pending = true;
            if (e.code == 'offline') offline = true;
            // Not-configured is permanent; anything else is worth retrying.
            if (e.code != 'offline' && e.code != 'not_configured') {
              transient = true;
              final wait = e.retryAfter;
              if (wait != null && (retryAfter == null || wait > retryAfter!)) {
                retryAfter = wait;
              }
            }
            failedKinds.add(request.kind);
          }
        }(),
    ]);
    return (
      notice: offline && !gotAny
          ? 'Offline. Showing saved stories; Cue retries automatically when you reconnect.'
          : failedKinds.isNotEmpty
          ? 'Some formats unavailable: ${failedKinds.map((k) => k.label).join(', ')}. Retry to check more stories; cached matches are still available.'
          : limited
          ? 'The catalog browsing limit was reached for now. Your filters have not been changed.'
          : null,
      pending: pending,
      failed: failedKinds.isNotEmpty,
      advanced: advanced,
      offline: offline && !gotAny,
      transient: transient,
      retryAfter: retryAfter,
    );
  }

  /// Records a decision on the top card. The card leaves the deck at once;
  /// if storing fails it comes back with a message.
  Future<DecisionResult?> decide(
    Decision d, {
    DeckContext context = DeckContext.deck,
    Duration? defer,
    NotNowReason? notNowReason,
    String? expectedTitleId,
  }) async {
    final card = state.top;
    final profileId = _dealtProfile;
    if (card == null ||
        profileId == null ||
        (expectedTitleId != null && card.title.id != expectedTitleId) ||
        !_inFlight.add(card.title.id)) {
      return null;
    }
    final filters = ref.read(deckFiltersProvider);
    final rest = state.cards.skip(1).toList();
    final signal = _signals.titleId == card.title.id ? _signals.finish() : null;
    state = state.copyWith(cards: rest, clearError: true);
    try {
      if (await _profile != profileId) {
        if (ref.mounted) {
          state = state.copyWith(error: 'Library changed. No choice saved.');
          unawaited(_deal());
        }
        return null;
      }
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
      _storeSignal(signal?.withDecision(d.code, result.eventId));
      if (!ref.mounted) return result;
      if (await _profile != profileId) {
        ref.read(decisionVersionProvider.notifier).bump();
        return result;
      }
      _activate(profileId);
      final suggestion = _temporary.choice(
        notNow: d == Decision.notNow,
        eventId: result.eventId,
        reason: d == Decision.notNow ? notNowReason : null,
      );
      _session.record(card.title.features, switch (d) {
        Decision.willTry => 0.6,
        Decision.notInterested => -0.6,
        Decision.notNow => notNowReason == NotNowReason.savingLater ? 0 : -0.2,
        Decision.watched => 0.1,
      });
      _saved.record();
      if (d == Decision.willTry && !filters.isRevisit) {
        _seedFromSave(card.title);
      }
      if (!filters.isRevisit && _tasteProfile == profileId) {
        final lesson =
            decisionLabel(
              d,
              savingForLater: notNowReason == NotNowReason.savingLater,
            ) ??
            (signal == null ? null : LearnedTasteRepository.implicit(signal));
        if (lesson != null) {
          _taste?.learn(card.title, lesson.label, lesson.weight);
        }
      }
      // The session may have closed while the app was hidden.
      final engine = _engine;
      if (engine != null && !engine.inSession) {
        engine.startSession(now: DateTime.now(), text: _typed);
      }
      if (d != Decision.notNow) engine?.onSwipe(card.title, d);
      final count = state.sessionDecisions + 1;
      try {
        await ref
            .read(recommendationRepositoryProvider)
            .decision(
              profileId,
              picked: d == Decision.willTry,
              eventId: result.eventId,
            );
      } on Object {
        state = state.copyWith(
          error: 'Your choice was saved, but local quality measures could not be updated.',
        );
      }
      state = state.copyWith(
        canUndo: true,
        lastDecision: result,
        sessionDecisions: count,
        directionSuggestion: suggestion,
      );
      ref.read(decisionVersionProvider.notifier).bump();
      final total = await ref
          .read(libraryRepositoryProvider)
          .decisionCount(profileId);
      if (d == Decision.willTry ||
          d == Decision.notInterested ||
          total % 10 == 0) {
        try {
          await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
        } on Object {
          if (ref.mounted) {
            state = state.copyWith(
              error: 'Choice saved, but taste refresh failed. Retry recommendations.',
            );
          }
        }
      }
      // Re-rank every few swipes so a change of mood shows up quickly.
      // Below [refillBelow] the deck prefetches in the background (the
      // catalog is checked when cached matches run thin), so the person
      // never swipes into an empty deck.
      // Re-ranking is local and cheap. Whether the catalog is asked for
      // more is decided by the deal itself from how much unseen, eligible
      // supply is cached, never by how many swipes happened.
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

  Future<DecisionResult?> tryNow({String? expectedTitleId}) async {
    final card = state.top;
    final profileId = _dealtProfile;
    if (card == null ||
        profileId == null ||
        (expectedTitleId != null && expectedTitleId != card.title.id) ||
        !_inFlight.add(card.title.id)) {
      return null;
    }
    final signal = _signals.titleId == card.title.id ? _signals.finish() : null;
    state = state.copyWith(
      cards: state.cards.skip(1).toList(),
      clearError: true,
    );
    try {
      if (await _profile != profileId) {
        if (ref.mounted) {
          state = state.copyWith(error: 'Library changed. No choice saved.');
          unawaited(_deal());
        }
        return null;
      }
      final result = await ref
          .read(decisionServiceProvider)
          .tryNow(profileId, card.title);
      _storeSignal(signal?.withDecision('try_now', result.eventId));
      if (!ref.mounted) return result;
      if (await _profile != profileId) {
        ref.read(decisionVersionProvider.notifier).bump();
        return result;
      }
      _activate(profileId);
      if (!result.repeated) {
        _saved.record();
        if (!ref.read(deckFiltersProvider).isRevisit) {
          _seedFromSave(card.title);
        }
        _temporary.immediateInterest(card.title, result.eventId);
        _temporary.choice(notNow: false, eventId: result.eventId);
        try {
          await ref
              .read(recommendationRepositoryProvider)
              .decision(profileId, picked: true, eventId: result.eventId);
        } on Object {
          if (ref.mounted) {
            state = state.copyWith(
              error: 'Try now saved, but local choice measures could not be updated.',
            );
          }
        }
      }
      if (!ref.mounted) return result;
      state = state.copyWith(
        canUndo: true,
        lastDecision: result,
        sessionDecisions: state.sessionDecisions + (result.repeated ? 0 : 1),
      );
      ref.read(decisionVersionProvider.notifier).bump();
      try {
        await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
      } on Object {
        if (ref.mounted) {
          state = state.copyWith(
            error: 'Try now saved, but taste refresh failed.',
          );
        }
      }
      _wantRetrieval = true;
      unawaited(_deal(keepTop: true));
      return result;
    } on DecisionFailed {
      if (ref.mounted) {
        state = state.copyWith(
          cards: [
            card,
            ...state.cards.where((c) => c.title.id != card.title.id),
          ],
          error: 'Could not save Try now. Try again.',
        );
      }
      return null;
    } finally {
      _inFlight.remove(card.title.id);
    }
  }

  /// Undoes the last decision and puts its card back on top. Returns the
  /// decision it reversed, so the card can return from that side.
  Future<UndoResult?> undo() async {
    final profileId = await _profile;
    if (!ref.mounted) return null;
    final filters = ref.read(deckFiltersProvider);
    final undone = await ref.read(decisionServiceProvider).undoLast(profileId);
    final undoneEvent = undone?.eventId;
    final signalStore = _signalStore;
    if (undoneEvent != null && signalStore != null) {
      // An undone swipe must not teach.
      unawaited(
        signalStore
            .clearDecision(undoneEvent)
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    if (!ref.mounted) return undone;
    ref.read(decisionVersionProvider.notifier).bump();
    bool current() =>
        ref.mounted && ref.read(profileIdProvider).value == profileId;
    if (!current()) return undone;
    if (undone == null) {
      state = state.copyWith(canUndo: false);
      return null;
    }
    final titleId = undone.titleId;
    _activate(profileId);
    if (undone.eventId != null) {
      _temporary.undoInterest(undone.eventId!);
      try {
        await ref
            .read(recommendationRepositoryProvider)
            .undoDecision(profileId, undone.eventId!);
        if (!current()) return undone;
        ref.read(recommendationMeasuresVersionProvider.notifier).bump();
      } on Object {
        if (ref.mounted) {
          state = state.copyWith(
            error: 'Undo saved, but local measures could not be restored.',
          );
        }
      }
    }
    // The undone swipe must not keep teaching: rebuild from history.
    _taste = null;
    _engine?.undo(titleId);
    if (!current()) return undone;
    await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
    if (!current()) return undone;
    final title = await ref.read(catalogRepositoryProvider).titleById(titleId);
    if (!current()) return undone;
    final canUndo = await ref.read(decisionServiceProvider).canUndo(profileId);
    if (!current()) return undone;
    if (title == null) {
      state = state.copyWith(canUndo: canUndo);
      return undone;
    }
    final signals = await ref
        .read(libraryRepositoryProvider)
        .signals(profileId);
    if (!current()) return undone;
    final settings = ref.read(currentSettingsProvider);
    final union = {..._enabledKinds, ...filters.kinds};
    bool eligible(Title t, ProfileSignals s, DeckFilters f) => ref
        .read(rankerProvider)
        .eligible(
          t,
          s,
          f,
          showAdult: settings.showAdult,
          enabledKinds: union,
          includeRewatchesDefault: settings.includeRewatches,
        );
    final exact = eligible(title, signals, filters);
    // A card that came from the fallback ladder comes back with its label.
    final relaxation = exact
        ? null
        : relaxationFor(title, signals, filters, eligible);
    if (filters != ref.read(deckFiltersProvider) ||
        (!exact && relaxation == null)) {
      await _deal();
      return undone;
    }
    final reason = reasonFor(
      title,
      signals,
      relaxation == null ? filters : openFilters(filters),
      titlesById: {title.id: title},
    );
    final card = relaxation == null
        ? RankedCard(title, 1, reason)
        : labelled(RankedCard(title, 1, reason), relaxation);
    state = state.copyWith(
      cards: [card, ...state.cards.where((c) => c.title.id != titleId)],
      relaxed: {
        for (final e in state.relaxed.entries)
          if (e.key != titleId) e.key: e.value,
        titleId: ?relaxation,
      },
      canUndo: canUndo,
      clearEmpty: true,
    );
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
