part of 'settings_screen.dart';

/// One source of titles in the active library: an import source (all its
/// batches together) or the deck.
class _SourceCount {
  const _SourceCount(this.label, this.titles, {this.sourceType});
  final String label;
  final int titles;

  /// Null for deck swipes, which are removed with Reset swipes instead.
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
  for (final b in batches) {
    final obs = await (db.select(
      db.sourceObservations,
    )..where((o) => o.batchId.equals(b.id) & o.titleId.isNotNull())).get();
    byType
        .putIfAbsent(b.sourceType, () => {})
        .addAll(obs.map((o) => o.titleId!));
  }
  final decided = await (db.select(
    db.decisionEvents,
  )..where((e) => e.profileId.equals(id) & e.reversesEventId.isNull())).get();
  return [
    for (final e in byType.entries)
      _SourceCount(importSourceName(e.key), e.value.length, sourceType: e.key),
    if (decided.isNotEmpty)
      _SourceCount('Deck swipes', decided.map((d) => d.titleId).toSet().length),
  ];
});

/// "What is in this library": titles per source, each import source with
/// an x that undoes all of its imports. Single titles are removed from
/// their own sheet in Library.
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
    final list = ref.watch(_contentsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CueSectionLabel('What is in this library'),
        if (list.isEmpty)
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
