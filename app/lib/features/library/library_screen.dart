import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/icons.dart';
import '../../app/providers.dart';
import '../../app/route_scaffold.dart';
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
import '../imports/import_screen.dart' show importSourceName;
import 'entry_sheet.dart';
import 'add_title_sheet.dart';
import 'review_sheet.dart';

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
  String _filter = '';

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
          const AddTitleButton(),
          const SizedBox(height: CueSpace.md),
          ...(d.isEmpty ? _empty(context) : _full(context, d)),
        ],
      ),
    );
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
    bool match(Title t) =>
        _filter.isEmpty ||
        t.displayTitle.toLowerCase().contains(_filter) ||
        (t.altTitle?.toLowerCase().contains(_filter) ?? false);
    final cutoff = DateTime.now().subtract(const Duration(days: 3 * 365));
    final rewatch = d.entries
        .where((e) => e.$1.rating?.isRewatch ?? false)
        .length;
    final longAgo = d.entries
        .where((e) => e.$1.actualWatchedAt?.isBefore(cutoff) ?? false)
        .toList();
    final active = d.entries
        .where(
          (e) =>
              (e.$1.state == LibraryState.watching ||
                  e.$1.state == LibraryState.reading ||
                  e.$1.state == LibraryState.caughtUp ||
                  e.$1.state == LibraryState.onHold) &&
              match(e.$2),
        )
        .toList();
    final done = d.entries
        .where(
          (e) =>
              (e.$1.state == LibraryState.completed ||
                  e.$1.state == LibraryState.seen ||
                  e.$1.state == LibraryState.partial ||
                  e.$1.state == LibraryState.dropped) &&
              match(e.$2),
        )
        .toList();
    final planned = d.entries
        .where((e) => e.$1.state == LibraryState.planned && match(e.$2))
        .toList();
    final imported = d.batches.where((b) => b.state == 'completed').toList();

    return [
      _RevisitTile(
        rewatch: rewatch,
        longAgo: longAgo.length,
        onDeal: rewatch + longAgo.length == 0 ? null : _dealRevisit,
      ),
      const SizedBox(height: CueSpace.md),
      Text(
        imported.isEmpty
            ? 'No list imported yet. Cue only knows what you decided here.'
            : 'Your list is in: ${d.entries.length} titles, from ${imported.map((b) => importSourceName(b.sourceType)).toSet().join(', ')}.',
        style: const TextStyle(fontSize: 14, color: CueColors.textMuted),
      ),
      const SizedBox(height: CueSpace.sm),
      Wrap(
        spacing: CueSpace.md,
        children: [
          CueSecondaryButton(
            label: imported.isEmpty ? 'Import a list' : 'Import more',
            onPressed: () => context.go(CueRoutes.importer),
          ),
        ],
      ),
      const SizedBox(height: CueSpace.md),
      TextField(
        decoration: const InputDecoration(
          hintText: 'Find in your library',
          prefixIcon: Padding(
            padding: EdgeInsets.all(12),
            child: CueIcon(CueIcons.library, size: 18),
          ),
        ),
        onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
      ),
      if (d.review.isNotEmpty)
        _Section(
          label: 'Needs review (${d.review.length})',
          note: 'Imported entries Cue could not match for sure. They do not affect recommendations.',
          children: [
            for (final o in d.review.where(
              (o) =>
                  _filter.isEmpty || o.rawTitle.toLowerCase().contains(_filter),
            ))
              CueListRow(
                title: o.rawTitle,
                subtitle: 'Match it',
                onTap: () => showReviewSheet(context, o),
              ),
          ],
        ),
      if (longAgo.isNotEmpty)
        _Section(
          label: 'Watched 3+ years ago',
          children: [
            for (final e in longAgo.where((e) => match(e.$2)))
              _entryRow(context, e),
          ],
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
      if (d.hidden.isNotEmpty)
        _Section(
          label: 'Hidden from your deck',
          note: 'Restore brings a title back into recommendations.',
          children: [
            for (final h in d.hidden.where((h) => match(h.$1)))
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
      if (d.decisions.isNotEmpty)
        _Section(
          label: 'Recent decisions',
          children: [
            for (final r
                in d.decisions
                    .where((r) => r.title != null && match(r.title!))
                    .take(20))
              CueListRow(
                title: r.title!.displayTitle,
                subtitle:
                    '${_actionLabel(r.event.action)} · ${DateFormat.MMMd().add_jm().format(r.event.createdAt)}',
                onTap: () => showEntrySheet(context, r.title!),
              ),
          ],
        ),
    ];
  }

  Widget _entryRow(BuildContext context, (LibraryEntry, Title) e) {
    final (entry, title) = e;
    final fresh = newChapters(entry, title);
    return CueListRow(
      title: title.displayTitle,
      subtitle: [
        title.kind.label,
        entry.state.label,
        ?entry.rating?.label,
        if (entry.progressValue != null)
          '${entry.progressUnit ?? 'progress'} ${entry.progressValue!.round()}'
              '${entry.latestKnown != null ? ' of ${entry.latestKnown!.round()}' : ''}',
      ].join(' · '),
      trailing: fresh == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CueColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(CueRadius.pill),
              ),
              child: Text(
                fresh == 1 ? '1 new chapter' : '$fresh new chapters',
                style: const TextStyle(fontSize: 12, color: CueColors.accent),
              ),
            ),
      onTap: () => showEntrySheet(context, title),
    );
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
              Text(
                'Revisit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
