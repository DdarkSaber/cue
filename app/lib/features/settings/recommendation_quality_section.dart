import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/learned_taste_repository.dart';
import '../../data/outcome_stats_repository.dart';
import '../../domain/learning/replay.dart';
import '../../domain/learning/swipe_model.dart';
import 'recommendation_quality_card.dart';

typedef _Quality = ({
  OutcomeStats recent,
  OutcomeStats earlier,
  List<({DateTime day, int saved, int rejected})> daily,
  ReplayReport? learned,
  ReplayReport? guess,
});

/// How the last cards landed, and how well learning from swipes would have
/// ranked them. Computed on the device from the stored decisions.
final recommendationQualityProvider = FutureProvider.autoDispose<_Quality?>((
  ref,
) async {
  ref.watch(decisionVersionProvider);
  final profileId = await ref.watch(profileIdProvider.future);
  final stats = ref.watch(outcomeStatsRepositoryProvider);
  final recent = await stats.stats(profileId, last: 50);
  final earlier = await stats.stats(profileId, last: 50, skip: 50);
  final daily = await stats.daily(profileId);
  final lessons = await ref
      .watch(learnedTasteRepositoryProvider)
      .lessons(profileId);
  // Too few answers say nothing about ranking.
  final enough = lessons.length >= 40;
  return (
    recent: recent,
    earlier: earlier,
    daily: daily,
    learned: enough
        ? replay(
            lessons,
            SwipeModelScorer(idf: featureIdf(lessons.map((e) => e.title))),
          )
        : null,
    guess: enough ? replay(lessons, ConstantScorer()) : null,
  );
});

class RecommendationQualitySection extends ConsumerWidget {
  const RecommendationQualitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(recommendationQualityProvider).value;
    if (q == null) return const SizedBox.shrink();
    return RecommendationQualityCard(
      recent: q.recent,
      earlier: q.earlier,
      daily: q.daily,
      learned: q.learned,
      baseline: q.guess,
    );
  }
}
