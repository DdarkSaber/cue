part of '../import_screen.dart';

/// Import batches for the active library; refreshes whenever the library
/// changes (an import, an undo, a sync), wherever that happened.
final _batchesProvider = FutureProvider.autoDispose<List<ImportBatch>>((
  ref,
) async {
  ref.watch(libraryVersionProvider);
  final id = await ref.watch(profileIdProvider.future);
  return ref.read(importServiceProvider).batches(id);
});

class _PastImports extends ConsumerStatefulWidget {
  const _PastImports();

  @override
  ConsumerState<_PastImports> createState() => _PastImportsState();
}

class _PastImportsState extends ConsumerState<_PastImports> {
  String? _message;

  Future<void> _undo(ImportBatch b) async {
    final ok = await confirmAction(
      context,
      title: 'Undo this import?',
      body: 'Titles this import added or changed go back to how they were. Anything you edited since stays as it is.',
      confirmLabel: 'Undo import',
    );
    if (!ok) return;
    final id = await ref.read(profileIdProvider.future);
    final r = await ref.read(importServiceProvider).undo(id, b.id);
    await ref.read(libraryRepositoryProvider).recomputeWeights(id);
    ref.read(libraryVersionProvider.notifier).bump();
    if (!mounted) return;
    setState(() {
      _message = r.kept == 0
          ? 'Import undone. ${r.reverted} titles restored.'
          : 'Import undone. ${r.reverted} titles restored; ${r.kept} you edited since were kept.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(_batchesProvider).value;
    return Builder(
      builder: (context) {
        // Sync merges are bookkeeping, and undone imports are gone. Repeat
        // imports from one source (the same MAL account three times) show
        // as one row: the latest, with how many times it was imported.
        final kept =
            (batches ?? const <ImportBatch>[])
                .where((b) => b.sourceType != 'sync' && b.state == 'completed')
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final counts = <String, int>{};
        for (final b in kept) {
          counts[b.sourceType] = (counts[b.sourceType] ?? 0) + 1;
        }
        final seen = <String>{};
        final list = [
          for (final b in kept)
            if (seen.add(b.sourceType)) b,
        ];
        if (list.isEmpty && _message == null) return const SizedBox.shrink();
        final fmt = DateFormat.yMMMd().add_jm();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CueSectionLabel('Past imports'),
            if (_message != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFC1DEF7),
                  ),
                ),
              ),
            for (final b in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  importSourceName(b.sourceType),
                  style: const TextStyle(fontSize: 15),
                ),
                subtitle: Text(
                  counts[b.sourceType]! > 1
                      ? 'Last ${fmt.format(b.createdAt)} · imported ${counts[b.sourceType]} times'
                      : fmt.format(b.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: CueColors.textMuted,
                  ),
                ),
                trailing: CueSecondaryButton(
                  label: 'Undo last',
                  onPressed: () => _undo(b),
                ),
              ),
          ],
        );
      },
    );
  }
}
