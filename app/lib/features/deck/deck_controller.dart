import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/catalog_gateway.dart';
import '../../data/catalog_repository.dart' show CatalogPageState;
import '../../domain/decisions.dart';
import '../../domain/models/deck_filters.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/quick_mood.dart';
import '../../domain/models/title.dart';
import '../../domain/mood/mood_engine.dart';
import '../../domain/mood/mood_features.dart';
import '../../domain/mood/sessions.dart' show sessionGap;
import '../../domain/ranker.dart';
import '../../domain/mood_rules.dart';
import '../../domain/reasons.dart';
import '../../domain/recommendation_context.dart';

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
  final bool directionSuggestion;
  final bool catalogPending;
  final bool lengthFallback;

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
    bool? directionSuggestion,
    bool? catalogPending,
    bool? lengthFallback,
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

  static const refillBelow = 4;
  static const maxRefillRounds = 4;

  @override
  DeckState build() {
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
    if (!profile.isLoading && !settingsLoading) Future.microtask(_deal);
    return const DeckState();
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
    _wantRetrieval = true;
    _skipCurrent = true;
    await _deal();
  }

  void dismissDirectionSuggestion() =>
      state = state.copyWith(directionSuggestion: false);

  Future<void> resetSession() async {
    _temporary.reset();
    _session.bias.clear();
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
    final valid = ref
        .read(rankerProvider)
        .eligible(
          title,
          signals,
          state.lengthFallback ? f.copyWith(shortOnly: false) : f,
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
  /// still eligible, so filters never yank a card mid-look.
  Future<void> _deal({bool keepTop = false}) async {
    if (!ref.mounted) return;
    if (_dealing) {
      _again = true;
      return;
    }
    _dealing = true;
    if (state.cards.isEmpty) {
      state = state.copyWith(loading: true, clearEmpty: true);
    }
    try {
      do {
        _again = false;
        await _dealOnce(keepTop: keepTop);
      } while (_again);
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        catalogPending: true,
        error: 'Could not prepare recommendations. Try again.',
        emptyMessage: state.cards.isEmpty
            ? 'Your local library or candidate cache could not be read.'
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

    var signals = await library.signals(profileId);
    if (!ref.mounted) return;
    var pool = await _pool(filters, kinds, signals);
    if (!ref.mounted) return;
    final history = signals.library.values.toList()
      ..sort(
        (a, b) => (b.rating?.weight ?? 0).compareTo(a.rating?.weight ?? 0),
      );
    final related = await catalog.titlesByIds({
      ...history.take(64).map((e) => e.titleId),
      ...signals.shortlisted.take(64),
    });
    if (!ref.mounted) return;
    clusters = interestClusters(signals, {
      for (final t in [...pool, ...related]) t.id: t,
    });
    String? notice;
    var catalogPending = false;

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
    if (!filters.isRevisit &&
        (_wantRetrieval ||
            eligibleCount() < Ranker.deckSize * 2 ||
            (filters.activeCount == 0 && missingKinds.isNotEmpty))) {
      final refillKinds =
          (_wantRetrieval || eligibleCount() < Ranker.deckSize * 2
                  ? kinds
                  : missingKinds)
              .difference(filters.excludedKinds);
      final routes = _wantRetrieval
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
      for (var round = 0; round < maxRefillRounds; round++) {
        final result = await _refill(refillKinds, routes: routes);
        notice = result.notice;
        catalogPending = result.pending;
        if (!ref.mounted) return;
        signals = await library.signals(profileId);
        if (!ref.mounted) return;
        pool = await _pool(filters, kinds, signals);
        if (!ref.mounted) return;
        if (ref.read(deckFiltersProvider) != filters ||
            await _profile != profileId) {
          _again = true;
          return;
        }
        if (eligibleCount() >= Ranker.deckSize * 2 ||
            !result.pending ||
            result.failed ||
            !result.advanced) {
          break;
        }
      }
      _retrievalRound++;
      _wantRetrieval = false;
    }

    final byId = {for (final t in pool) t.id: t};
    // Rated titles may not be in this pool; reasons need them.
    final ratedIds = signals.library.values
        .where(
          (e) => e.rating != null || signals.weakHistoryIds.contains(e.titleId),
        )
        .map((e) => e.titleId)
        .where((id) => !byId.containsKey(id));
    for (final t in await catalog.titlesByIds(ratedIds)) {
      byId[t.id] = t;
    }
    if (!ref.mounted) return;

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

    var rankingFilters = filters;
    var rankingPool = pool;
    var lengthFallback = false;
    if (!catalogPending &&
        filters.shortOnly &&
        !filters.isRevisit &&
        kinds.length == 1 &&
        kinds.contains(MediaKind.anime) &&
        eligibleCount() == 0) {
      final nearbyFilters = filters.copyWith(shortOnly: false);
      final nearby =
          pool
              .where(
                (t) =>
                    t.episodes != null &&
                    t.episodes! > 13 &&
                    ranker.eligible(
                      t,
                      signals,
                      nearbyFilters,
                      showAdult: settings.showAdult,
                      enabledKinds: _enabledKinds,
                    ),
              )
              .toList()
            ..sort((a, b) => a.episodes!.compareTo(b.episodes!));
      if (nearby.isNotEmpty) {
        rankingFilters = nearbyFilters;
        rankingPool = nearby;
        lengthFallback = true;
      }
    }
    final previous = keepTop ? state.top : null;
    final keep =
        previous != null &&
            ranker.eligible(
              previous.title,
              signals,
              rankingFilters,
              showAdult: settings.showAdult,
              enabledKinds: _enabledKinds,
            )
        ? previous
        : null;
    final exposures =
        (await ref.read(recommendationRepositoryProvider).exposures(profileId))
            .keys
            .toSet();
    if (!ref.mounted) return;
    poolSize = pool.length;
    final unseenEligible = rankingPool
        .where(
          (t) =>
              !_temporary.shown.contains(t.id) &&
              ranker.eligible(
                t,
                signals,
                rankingFilters,
                showAdult: settings.showAdult,
                enabledKinds: _enabledKinds,
              ),
        )
        .isNotEmpty;
    final dealt = ranker.deal(
      rankingPool,
      signals,
      rankingFilters,
      showAdult: settings.showAdult,
      enabledKinds: _enabledKinds,
      titlesById: byId,
      includeRewatchesDefault: settings.includeRewatches,
      session: _session,
      target: target,
      size: keep == null ? Ranker.deckSize : Ranker.deckSize - 1,
      shortestFirst: lengthFallback,
      temporary: _temporary.bias,
      preferShorter: _temporary.preferShorter,
      clusters: clusters,
      recentExposures: exposures,
      explorePreference: _temporary.effectiveExploration,
      skip: {
        if (keep != null) keep.title.id,
        if (_skipCurrent && eligibleCount() > 1 && _visibleId != null)
          _visibleId!,
        if (unseenEligible) ..._temporary.shown,
      },
    );
    final cards = lengthFallback
        ? [
            for (final c in dealt.take(
              keep == null ? Ranker.deckSize : Ranker.deckSize - 1,
            ))
              RankedCard(
                c.title,
                c.score,
                'Longer than requested - ${c.title.episodes} episodes. ${c.reason}',
              ),
          ]
        : diversify(
            dealt,
            (target?.confidence ?? 0) > 0.4 ? mood?.secondMode : null,
          );
    final next = [?keep, ...cards];
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
    final empty = next.isEmpty
        ? ranker.explainEmpty(
            pool,
            signals,
            filters,
            showAdult: settings.showAdult,
            enabledKinds: _enabledKinds,
          )
        : null;
    state = state.copyWith(
      cards: next,
      loading: false,
      catalogPending: catalogPending,
      lengthFallback: lengthFallback,
      emptyMessage: next.isEmpty
          ? catalogPending && pool.isNotEmpty
                ? notice ?? 'More catalog pages remain. Try again to keep looking with these filters.'
                : empty?.message
          : null,
      clearEmpty: next.isNotEmpty,
      // "Showing saved stories" only when there are saved stories to show.
      notice: notices.isEmpty ? null : notices.join(' '),
      clearNotice: notices.isEmpty,
      canUndo: canUndo,
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

  /// One bounded pass; only a provider's final page proves exhaustion.
  Future<({String? notice, bool pending, bool failed, bool advanced})> _refill(
    Set<MediaKind> kinds, {
    List<RetrievalRequest>? routes,
  }) async {
    final catalog = ref.read(catalogRepositoryProvider);
    var offline = false;
    var gotAny = false;
    var pending = false;
    var advanced = false;
    var limited = false;
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
          try {
            final n = await catalog.fetchNext(request.kind, mood: request.mood);
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
            failedKinds.add(request.kind);
          }
        }(),
    ]);
    return (
      notice: offline && !gotAny
          ? 'Offline. Showing saved stories when available; retry when connected.'
          : failedKinds.isNotEmpty
          ? 'Some formats unavailable: ${failedKinds.map((k) => k.label).join(', ')}. Retry to check more stories; cached matches are still available.'
          : limited
          ? 'The catalog browsing limit was reached for now. Your filters have not been changed.'
          : null,
      pending: pending,
      failed: failedKinds.isNotEmpty,
      advanced: advanced,
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
      if (state.cards.length < refillBelow || count % 3 == 0) {
        _wantRetrieval = true;
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
      if (!ref.mounted) return result;
      if (await _profile != profileId) {
        ref.read(decisionVersionProvider.notifier).bump();
        return result;
      }
      _activate(profileId);
      if (!result.repeated) {
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
    final undoFilters = state.lengthFallback
        ? filters.copyWith(shortOnly: false)
        : filters;
    if (filters != ref.read(deckFiltersProvider) ||
        !ref
            .read(rankerProvider)
            .eligible(
              title,
              signals,
              undoFilters,
              showAdult: settings.showAdult,
              enabledKinds: _enabledKinds,
              includeRewatchesDefault: settings.includeRewatches,
            )) {
      await _deal();
      return undone;
    }
    final reason = reasonFor(
      title,
      signals,
      undoFilters,
      titlesById: {title.id: title},
    );
    final card = RankedCard(
      title,
      1,
      state.lengthFallback && title.episodes != null && title.episodes! > 13
          ? 'Longer than requested - ${title.episodes} episodes. $reason'
          : reason,
    );
    state = state.copyWith(
      cards: [card, ...state.cards.where((c) => c.title.id != titleId)],
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
