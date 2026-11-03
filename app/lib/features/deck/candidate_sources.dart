import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/ai_recommendation_client.dart';
import '../../data/ai_recommendation_repository.dart';
import '../../domain/ai_taste.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/title.dart';
import '../../domain/ranker.dart';

/// A pluggable source of extra deck candidates. A source puts real catalog
/// titles into the shared cache (the refill path) and may attach provenance
/// to them. Hard filters in the ranker still apply to everything it adds.
abstract class CandidateSource {
  /// Best-effort, fire-and-forget refresh; must never throw.
  void refill(
    String profileId,
    ProfileSignals signals,
    Set<MediaKind> kinds,
    AppSettings settings,
  );

  /// Provenance for titles this source suggested, by title id.
  Future<Map<String, AiPick>> provenance(
    String profileId,
    AppSettings settings,
  );
}

/// Opt-in AI picks from the person's own taste. Does nothing while off.
class AiTasteSource implements CandidateSource {
  AiTasteSource(this.repository);
  final AiRecommendationRepository repository;
  bool _busy = false;

  @override
  void refill(
    String profileId,
    ProfileSignals signals,
    Set<MediaKind> kinds,
    AppSettings settings,
  ) {
    if (!settings.aiPicks || _busy) return;
    _busy = true;
    unawaited(
      repository
          .refreshIfDue(profileId, signals, kinds)
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => _busy = false),
    );
  }

  @override
  Future<Map<String, AiPick>> provenance(
    String profileId,
    AppSettings settings,
  ) async {
    if (!settings.aiPicks) return const {};
    try {
      return await repository.picks(profileId);
    } on Object {
      return const {};
    }
  }
}

final aiRecommendationClientProvider = Provider<AiRecommendationClient>(
  (ref) => HttpAiRecommendationClient(cueApiBase),
);

final aiRecommendationRepositoryProvider = Provider<AiRecommendationRepository>(
  (ref) => AiRecommendationRepository(
    client: ref.watch(aiRecommendationClientProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    profiles: ref.watch(profileRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final candidateSourcesProvider = Provider<List<CandidateSource>>(
  (ref) => [AiTasteSource(ref.watch(aiRecommendationRepositoryProvider))],
);

/// Deals from [pool] and mixes in candidates that [picks] marks as suggested,
/// at most ~30% of the slots, each dealt through the same [deal] (so hard
/// filters and scoring are unchanged). With no picks it is just `deal`.
List<RankedCard> dealWithPicks(
  List<RankedCard> Function(List<Title> pool, int size) deal,
  List<Title> pool,
  Map<String, AiPick> picks, {
  required int size,
}) {
  if (picks.isEmpty) return deal(pool, size);
  final ai = [
    for (final t in pool)
      if (picks.containsKey(t.id)) t,
  ];
  if (ai.isEmpty) return deal(pool, size);
  final rest = [
    for (final t in pool)
      if (!picks.containsKey(t.id)) t,
  ];
  final aiCards = deal(ai, (size * 0.3).floor());
  return mixAiCards(deal(rest, size), aiCards, picks, size: size);
}

/// True when the person has enough positive titles to make AI picks useful
/// and has not been asked yet.
final aiPicksPromptProvider = FutureProvider<bool>((ref) async {
  final s = ref.watch(currentSettingsProvider);
  if (s.aiPicks || s.aiPicksPromptSeen) return false;
  ref.watch(libraryVersionProvider);
  final id = await ref.watch(profileIdProvider.future);
  final signals = await ref.read(libraryRepositoryProvider).signals(id);
  final ids = {...signals.library.keys, ...signals.shortlisted};
  final titles = {
    for (final t in await ref.read(catalogRepositoryProvider).titlesByIds(ids))
      t.id: t,
  };
  return AiRecommendationRepository.hasEnoughTaste(signals, titles);
});

/// One-time, friendly, dismissible. Never sends anything by itself.
class AiPicksPrompt extends ConsumerWidget {
  const AiPicksPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(aiPicksPromptProvider).value != true) {
      return const SizedBox.shrink();
    }
    void answer(bool on) => ref
        .read(settingsProvider.notifier)
        .change((x) => x.copyWith(aiPicks: on, aiPicksPromptSeen: true));
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CueRadius.chip),
        border: Border.all(color: CueColors.textMuted.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Want picks that understand your taste?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cue can ask an AI service (Groq or Google Gemini) for ideas based on the names of titles you liked and disliked. Only those names are sent, never your ratings, notes or dates. Every idea is checked against the real catalog. Off unless you say yes; change it any time in Settings.',
            style: TextStyle(fontSize: 13, color: CueColors.textMuted),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => answer(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => answer(true),
                child: const Text('Turn on'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
