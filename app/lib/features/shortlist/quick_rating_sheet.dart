import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/library.dart';
import '../../domain/models/title.dart';

/// The ratings offered right after finishing something: the six that say
/// the most about taste, best first.
const quickRatings = [
  Rating.favourite,
  Rating.enjoyed,
  Rating.okay,
  Rating.once,
  Rating.disliked,
  Rating.dropped,
];

/// Asks how a just-finished title was and saves the answer as a rating.
/// Skipping changes nothing. Returns the rating chosen, if any.
Future<Rating?> showQuickRatingSheet(
  BuildContext context,
  WidgetRef ref,
  Title title,
) async {
  final chosen = await showCueSheet<Rating>(
    context,
    kicker: title.kind.isReading ? 'You read it' : 'You watched it',
    title: 'How was ${title.displayTitle}?',
    body: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your answer teaches Cue what to suggest next. It stays on this device.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: CueColors.textMuted,
          ),
        ),
        const SizedBox(height: CueSpace.md),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final r in quickRatings)
              CueChoiceChip(
                label: r.label,
                selected: false,
                onTap: () => Navigator.of(ctx).pop(r),
              ),
          ],
        ),
      ],
    ),
    footer: (ctx) => Align(
      alignment: Alignment.centerLeft,
      child: CueSecondaryButton(
        label: 'Skip for now',
        onPressed: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
  if (chosen == null) return null;
  final id = await ref.read(profileIdProvider.future);
  final repo = ref.read(libraryRepositoryProvider);
  final existing = await repo.entry(id, title.id);
  await repo.saveEntry(
    id,
    title.id,
    state: existing?.state ?? LibraryState.seen,
    rating: chosen,
    rewatchMood: existing?.rewatchMood,
    actualWatchedAt: existing?.actualWatchedAt,
  );
  await repo.recomputeWeights(id);
  ref.read(libraryVersionProvider.notifier).bump();
  return chosen;
}
