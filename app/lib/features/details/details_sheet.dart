import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/icons.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/catalog_gateway.dart';
import '../../data/franchise_exclusion_repository.dart';
import '../../domain/franchise_identity.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/title.dart';
import '../deck/deck_controller.dart';
import '../library/entry_sheet.dart';
import '../settings/settings_screen.dart' show LibraryContentsPage;

/// Opens the details for a title. Returns a decision when the person picks
/// Will try or Watched from the sheet.
Future<Decision?> showDetailsSheet(
  BuildContext context,
  Title title, {
  String? reason,
  bool showActions = true,
}) => showCueSheet<Decision>(
  context,
  kicker: title.kind.label,
  title: title.displayTitle,
  body: (_) => DetailsBody(title: title, reason: reason),
  footer: showActions
      ? (ctx) => Row(
          spacing: CueSpace.md,
          children: [
            Expanded(
              child: CueSecondaryButton(
                label: Decision.watched.labelFor(reading: title.kind.isReading),
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(Decision.watched),
              ),
            ),
            Expanded(
              child: CuePrimaryButton(
                label: 'Will try',
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(Decision.willTry),
              ),
            ),
          ],
        )
      : null,
);

/// Where a reason line came from, in plain words; null when the line
/// already says it (or is a plain description of the work).
String? reasonSource(String reason) {
  if (reason.startsWith('Because you liked')) {
    return 'From the catalog’s “more like this” links for a title you rated well.';
  }
  if (reason.contains('your imports')) {
    return 'Based on imported history, which is not a confirmed like.';
  }
  return null;
}

class DetailsBody extends ConsumerStatefulWidget {
  const DetailsBody({super.key, required this.title, this.reason});
  final Title title;
  final String? reason;

  @override
  ConsumerState<DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends ConsumerState<DetailsBody> {
  late Title _title = widget.title;
  WatchProvidersDto? _providers;
  bool get _hasProviders {
    final p = _providers;
    return p != null &&
        (p.link != null ||
            p.stream.isNotEmpty ||
            p.free.isNotEmpty ||
            p.rent.isNotEmpty ||
            p.buy.isNotEmpty);
  }

  bool _providersLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(catalogRepositoryProvider);
    final full = await repo.detailed(widget.title.id);
    if (mounted && full != null) setState(() => _title = full);
    final region = ref.read(currentSettingsProvider).region;
    final p = await repo.watchProviders(widget.title.id, region);
    if (mounted) {
      setState(() {
        _providers = p;
        _providersLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _title;
    final facts = <(String, String)>[
      if (t.titleRomaji != null && t.titleRomaji != t.displayTitle)
        ('Romaji', t.titleRomaji!),
      if (t.titleNative != null) ('Native title', t.titleNative!),
      ('Year', t.year?.toString() ?? 'Unknown'),
      ('Status', _status(t)),
      if (t.kind.isReading)
        ('Chapters', t.chapters?.toString() ?? 'Unknown')
      else if (t.kind != MediaKind.movie)
        ('Episodes', t.episodes?.toString() ?? 'Unknown'),
      if (t.country != null) ('Country', t.country!),
      if (t.score != null) ('Catalog score', '${t.score} / 100'),
    ];
    const muted = TextStyle(fontSize: 14, color: CueColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.reason != null && widget.reason!.isNotEmpty) ...[
          const CueSectionLabel('Why you are seeing this'),
          Text(
            widget.reason!,
            style: const TextStyle(fontSize: 15, color: Color(0xFFC1DEF7)),
          ),
          if (reasonSource(widget.reason!) case final note?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note, style: muted.copyWith(fontSize: 13)),
            ),
        ],
        if (t.synopsis != null) ...[
          const CueSectionLabel('The story'),
          Text(t.synopsis!, style: const TextStyle(fontSize: 15, height: 1.55)),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: CueSpace.md),
            child: Text(
              'No synopsis from the catalog for this title.',
              style: TextStyle(fontSize: 14, color: CueColors.textMuted),
            ),
          ),
        if (t.genres.isNotEmpty || t.tags.isNotEmpty) ...[
          const CueSectionLabel('Genres and themes'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in {...t.genres, ...t.tags.take(8)})
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(CueRadius.chip),
                    border: Border.all(color: CueColors.line),
                  ),
                  child: Text(g, style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ],
        const CueSectionLabel('Details'),
        for (final (k, v) in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 120, child: Text(k, style: muted)),
                Expanded(child: Text(v, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        if (t.seasons.isNotEmpty) ...[
          const CueSectionLabel('Seasons'),
          for (final s in t.seasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                [
                  'Season ${s.number}',
                  if (s.year != null) '${s.year}',
                  s.episodes == null
                      ? 'episodes unknown'
                      : '${s.episodes} episodes',
                ].join(' · '),
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
        // Shown only when a source actually lists services; without a TMDB
        // key there never is one, and an empty section looks broken.
        if (_hasProviders) ...[
          const CueSectionLabel('Where to watch'),
          _WhereToWatch(
            title: t,
            providers: _providers,
            loaded: _providersLoaded,
          ),
        ],
        const SizedBox(height: CueSpace.lg),
        DetailsActions(title: t),
        const SizedBox(height: CueSpace.md),
        Text(
          'Metadata and artwork: ${_source(t)}.',
          style: const TextStyle(fontSize: 12, color: CueColors.textMuted),
        ),
      ],
    );
  }

  static String _status(Title t) => switch (t.status) {
    'finished' => 'Finished',
    'airing' => 'Airing',
    'ongoing' => 'Ongoing',
    _ => 'Unknown',
  };

  static String _source(Title t) {
    if (t.id.startsWith('anilist:')) return 'AniList';
    if (t.id.startsWith('tmdb:')) return 'TMDB';
    if (t.id.startsWith('cinemeta:')) return 'Stremio Cinemeta';
    if (t.id.startsWith('tvmaze:')) return 'TVmaze';
    return 'imported';
  }
}

final _franchiseScopesProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, profileId) {
      ref.watch(libraryVersionProvider);
      return FranchiseExclusionRepository(
        ref.watch(databaseProvider),
        clock: ref.watch(clockProvider),
      ).activeScopes(profileId);
    });

/// Details-only disclosure: never changes the deck's gesture vocabulary.
class DetailsActions extends ConsumerStatefulWidget {
  const DetailsActions({super.key, required this.title, this.onMoreOfTrait});
  final Title title;
  final Future<void> Function(String profileId, Title title, String feature)?
  onMoreOfTrait;

  @override
  ConsumerState<DetailsActions> createState() => _DetailsActionsState();
}

class _DetailsActionsState extends ConsumerState<DetailsActions> {
  bool _expanded = false;
  bool _traitsExpanded = false;
  bool _busy = false;
  String? _feature;
  String? _message;
  FranchiseExclusionChange? _undo;

  FranchiseExclusionRepository get _franchises => FranchiseExclusionRepository(
    ref.read(databaseProvider),
    clock: ref.read(clockProvider),
  );

  Map<String, String> get _traits => {
    for (final trait in [...widget.title.genres, ...widget.title.tags])
      if (trait.trim().isNotEmpty) trait.toLowerCase(): trait.trim(),
  };

  @override
  void didUpdateWidget(DetailsActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title.id != widget.title.id) {
      _feature = null;
      _message = null;
      _undo = null;
    }
  }

  Future<void> _more(String profileId) async {
    final feature = _feature;
    if (feature == null || !_traits.containsKey(feature)) return;
    setState(() => _busy = true);
    try {
      final callback = widget.onMoreOfTrait;
      if (callback != null) {
        await callback(profileId, widget.title, feature);
      } else {
        await ref
            .read(deckControllerProvider.notifier)
            .moreOfTrait(profileId, widget.title, feature);
      }
      if (mounted) {
        setState(
          () => _message =
              'More ${_traits[feature] ?? feature} for this session only. '
              'Your saved preferences are unchanged.',
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _message = 'Could not change this session. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exclude(String profileId, String scope) async {
    final ok = await showCueSheet<bool>(
      context,
      kicker: 'Library preference',
      title: 'Exclude this franchise?',
      body: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CueSpace.md,
        children: [
          Text(
            'Hide titles identified by TMDB as belonging to collection '
            '${scope.substring('tmdb:c'.length)} from this library\'s picks. '
            'This is a saved preference, not just this session. '
            'Your existing library entries stay.',
          ),
          const Text(
            'Only verified members of this TMDB collection are covered. '
            'Other adaptations or titles without collection metadata are not. '
            'You can Undo or restore this franchise from details.',
          ),
          CueSecondaryButton(
            label: 'Cancel',
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CueSecondaryButton(
            label: 'Exclude franchise',
            destructive: true,
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (reliableFranchiseId(widget.title) != scope ||
        ref.read(profileIdProvider).value != profileId) {
      return;
    }
    await _change(
      () => _franchises.exclude(profileId, widget.title),
      'Franchise excluded from this library.',
    );
  }

  Future<void> _change(
    Future<FranchiseExclusionChange> Function() action,
    String message,
  ) async {
    setState(() => _busy = true);
    try {
      final change = await action();
      ref.read(libraryVersionProvider.notifier).bump();
      if (mounted) {
        setState(() {
          _undo = change;
          _message = message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _message = 'Could not save this preference. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undoChange() async {
    final change = _undo;
    if (change == null) return;
    setState(() => _busy = true);
    try {
      final undone = await _franchises.undo(change);
      if (undone) ref.read(libraryVersionProvider.notifier).bump();
      if (mounted) {
        setState(() {
          _undo = null;
          _message = undone
              ? 'Franchise preference undone.'
              : 'A newer preference was kept. Nothing was overwritten.';
        });
      }
    } on Object {
      if (mounted) setState(() => _message = 'Could not undo. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wrongInformation(String profileId) async {
    setState(() => _busy = true);
    try {
      final entry = await ref
          .read(libraryRepositoryProvider)
          .entry(profileId, widget.title.id);
      if (!mounted) return;
      final choice = await showCueSheet<String>(
        context,
        kicker: 'Local correction',
        title: 'Wrong information',
        body: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: CueSpace.md,
          children: [
            const Text(
              'Edit your own status, rating or date, or open your library\'s '
              'Needs review queue to correct an imported title match.',
            ),
            const Text(
              'These local tools cannot repair provider titles, synopsis, '
              'genres, artwork or collection metadata. Cue cannot write to '
              'the provider catalog. No report or title is uploaded.',
            ),
            CueSecondaryButton(
              label: 'Edit my library entry',
              expand: true,
              onPressed: entry == null
                  ? null
                  : () => Navigator.of(ctx).pop('entry'),
            ),
            if (entry == null)
              const Text('This title has no saved library entry to edit.'),
            CueSecondaryButton(
              label: 'Open library review',
              expand: true,
              onPressed: () => Navigator.of(ctx).pop('review'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      // The existing entry editor binds to the active library. Do not route a
      // stale details sheet into a different profile after a library switch.
      if (await ref.read(profileIdProvider.future) != profileId || !mounted) {
        return;
      }
      if (choice == 'entry') {
        await showEntrySheet(context, widget.title);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LibraryContentsPage(profileId: profileId),
          ),
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _message = 'Could not open local corrections. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _action(String label, CueIcons icon, VoidCallback? onPressed) =>
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: CueColors.text,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            CueIcon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    ref.listen(profileIdProvider, (previous, next) {
      if (previous?.value != next.value) {
        setState(() {
          _feature = null;
          _message = null;
          _undo = null;
        });
      }
    });
    final profileId = ref.watch(profileIdProvider).value;
    final scope = reliableFranchiseId(widget.title);
    final scopes = profileId == null
        ? null
        : ref.watch(_franchiseScopesProvider(profileId)).value;
    final excluded = scope != null && (scopes?.contains(scope) ?? false);
    final enabled = !_busy && profileId != null;
    final traits = _traits;
    final feature = traits.containsKey(_feature) ? _feature : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: _action(
            'Refine or correct',
            CueIcons.tune,
            () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded) ...[
          _action(
            'More like this',
            CueIcons.up,
            enabled
                ? () => setState(() => _traitsExpanded = !_traitsExpanded)
                : null,
          ),
          if (_traitsExpanded) ...[
            const Text(
              'Choose a listed genre or theme. This steers this session only, '
              'not your saved taste.',
            ),
            if (traits.isEmpty)
              const Text(
                'No known genres or themes. More like this is unavailable.',
              )
            else ...[
              const SizedBox(height: CueSpace.md),
              DropdownButtonFormField<String>(
                key: ValueKey((
                  profileId,
                  widget.title.id,
                  traits.keys.join('|'),
                )),
                initialValue: feature,
                isExpanded: true,
                icon: const CueIcon(CueIcons.down, size: 20),
                decoration: const InputDecoration(
                  labelText: 'Known genre or theme',
                ),
                items: [
                  for (final trait in traits.entries)
                    DropdownMenuItem(
                      value: trait.key,
                      child: Text(trait.value),
                    ),
                ],
                onChanged: enabled
                    ? (value) => setState(() => _feature = value)
                    : null,
              ),
              const SizedBox(height: CueSpace.md),
              CueSecondaryButton(
                label: feature == null
                    ? 'Choose a trait first'
                    : 'More ${traits[feature]}',
                expand: true,
                onPressed: enabled && feature != null
                    ? () => _more(profileId)
                    : null,
              ),
            ],
          ],
          _action(
            'Wrong information',
            CueIcons.info,
            enabled ? () => _wrongInformation(profileId) : null,
          ),
          _action(
            excluded ? 'Restore franchise' : 'Exclude franchise',
            excluded ? CueIcons.undo : CueIcons.shield,
            enabled && scope != null && scopes != null
                ? () => excluded
                      ? _change(
                          () => _franchises.restore(profileId, scope),
                          'Franchise restored to this library\'s picks.',
                        )
                      : _exclude(profileId, scope)
                : null,
          ),
          if (scope == null)
            const Text(
              'Franchise exclusion unavailable: no verified provider collection. '
              'Cue will not guess from the title name.',
              style: TextStyle(color: CueColors.textMuted, fontSize: 13),
            ),
          if (_message != null)
            Semantics(liveRegion: true, child: Text(_message!)),
          if (_undo != null && _undo!.profileId == profileId)
            _action(
              'Undo franchise preference',
              CueIcons.undo,
              _busy ? null : _undoChange,
            ),
        ],
      ],
    );
  }
}

class _WhereToWatch extends StatelessWidget {
  const _WhereToWatch({
    required this.title,
    required this.providers,
    required this.loaded,
  });

  final Title title;
  final WatchProvidersDto? providers;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 14, color: CueColors.textMuted);
    if (title.kind.isReading) {
      return const Text(
        'Reading platforms vary by region; Cue does not verify them.',
        style: muted,
      );
    }
    if (!loaded) return const Text('Checking…', style: muted);
    final p = providers;
    if (p == null || p.isEmpty) {
      return const Text(
        'Not verified for your region. Cue only shows providers it can confirm.',
        style: muted,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        if (p.stream.isNotEmpty) Text('Stream: ${p.stream.join(', ')}'),
        if (p.free.isNotEmpty) Text('Free: ${p.free.join(', ')}'),
        if (p.rent.isNotEmpty) Text('Rent: ${p.rent.join(', ')}'),
        if (p.buy.isNotEmpty) Text('Buy: ${p.buy.join(', ')}'),
        const Text('Availability data from JustWatch via TMDB.', style: muted),
      ],
    );
  }
}
