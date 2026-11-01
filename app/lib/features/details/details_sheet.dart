import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/catalog_gateway.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/title.dart';

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
        if (widget.reason != null && widget.reason!.isNotEmpty)
          Text(
            widget.reason!,
            style: const TextStyle(fontSize: 15, color: Color(0xFFC1DEF7)),
          ),
        if (t.synopsis != null) ...[
          const CueSectionLabel('The story'),
          Text(t.synopsis!, style: const TextStyle(fontSize: 15, height: 1.55)),
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
