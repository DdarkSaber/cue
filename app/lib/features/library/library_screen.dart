import 'dart:convert';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/icons.dart';
import '../../app/providers.dart';
import '../../app/route_scaffold.dart';
import '../../app/sheets.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/db/database.dart';
import '../../data/library_repository.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/library.dart';
import '../../domain/models/quick_mood.dart';
import '../../domain/models/title.dart';
import '../deck/deck_controller.dart';
import '../imports/source_names.dart';
import 'entry_sheet.dart';
import 'add_title_sheet.dart';
import 'library_view.dart';
import 'review_sheet.dart';
import 'rating_cards.dart';
import '../../data/library_rating_service.dart';

/// Everything the Library route shows, loaded in one go.
class LibraryData {
  const LibraryData({
    required this.entries,
    required this.hidden,
    required this.decisions,
    required this.review,
    required this.batches,
  });

  final List<(LibraryEntry, Title)> entries;
  final List<(Title, bool, DateTime?)> hidden;
  final List<DecisionRow> decisions;
  final List<SourceObservation> review;
  final List<ImportBatch> batches;

  bool get isEmpty =>
      entries.isEmpty && hidden.isEmpty && decisions.isEmpty && review.isEmpty;
}

final libraryDataProvider = FutureProvider.autoDispose<LibraryData>((
  ref,
) async {
  ref.watch(libraryVersionProvider);
  ref.watch(decisionVersionProvider);
  final id = await ref.watch(profileIdProvider.future);
  final lib = ref.read(libraryRepositoryProvider);
  final imports = ref.read(importServiceProvider);
  final results = await Future.wait([
    lib.entries(id),
    lib.hidden(id),
    lib.recentDecisions(id, limit: 30),
    imports.reviewQueue(id),
    imports.batches(id),
  ]);
  return LibraryData(
    entries: results[0] as List<(LibraryEntry, Title)>,
    hidden: results[1] as List<(Title, bool, DateTime?)>,
    decisions: results[2] as List<DecisionRow>,
    review: results[3] as List<SourceObservation>,
    batches: results[4] as List<ImportBatch>,
  );
});

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryQuery _q = const LibraryQuery();
  bool _selecting = false;
  bool _filtersOpen = false;
  final Set<String> _selected = {};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Saves [rating] on every row, keeping each entry's other fields.
  Future<void> _rate(List<LibraryRow> rows, Rating? rating) async {
    if (rows.isEmpty) return;
    final id = await ref.read(profileIdProvider.future);
    final repo = ref.read(libraryRepositoryProvider);
    for (final (e, t) in rows) {
      await repo.saveEntry(
        id,
        t.id,
        state: e.state,
        rating: rating,
        rewatchMood: e.rewatchMood,
        actualWatchedAt: e.actualWatchedAt,
      );
    }
    await repo.recomputeWeights(id);
    if (!mounted) return;
    ref.read(libraryVersionProvider.notifier).bump();
    final what = rows.length == 1
        ? rows.first.$2.displayTitle
        : '${rows.length} titles';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rating == null
              ? 'Cleared the rating on $what.'
              : 'Rated $what ${rating.label}. Cue will use this for picks.',
        ),
      ),
    );
    if (_selecting) setState(_selected.clear);
  }

  Future<void> _removeRows(List<LibraryRow> rows) async {
    if (rows.isEmpty) return;
    final ok = await confirmAction(
      context,
      title: rows.length == 1
          ? 'Remove ${rows.first.$2.displayTitle}?'
          : 'Remove ${rows.length} titles?',
      body: 'They leave this library and stop counting towards your taste. They may show up in suggestions again.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    final id = await ref.read(profileIdProvider.future);
    final repo = ref.read(libraryRepositoryProvider);
    for (final (_, t) in rows) {
      await repo.removeEntry(id, t.id);
    }
    await repo.recomputeWeights(id);
    if (!mounted) return;
    ref.read(libraryVersionProvider.notifier).bump();
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rows.length == 1
              ? 'Removed from your library.'
              : 'Removed ${rows.length} titles from your library.',
        ),
      ),
    );
  }

  int get _activeOptions =>
      (_q.sort != LibrarySort.recent ? 1 : 0) +
      (_q.kind != null ? 1 : 0) +
      (_q.status != null ? 1 : 0);

  void _clearFilters() {
    _search.clear();
    setState(() => _q = LibraryQuery(sort: _q.sort));
  }

  Future<void> _openRatings({bool followUp = false}) async {
    final id = await ref.read(profileIdProvider.future);
    if (!mounted) return;
    final service = LibraryRatingService(
      ref.read(databaseProvider),
      ref.read(libraryRepositoryProvider),
      ref.read(recommendationRepositoryProvider),
      clock: ref.read(clockProvider),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LibraryRatingCards(
        service: service,
        profileId: id,
        followUp: followUp,
        onChanged: () {
          if (!mounted) return;
          ref.read(libraryVersionProvider.notifier).bump();
          ref.read(decisionVersionProvider.notifier).bump();
        },
      ),
    );
  }

  void _dealRevisit() {
    ref.read(deckFiltersProvider.notifier).setMood(QuickMood.revisit);
    context.go(CueRoutes.forYou);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(libraryDataProvider);
    return RouteScaffold(
      kicker: 'Your corner of Cue',
      title: 'Library',
      children: data.when(
        loading: () => const [LinearProgressIndicator(color: CueColors.accent)],
        error: (_, _) => const [Text('Your library could not be read.')],
        data: (d) => [
          Wrap(
            spacing: CueSpace.md,
            runSpacing: CueSpace.sm,
            children: [
              const AddTitleButton(),
              if (!d.isEmpty)
                CueSecondaryButton(
                  label: d.batches.any((b) => b.state == 'completed')
                      ? 'Import more'
                      : 'Import a list',
                  onPressed: () => context.go(CueRoutes.importer),
                ),
              CueSecondaryButton(
                label: 'Review shortlist picks',
                onPressed: () => _openRatings(followUp: true),
              ),
            ],
          ),
          const SizedBox(height: CueSpace.md),
          ...(d.isEmpty ? _empty(context) : _full(context, d)),
        ],
      ),
    );
  }

  /// The suggested title's name, from the stored candidate.
  static String? _maybe(SourceObservation o) {
    final raw = o.candidateJson;
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map;
    return (j['titleEn'] ?? j['titleRomaji'] ?? j['titleNative']) as String?;
  }

  Future<void> _acceptSimilar(List<SourceObservation> review) async {
    final id = await ref.read(profileIdProvider.future);
    await ref.read(importServiceProvider).acceptAllSimilar(id, review);
    await ref.read(libraryRepositoryProvider).recomputeWeights(id);
    ref.read(libraryVersionProvider.notifier).bump();
  }

  Future<void> _dismissAll(
    BuildContext context,
    List<SourceObservation> review,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Clear ${review.length} entries from review?',
      body: 'They leave the review queue. Your imports and their undo stay as they are.',
      confirmLabel: 'Clear them',
    );
    if (!ok) return;
    await ref.read(importServiceProvider).dismissAll(review);
    ref.read(libraryVersionProvider.notifier).bump();
  }

  List<Widget> _empty(BuildContext context) => [
    const Text(
      'Your history belongs here. Bring a list, or keep discovering.',
      style: TextStyle(fontSize: 15, height: 1.5, color: CueColors.textMuted),
    ),
    const SizedBox(height: CueSpace.sm),
    const Text(
      'Until then Cue cannot know what you have already watched, so it may suggest some of it.',
      style: TextStyle(fontSize: 14, height: 1.5, color: CueColors.textMuted),
    ),
    const SizedBox(height: CueSpace.lg),
    Wrap(
      spacing: CueSpace.md,
      runSpacing: CueSpace.sm,
      children: [
        CuePrimaryButton(
          label: 'Import a list',
          onPressed: () => context.go(CueRoutes.importer),
        ),
        CueSecondaryButton(
          label: 'Keep discovering',
          onPressed: () => context.go(CueRoutes.forYou),
        ),
      ],
    ),
  ];

  List<Widget> _full(BuildContext context, LibraryData d) {
    final textOnly = _q.kind == null && _q.status == null;
    bool text(Title t) => _q.matchesText(t);
    final cutoff = DateTime.now().subtract(const Duration(days: 3 * 365));
    final rewatch = d.entries
        .where((e) => e.$1.rating?.isRewatch ?? false)
        .length;
    final longAgoAll = d.entries
        .where((e) => e.$1.actualWatchedAt?.isBefore(cutoff) ?? false)
        .toList();
    List<LibraryRow> inStates(Set<LibraryState> states) =>
        _q.apply(d.entries.where((e) => states.contains(e.$1.state)));
    final longAgo = _q.apply(longAgoAll);
    final active = inStates({
      LibraryState.watching,
      LibraryState.reading,
      LibraryState.caughtUp,
      LibraryState.onHold,
    });
    final done = inStates({
      LibraryState.completed,
      LibraryState.seen,
      LibraryState.partial,
      LibraryState.dropped,
    });
    final planned = inStates({LibraryState.planned});
    final noStatus = inStates({LibraryState.none});
    final shown = [...active, ...done, ...planned, ...noStatus];
    final imported = d.batches.where((b) => b.state == 'completed').toList();
    final kinds = {for (final e in d.entries) e.$2.kind}.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final summary = TasteSummary.from(d.entries);
    final needle = _q.text.toLowerCase();
    final review = textOnly
        ? d.review
              .where((o) => o.rawTitle.toLowerCase().contains(needle))
              .toList()
        : <SourceObservation>[];

    return [
      _TasteCard(summary: summary, onRate: () => _openRatings()),
      const SizedBox(height: CueSpace.md),
      Text(
        imported.isEmpty
            ? 'No list imported yet. Cue only knows what you decided here.'
            : 'Your list is in: ${d.entries.length} titles, from ${imported.map((b) => importSourceName(b.sourceType)).toSet().join(', ')}.',
        style: const TextStyle(fontSize: 14, color: CueColors.textMuted),
      ),
      const SizedBox(height: CueSpace.md),
      _RevisitTile(
        rewatch: rewatch,
        longAgo: longAgoAll.length,
        onDeal: rewatch + longAgoAll.length == 0 ? null : _dealRevisit,
      ),
      const SizedBox(height: CueSpace.xs),
      const CueSectionLabel('Your titles'),
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Find in your library',
          prefixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: CueIcon(CueIcons.library, size: 18),
          ),
          suffixIcon: _q.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  constraints: const BoxConstraints(
                    minWidth: CueSize.minTarget,
                    minHeight: CueSize.minTarget,
                  ),
                  icon: const CueIcon(CueIcons.close, size: 16),
                  onPressed: () {
                    _search.clear();
                    setState(() => _q = _q.copyWith(text: ''));
                  },
                ),
        ),
        onChanged: (v) => setState(() => _q = _q.copyWith(text: v.trim())),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          expanded: _filtersOpen,
          child: TextButton.icon(
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            style: _tapTarget,
            icon: Icon(
              _filtersOpen ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            label: Text(
              [
                'Sort and filter',
                if (_activeOptions > 0) '($_activeOptions)',
              ].join(' '),
            ),
          ),
        ),
      ),
      if (_filtersOpen) ...[
        _ChipRow(
          label: 'Sort by',
          chips: [
            for (final s in LibrarySort.values)
              CueChoiceChip(
                label: s.label,
                selected: _q.sort == s,
                onTap: () => setState(() => _q = _q.copyWith(sort: s)),
              ),
          ],
        ),
        if (kinds.length > 1)
          _ChipRow(
            label: 'Format',
            chips: [
              CueChoiceChip(
                label: 'All',
                selected: _q.kind == null,
                onTap: () => setState(() => _q = _q.copyWith(clearKind: true)),
              ),
              for (final k in kinds)
                CueChoiceChip(
                  label: k.label,
                  selected: _q.kind == k,
                  onTap: () => setState(() => _q = _q.copyWith(kind: k)),
                ),
            ],
          ),
        _ChipRow(
          label: 'Status',
          chips: [
            CueChoiceChip(
              label: 'All',
              selected: _q.status == null,
              onTap: () => setState(() => _q = _q.copyWith(clearStatus: true)),
            ),
            for (final s in StatusFilter.values)
              CueChoiceChip(
                label: s.label,
                selected: _q.status == s,
                onTap: () => setState(() => _q = _q.copyWith(status: s)),
              ),
          ],
        ),
      ],
      const SizedBox(height: CueSpace.xs),
      Wrap(
        spacing: CueSpace.md,
        runSpacing: CueSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              _q.filtering
                  ? '${shown.length} of ${d.entries.length} titles'
                  : '${d.entries.length} titles',
              style: const TextStyle(fontSize: 13, color: CueColors.textMuted),
            ),
          ),
          if (_q.filtering)
            TextButton(
              onPressed: _clearFilters,
              style: _tapTarget,
              child: const Text('Clear filters'),
            ),
          TextButton(
            onPressed: d.entries.isEmpty
                ? null
                : () => setState(() {
                    _selecting = !_selecting;
                    _selected.clear();
                  }),
            style: _tapTarget,
            child: Text(_selecting ? 'Done selecting' : 'Select several'),
          ),
        ],
      ),
      if (_selecting)
        _BulkBar(
          count: _selected.length,
          onSelectAll: () => setState(() {
            _selected
              ..clear()
              ..addAll(shown.map((r) => r.$2.id));
          }),
          onRate: (r) => _rate(_pickedRows(d), r),
          onRemove: () => _removeRows(_pickedRows(d)),
        ),
      if (d.entries.isNotEmpty && shown.isEmpty && longAgo.isEmpty)
        _NoMatches(onClear: _clearFilters),
      if (review.isNotEmpty)
        _Section(
          label: 'Needs review (${d.review.length})',
          note: 'Titles Cue could not match on its own. They are saved on this device, are not yet recognised as history and may still appear in suggestions. Tap one to search and confirm its match.',
          children: [
            for (final o in review)
              CueListRow(
                title: o.rawTitle,
                subtitle: _maybe(o) == null ? 'Match it' : 'Maybe ${_maybe(o)}',
                onTap: () => showReviewSheet(context, o),
              ),
            if (d.review.any((o) => o.candidateJson != null))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _acceptSimilar(d.review),
                  style: _tapTarget,
                  child: Text(
                    'Accept all ${d.review.where((o) => o.candidateJson != null).length} suggested matches',
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _dismissAll(context, d.review),
                style: _tapTarget,
                child: const Text('None of these are in my history'),
              ),
            ),
          ],
        ),
      if (longAgo.isNotEmpty)
        _Section(
          label: 'Watched 3+ years ago',
          children: [for (final e in longAgo) _entryRow(context, e)],
        ),
      if (active.isNotEmpty)
        _Section(
          label: 'Watching and reading',
          children: [for (final e in active) _entryRow(context, e)],
        ),
      if (done.isNotEmpty)
        _Section(
          label: 'Watched and read',
          children: [for (final e in done) _entryRow(context, e)],
        ),
      if (planned.isNotEmpty)
        _Section(
          label: 'Planned',
          children: [for (final e in planned) _entryRow(context, e)],
        ),
      if (noStatus.isNotEmpty)
        _Section(
          label: 'No status',
          note: 'A rating does not set a watching or reading status. Your saved ratings remain here.',
          children: [for (final e in noStatus) _entryRow(context, e)],
        ),
      if (d.hidden.isNotEmpty && textOnly)
        _Section(
          label: 'Hidden from your deck',
          note: 'Restore brings a title back into recommendations.',
          children: [
            for (final h in d.hidden.where((h) => text(h.$1)))
              CueListRow(
                title: h.$1.displayTitle,
                subtitle: h.$2
                    ? 'Not interested'
                    : 'Not now, until ${DateFormat.MMMd().format(h.$3!)}',
                trailing: CueSecondaryButton(
                  label: 'Restore',
                  onPressed: () async {
                    final id = await ref.read(profileIdProvider.future);
                    await ref
                        .read(decisionServiceProvider)
                        .restore(id, h.$1.id);
                    ref.read(libraryVersionProvider.notifier).bump();
                  },
                ),
              ),
          ],
        ),
      if (d.decisions.isNotEmpty && textOnly)
        _Section(
          label: 'Recent decisions',
          children: [
            for (final r
                in d.decisions
                    .where((r) => r.title != null && text(r.title!))
                    .take(20))
              CueListRow(
                title: r.title!.displayTitle,
                subtitle:
                    '${_actionLabel(r.event.action)} · ${DateFormat.MMMd().add_jm().format(r.event.createdAt)}',
                onTap: () => showEntrySheet(context, r.title!),
              ),
          ],
        ),
      const Padding(
        padding: EdgeInsets.only(top: CueSpace.lg),
        child: Text(
          'Sources combine in this library; separate libraries stay separate. Browse or remove titles in Settings > This library.',
          style: TextStyle(fontSize: 12, color: CueColors.textMuted),
        ),
      ),
    ];
  }

  static const _tapTarget = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(CueSize.minTarget, CueSize.minTarget),
    ),
    foregroundColor: WidgetStatePropertyAll(CueColors.accent),
  );

  List<LibraryRow> _pickedRows(LibraryData d) => [
    for (final r in d.entries)
      if (_selected.contains(r.$2.id)) r,
  ];

  Widget _entryRow(BuildContext context, LibraryRow e) {
    final (entry, title) = e;
    final fresh = newChapters(entry, title);
    final picked = _selected.contains(title.id);
    final row = CueListRow(
      title: title.displayTitle,
      leading: _selecting
          ? ExcludeSemantics(
              child: Icon(
                picked ? Icons.check_box : Icons.check_box_outline_blank,
                color: picked ? CueColors.accent : CueColors.textMuted,
              ),
            )
          : null,
      subtitle: [
        title.kind.label,
        entry.state.label,
        ?entry.rating?.label,
        if (entry.progressValue != null)
          '${entry.progressUnit ?? 'progress'} ${entry.progressValue!.round()}'
              '${entry.latestKnown != null ? ' of ${entry.latestKnown!.round()}' : ''}',
      ].join(' · '),
      trailing: _selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fresh != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: CueColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(CueRadius.pill),
                      ),
                      child: Text(
                        fresh == 1 ? '1 new chapter' : '$fresh new chapters',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CueColors.accent,
                        ),
                      ),
                    ),
                  ),
                RatingMenuButton(
                  title: title.displayTitle,
                  current: entry.rating,
                  onSelected: (r) => _rate([e], r),
                ),
              ],
            ),
      onTap: _selecting
          ? () => setState(() {
              picked ? _selected.remove(title.id) : _selected.add(title.id);
            })
          : () => showEntrySheet(context, title),
    );
    return _selecting ? Semantics(selected: picked, child: row) : row;
  }

  static String _actionLabel(String action) => switch (action) {
    'read' => 'Read it',
    'undo' => 'Undone',
    'restore' => 'Restored',
    _ => Decision.parse(action)?.label ?? action,
  };
}

class _RevisitTile extends StatelessWidget {
  const _RevisitTile({
    required this.rewatch,
    required this.longAgo,
    required this.onDeal,
  });
  final int rewatch;
  final int longAgo;
  final VoidCallback? onDeal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x29A9D7FF)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A3544), Color(0xFF11171F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            spacing: 8,
            children: [
              CueIcon(CueIcons.repeat, size: 18, color: CueColors.accent),
              Flexible(
                child: Text(
                  'Revisit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rewatch + longAgo == 0
                ? 'Rate titles Rewatched or Would rewatch, or add real watch dates, and they gather here.'
                : '$rewatch to rewatch${longAgo > 0 ? ', $longAgo watched 3+ years ago' : ''}.',
            style: const TextStyle(fontSize: 14, color: Color(0xFFC1DEF7)),
          ),
          if (onDeal != null) ...[
            const SizedBox(height: CueSpace.md),
            CuePrimaryButton(label: 'Deal Revisit', onPressed: onDeal),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({required this.label, required this.children, this.note});
  final String label;
  final String? note;
  final List<Widget> children;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _all = false;
  static const _preview = 6;

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    final shown = _all
        ? widget.children
        : widget.children.take(_preview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CueSectionLabel(widget.label),
        if (widget.note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.note!,
              style: const TextStyle(fontSize: 13, color: CueColors.textMuted),
            ),
          ),
        CueGroup(children: shown),
        if (widget.children.length > _preview)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _all = !_all),
              style: TextButton.styleFrom(
                minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
                foregroundColor: CueColors.accent,
              ),
              child: Text(
                _all ? 'Show fewer' : 'Show all ${widget.children.length}',
              ),
            ),
          ),
      ],
    );
  }
}

/// Chapters past where the person stopped, only when both numbers are
/// known. An unknown total is never treated as "nothing new".
int? newChapters(LibraryEntry e, Title t) {
  if (!t.kind.isReading || e.progressValue == null) return null;
  final latest = [t.chapters?.toDouble(), e.latestKnown]
      .whereType<double>()
      .fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  if (latest == null) return null;
  final n = (latest - e.progressValue!).floor();
  return n > 0 ? n : null;
}

/// A one-tap rating menu for a library row.
class RatingMenuButton extends StatelessWidget {
  const RatingMenuButton({
    super.key,
    required this.title,
    required this.current,
    required this.onSelected,
  });

  final String title;
  final Rating? current;
  final ValueChanged<Rating?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: current == null
          ? 'Rate $title'
          : 'Rated ${current!.label}. Change rating for $title',
      constraints: const BoxConstraints(minWidth: 200),
      color: CueColors.surfaceHigh,
      icon: Icon(
        current == null ? Icons.star_border_rounded : Icons.star_rounded,
        color: current == null ? CueColors.textMuted : CueColors.accent,
      ),
      iconSize: 24,
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(CueSize.minTarget, CueSize.minTarget),
        ),
      ),
      onSelected: (v) => onSelected(v is Rating ? v : null),
      itemBuilder: (_) => [
        for (final r in Rating.values)
          CheckedPopupMenuItem<Object>(
            value: r,
            checked: current == r,
            height: CueSize.minTarget,
            child: Text(r.label),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<Object>(
          value: 'clear',
          height: CueSize.minTarget,
          child: Text('No rating'),
        ),
      ],
    );
  }
}

/// A labelled, wrapping row of filter chips.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.chips});
  final String label;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CueSpace.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: CueColors.textMuted),
          ),
        ),
        Wrap(spacing: 8, runSpacing: 0, children: chips),
      ],
    ),
  );
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CueSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nothing in your library matches that.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Try fewer filters, or import more of your history.',
          style: TextStyle(fontSize: 14, color: CueColors.textMuted),
        ),
        const SizedBox(height: CueSpace.sm),
        Wrap(
          spacing: CueSpace.md,
          runSpacing: CueSpace.sm,
          children: [
            CueSecondaryButton(label: 'Clear filters', onPressed: onClear),
            CueSecondaryButton(
              label: 'Import a list',
              onPressed: () => context.go(CueRoutes.importer),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Actions for the titles ticked in "Select several".
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onSelectAll,
    required this.onRate,
    required this.onRemove,
  });
  final int count;
  final VoidCallback onSelectAll;
  final ValueChanged<Rating?> onRate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: CueSpace.sm),
      padding: const EdgeInsets.all(CueSpace.md),
      decoration: BoxDecoration(
        color: CueColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CueColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              count == 0 ? 'Tap titles to select them.' : '$count selected',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: CueSpace.sm),
          Wrap(
            spacing: CueSpace.sm,
            runSpacing: CueSpace.sm,
            children: [
              CueSecondaryButton(
                label: 'Select all shown',
                onPressed: onSelectAll,
              ),
              PopupMenuButton<Object>(
                enabled: count > 0,
                tooltip: 'Rate selected titles',
                color: CueColors.surfaceHigh,
                onSelected: (v) => onRate(v is Rating ? v : null),
                itemBuilder: (_) => [
                  for (final r in Rating.values)
                    PopupMenuItem<Object>(
                      value: r,
                      height: CueSize.minTarget,
                      child: Text(r.label),
                    ),
                  const PopupMenuItem<Object>(
                    value: 'clear',
                    height: CueSize.minTarget,
                    child: Text('No rating'),
                  ),
                ],
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: CueSize.minTarget,
                    minWidth: CueSize.minTarget,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CueRadius.chip),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Text(
                    'Rate selected',
                    style: TextStyle(
                      fontSize: 15,
                      color: count > 0 ? CueColors.text : CueColors.textMuted,
                    ),
                  ),
                ),
              ),
              CueSecondaryButton(
                label: 'Remove selected',
                destructive: true,
                onPressed: count == 0 ? null : onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What Cue has learned from your ratings, and what to do to teach it more.
class _TasteCard extends StatelessWidget {
  const _TasteCard({required this.summary, required this.onRate});
  final TasteSummary summary;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final headline = s.rated == 0
        ? 'Cue is still learning your taste'
        : 'Your taste, from ${s.rated} rated ${s.rated == 1 ? 'title' : 'titles'}';
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(CueSpace.lg),
        decoration: BoxDecoration(
          color: CueColors.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CueColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                headline,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: CueSpace.sm),
            if (s.liked > 0) ...[
              if (s.genres.isNotEmpty)
                _fact('Genres you lean towards', s.genres.join(', ')),
              if (s.kinds.isNotEmpty)
                _fact(
                  'Formats you rate well',
                  s.kinds.map((k) => k.label).join(', '),
                ),
            ] else
              const Text(
                'Rate a few titles you know and Cue starts to favour what you like and steer away from what you did not.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: CueColors.textMuted,
                ),
              ),
            const SizedBox(height: CueSpace.sm),
            const Text(
              'Recommendations follow your ratings first. Imported titles you did not rate are only weak hints, and your swipes on the deck add to it.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: CueColors.textMuted,
              ),
            ),
            const SizedBox(height: CueSpace.md),
            CuePrimaryButton(label: 'Rate more titles', onPressed: onRate),
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: CueColors.textMuted),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 14, height: 1.4),
    ),
  );
}
