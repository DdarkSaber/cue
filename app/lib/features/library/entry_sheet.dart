import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/library.dart';
import '../../domain/models/title.dart';

/// Edit a library entry: status, rating, rewatch mood, actual date.
/// A manual edit always wins over imported evidence.
Future<bool?> showEntrySheet(BuildContext context, Title title) async {
  final container = ProviderScope.containerOf(context);
  final profileId = await container.read(profileIdProvider.future);
  final existing = await container
      .read(libraryRepositoryProvider)
      .entry(profileId, title.id);
  if (!context.mounted) return null;
  final draft = ValueNotifier(
    existing ?? LibraryEntry(titleId: title.id, state: LibraryState.seen),
  );
  final saved = await showCueSheet<bool>(
    context,
    kicker: title.kind.label,
    title: title.displayTitle,
    body: (_) => _EntryBody(draft: draft, reading: title.kind.isReading),
    footer: (ctx) => Row(
      spacing: CueSpace.md,
      children: [
        if (existing != null)
          CueSecondaryButton(
            label: 'Remove',
            destructive: true,
            onPressed: () async {
              await container
                  .read(libraryRepositoryProvider)
                  .removeEntry(profileId, title.id);
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
          ),
        Expanded(
          child: CuePrimaryButton(
            label: 'Save',
            expand: true,
            onPressed: () async {
              final d = draft.value;
              await container
                  .read(libraryRepositoryProvider)
                  .saveEntry(
                    profileId,
                    title.id,
                    state: d.state,
                    rating: d.rating,
                    rewatchMood: d.rewatchMood,
                    actualWatchedAt: d.actualWatchedAt,
                  );
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
          ),
        ),
      ],
    ),
  );
  draft.dispose();
  if (saved == true) {
    await container.read(libraryRepositoryProvider).recomputeWeights(profileId);
    container.read(libraryVersionProvider.notifier).bump();
  }
  return saved;
}

class _EntryBody extends StatefulWidget {
  const _EntryBody({required this.draft, required this.reading});
  final ValueNotifier<LibraryEntry> draft;
  final bool reading;

  @override
  State<_EntryBody> createState() => _EntryBodyState();
}

class _EntryBodyState extends State<_EntryBody> {
  LibraryEntry get _e => widget.draft.value;

  void _set({
    LibraryState? state,
    Rating? rating,
    bool clearRating = false,
    RewatchMood? mood,
    bool clearMood = false,
    DateTime? date,
    bool clearDate = false,
  }) {
    setState(() {
      widget.draft.value = LibraryEntry(
        titleId: _e.titleId,
        state: state ?? _e.state,
        rating: clearRating ? null : (rating ?? _e.rating),
        rewatchMood: clearMood ? null : (mood ?? _e.rewatchMood),
        actualWatchedAt: clearDate ? null : (date ?? _e.actualWatchedAt),
        progressUnit: _e.progressUnit,
        progressValue: _e.progressValue,
        latestKnown: _e.latestKnown,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final states = widget.reading
        ? [
            LibraryState.reading,
            LibraryState.caughtUp,
            LibraryState.completed,
            LibraryState.seen,
            LibraryState.onHold,
            LibraryState.dropped,
            LibraryState.planned,
          ]
        : [
            LibraryState.watching,
            LibraryState.completed,
            LibraryState.seen,
            LibraryState.partial,
            LibraryState.onHold,
            LibraryState.dropped,
            LibraryState.planned,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CueSectionLabel('Status'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in states)
              CueChoiceChip(
                label: s.label,
                selected: _e.state == s,
                onTap: () => _set(state: s),
              ),
          ],
        ),
        const CueSectionLabel('Your rating'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            CueChoiceChip(
              label: 'No rating',
              selected: _e.rating == null,
              onTap: () => _set(clearRating: true),
            ),
            for (final r in Rating.values)
              CueChoiceChip(
                label: r.label,
                selected: _e.rating == r,
                onTap: () => _set(rating: r),
              ),
          ],
        ),
        const CueSectionLabel('Rewatch mood'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            CueChoiceChip(
              label: 'None',
              selected: _e.rewatchMood == null,
              onTap: () => _set(clearMood: true),
            ),
            for (final m in RewatchMood.values)
              CueChoiceChip(
                label: m.label,
                selected: _e.rewatchMood == m,
                onTap: () => _set(mood: m),
              ),
          ],
        ),
        const CueSectionLabel('When you finished it'),
        Row(
          spacing: CueSpace.sm,
          children: [
            Expanded(
              child: Text(
                _e.actualWatchedAt == null
                    ? 'Unknown'
                    : DateFormat.yMMMd().format(_e.actualWatchedAt!),
                style: const TextStyle(fontSize: 15),
              ),
            ),
            CueSecondaryButton(
              label: 'Pick a date',
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1960),
                  lastDate: now,
                  initialDate: _e.actualWatchedAt ?? now,
                );
                if (d != null) _set(date: DateTime.utc(d.year, d.month, d.day));
              },
            ),
            if (_e.actualWatchedAt != null)
              CueSecondaryButton(
                label: 'Clear',
                onPressed: () => _set(clearDate: true),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Only real dates count for "Watched 3+ years ago".',
          style: TextStyle(fontSize: 12, color: CueColors.textMuted),
        ),
      ],
    );
  }
}
