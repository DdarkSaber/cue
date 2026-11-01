part of 'settings_screen.dart';

class _LibraryContentsData {
  const _LibraryContentsData(this.profile, this.titles, this.review);
  final Profile profile;
  final List<LibraryContentEntry> titles;
  final List<SourceObservation> review;
}

final _libraryContentsProvider = FutureProvider.autoDispose
    .family<_LibraryContentsData, String>((ref, id) async {
      ref.watch(libraryVersionProvider);
      ref.watch(decisionVersionProvider);
      ref.watch(settingsProvider);
      final db = ref.read(databaseProvider);
      final profile = await (db.select(
        db.profiles,
      )..where((p) => p.id.equals(id))).getSingleOrNull();
      if (profile == null) throw StateError('This library no longer exists');
      return _LibraryContentsData(
        profile,
        await ref.read(libraryRepositoryProvider).contents(id),
        await ref.read(importServiceProvider).reviewQueue(id),
      );
    });

/// Browsing is profile-scoped; opening this page never activates a library.
class LibraryContentsPage extends ConsumerStatefulWidget {
  const LibraryContentsPage({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<LibraryContentsPage> createState() =>
      _LibraryContentsPageState();
}

class _LibraryContentsPageState extends ConsumerState<LibraryContentsPage> {
  final _search = TextEditingController();
  String _query = '';
  MediaKind? _kind;
  bool _busy = false;

  @override
  void didUpdateWidget(LibraryContentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _query = '';
      _kind = null;
      _search.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    _search.clear();
    setState(() => _query = '');
  }

  Future<void> _use(Profile profile) async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).activate(profile.id);
      resetLibraryState(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_libraryName(profile)} is now in use.')),
        );
      }
    } on Object catch (error) {
      _error('Could not switch libraries. Try again.', error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message, Object error) {
    debugPrint('Library contents action failed (${error.runtimeType}).');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _remove(Profile profile, LibraryContentEntry row) async {
    final ok = await confirmAction(
      context,
      title: 'Remove ${row.title.displayTitle}?',
      body:
          'Its history, Will try and hidden status are removed from ${_libraryName(profile)} only. Other titles, import batches and other libraries stay. This title removal cannot be undone here.',
      confirmLabel: 'Remove title',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final lib = ref.read(libraryRepositoryProvider);
      await lib.removeTitle(profile.id, row.title.id);
      await lib.recomputeWeights(profile.id);
      ref.read(libraryVersionProvider.notifier).bump();
      ref.read(decisionVersionProvider.notifier).bump();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${row.title.displayTitle} removed.')),
        );
      }
    } on Object catch (error) {
      _error('Could not remove this title. Try again.', error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Profile profile) async {
    setState(() => _busy = true);
    try {
      await _deleteLocalLibrary(context, ref, profile);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _frame(Widget child) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: child,
    ),
  );

  String _subtitle(LibraryContentEntry row) => [
    if (!row.metadataAvailable) 'Catalog details unavailable',
    if (row.entry != null) row.entry!.state.label,
    if (row.entry?.rating != null) row.entry!.rating!.label,
    if (row.shortlisted) 'Will try',
    if (row.excluded) 'Not interested',
    if (row.deferred) 'Not now',
    if (row.title.year != null) '${row.title.year}',
  ].join(', ');

  List<Widget> _contents(_LibraryContentsData data, String? activeId) {
    final counts = <MediaKind, int>{};
    for (final row in data.titles) {
      counts.update(row.title.kind, (n) => n + 1, ifAbsent: () => 1);
    }
    final filtered =
        data.titles.where((row) {
          final t = row.title;
          return (_kind == null || t.kind == _kind) &&
              (_query.isEmpty ||
                  t.displayTitle.toLowerCase().contains(_query) ||
                  (t.altTitle?.toLowerCase().contains(_query) ?? false));
        }).toList()..sort((a, b) {
          final byName = a.title.displayTitle.toLowerCase().compareTo(
            b.title.displayTitle.toLowerCase(),
          );
          return byName == 0 ? a.title.id.compareTo(b.title.id) : byName;
        });
    final rows = <({MediaKind kind, LibraryContentEntry? entry, int count})>[];
    for (final kind in MediaKind.values) {
      final group = filtered.where((r) => r.title.kind == kind).toList();
      if (group.isEmpty) continue;
      rows.add((kind: kind, entry: null, count: group.length));
      rows.addAll(
        group.map((r) => (kind: kind, entry: r, count: group.length)),
      );
    }
    return [
      SliverToBoxAdapter(
        child: _frame(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${data.titles.length} titles, grouped by type and sorted A-Z.',
                style: _body,
              ),
              const SizedBox(height: CueSpace.sm),
              Text(
                activeId == data.profile.id
                    ? 'This is your active library.'
                    : 'Viewing only. Your active library is unchanged.',
                style: _body,
              ),
              const SizedBox(height: CueSpace.md),
              if (data.review.isNotEmpty) ...[
                CueSectionLabel('Needs review (${data.review.length})'),
                const Text(
                  'Unmatched imports stay here until you confirm or dismiss them. They may still appear in suggestions. Review changes this library only.',
                  style: _body,
                ),
                for (final observation in data.review)
                  CueListRow(
                    title: observation.rawTitle,
                    subtitle: 'Search and confirm the matching title',
                    onTap: () => showReviewSheet(context, observation),
                  ),
                const SizedBox(height: CueSpace.md),
              ],
              Wrap(
                spacing: CueSpace.sm,
                runSpacing: CueSpace.sm,
                children: [
                  if (activeId != data.profile.id)
                    CueSecondaryButton(
                      label: 'Use this library',
                      onPressed: _busy ? null : () => _use(data.profile),
                    ),
                  CueSecondaryButton(
                    label: 'Delete this library',
                    destructive: true,
                    onPressed: _busy ? null : () => _delete(data.profile),
                  ),
                ],
              ),
              if (data.titles.isNotEmpty) ...[
                const SizedBox(height: CueSpace.lg),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Find a title in this library',
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: CueSpace.md),
                Wrap(
                  spacing: CueSpace.sm,
                  runSpacing: CueSpace.sm,
                  children: [
                    CueChoiceChip(
                      label: 'All types',
                      selected: _kind == null,
                      onTap: () => setState(() => _kind = null),
                    ),
                    for (final kind in MediaKind.values)
                      if (counts.containsKey(kind))
                        CueChoiceChip(
                          key: ValueKey('kind-${kind.name}'),
                          label: '${kind.label} (${counts[kind]})',
                          selected: _kind == kind,
                          onTap: () => setState(() => _kind = kind),
                        ),
                  ],
                ),
              ],
              if (filtered.isEmpty) ...[
                const SizedBox(height: CueSpace.lg),
                Text(
                  data.titles.isEmpty
                      ? 'This library has no titles yet.'
                      : 'No titles match these filters.',
                  style: _body,
                ),
              ],
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final entry = row.entry;
          return _frame(
            entry == null
                ? CueSectionLabel('${row.kind.label} (${row.count})')
                : CueListRow(
                    key: ValueKey('library-title-${entry.title.id}'),
                    title: entry.title.displayTitle,
                    subtitle: _subtitle(entry),
                    trailing: IconButton(
                      tooltip: 'Remove ${entry.title.displayTitle}',
                      icon: const Icon(Icons.close),
                      onPressed: _busy
                          ? null
                          : () => _remove(data.profile, entry),
                    ),
                  ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_libraryContentsProvider(widget.profileId));
    final active = ref.watch(profileIdProvider).value;
    final desktop = context.cueLayout == CueLayout.desktop;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 4 : 10,
            desktop ? 96 : CueSpace.lg,
            desktop ? 4 : 10,
            CueSpace.xl,
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _frame(
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CueRoundButton(
                            icon: CueIcons.back,
                            tooltip: 'Back',
                            visualSize: 40,
                            iconSize: 18,
                            onPressed: () =>
                                context.go('${CueRoutes.settings}/library'),
                          ),
                          const SizedBox(width: CueSpace.sm),
                          Expanded(
                            child: CueRouteHeader(
                              kicker: 'Library contents',
                              title: data.value == null
                                  ? 'Contents'
                                  : _libraryName(data.value!.profile),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CueSpace.lg),
                    ],
                  ),
                ),
              ),
              ...data.when(
                loading: () => [
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(color: CueColors.accent),
                  ),
                ],
                error: (_, _) => [
                  SliverToBoxAdapter(
                    child: _frame(
                      Column(
                        children: [
                          const Text(
                            'This library could not be read. It may have been deleted.',
                            style: _body,
                          ),
                          CueSecondaryButton(
                            label: 'Retry',
                            onPressed: () => ref.invalidate(
                              _libraryContentsProvider(widget.profileId),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                data: (value) => _contents(value, active),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
