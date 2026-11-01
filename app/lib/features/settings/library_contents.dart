part of 'settings_screen.dart';

/// One source of titles in the active library: an import source (all its
/// batches together) or the deck.
class _SourceCount {
  const _SourceCount(this.label, this.titles, {this.sourceType});
  final String label;
  final int titles;

  /// Null for local/deck records without an undoable import source.
  final String? sourceType;
}

final _contentsProvider = FutureProvider.autoDispose<List<_SourceCount>>((
  ref,
) async {
  ref.watch(libraryVersionProvider);
  ref.watch(decisionVersionProvider);
  final db = ref.read(databaseProvider);
  final id = await ref.watch(profileIdProvider.future);
  final batches =
      await (db.select(db.importBatches)..where(
            (b) =>
                b.profileId.equals(id) &
                b.state.equals('completed') &
                b.sourceType.isNotValue('sync'),
          ))
          .get();
  final byType = <String, Set<String>>{};
  final held = await ref.read(libraryRepositoryProvider).contents(id);
  final historyIds = {
    for (final r in held)
      if (r.entry != null) r.title.id,
  };
  for (final b in batches) {
    final obs =
        await (db.select(db.sourceObservations)..where(
              (o) =>
                  o.batchId.equals(b.id) &
                  o.titleId.isNotNull() &
                  o.included.equals(true),
            ))
            .get();
    byType
        .putIfAbsent(b.sourceType, () => {})
        .addAll(obs.map((o) => o.titleId!).where(historyIds.contains));
  }
  final decided = await (db.select(
    db.decisionEvents,
  )..where((e) => e.profileId.equals(id))).get();
  final reversed = {for (final e in decided) ?e.reversesEventId};
  final active = <String>{};
  final byId = {for (final row in held) row.title.id: row};
  for (final e in decided.where(
    (e) => e.reversesEventId == null && !reversed.contains(e.id),
  )) {
    final row = byId[e.titleId];
    if (row == null) continue;
    final applies = switch (e.action) {
      'will_try' => row.shortlisted,
      'not_interested' => row.excluded,
      'not_now' => row.deferred,
      'watched' || 'read' => row.entry?.state.isSeen ?? false,
      _ => false,
    };
    if (applies) active.add(e.titleId);
  }
  final local = historyIds
      .difference(byType.values.expand((ids) => ids).toSet())
      .difference(active);
  return [
    for (final e in byType.entries)
      _SourceCount(importSourceName(e.key), e.value.length, sourceType: e.key),
    if (active.isNotEmpty) _SourceCount('Deck swipes', active.length),
    if (local.isNotEmpty) _SourceCount('Added in Cue', local.length),
  ];
});

/// "What is in this library": titles per source, each import source with
/// an x that undoes all of its imports. Titles can also be removed from
/// the selected library's contents page.
class _LibraryContents extends ConsumerWidget {
  const _LibraryContents();

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    _SourceCount s,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Remove ${s.label}?',
      body:
          'Every import from ${s.label} is undone. Titles you edited since stay as they are.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    final id = await ref.read(profileIdProvider.future);
    final batches =
        await (db.select(db.importBatches)..where(
              (b) =>
                  b.profileId.equals(id) &
                  b.state.equals('completed') &
                  b.sourceType.equals(s.sourceType!),
            ))
            .get();
    final imports = ref.read(importServiceProvider);
    for (final b in batches) {
      await imports.undo(id, b.id);
    }
    await ref.read(libraryRepositoryProvider).recomputeWeights(id);
    ref.read(libraryVersionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(_contentsProvider);
    final list = contents.isLoading || contents.hasError
        ? const <_SourceCount>[]
        : contents.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CueSectionLabel('What is in this library'),
        if (contents.isLoading)
          const LinearProgressIndicator(color: CueColors.accent),
        if (contents.hasError)
          const Text(
            'Source counts could not be read. Try reopening this page.',
            style: _body,
          ),
        if (!contents.isLoading && !contents.hasError && list.isEmpty)
          const Text(
            'Nothing yet: import a list or start swiping.',
            style: _body,
          ),
        for (final s in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.label),
            subtitle: Text('${s.titles} titles'),
            trailing: s.sourceType == null
                ? null
                : IconButton(
                    tooltip: 'Remove ${s.label}',
                    icon: const Icon(Icons.close),
                    onPressed: () => _remove(context, ref, s),
                  ),
          ),
      ],
    );
  }
}
