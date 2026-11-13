import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sheets.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/catalog_gateway.dart';
import '../../data/db/database.dart';
import '../../domain/models/title.dart';
import '../deck/poster.dart';

/// Match a queued import entry to a catalog title by searching for it.
Future<bool?> showReviewSheet(BuildContext context, SourceObservation o) =>
    showCueSheet<bool>(
      context,
      kicker: 'Needs review',
      title: o.rawTitle,
      body: (_) => _ReviewBody(observation: o),
    );

const reviewFormats = {
  'TV': 'TV',
  'TV_SHORT': 'TV short',
  'MOVIE': 'Movie',
  'SPECIAL': 'Special',
  'OVA': 'OVA',
  'ONA': 'ONA',
  'ONE_SHOT': 'One-shot',
};

/// A catalog search result as a title, enough to draw its row and poster.
Title reviewPreview(CatalogItemDto r) {
  final j = r.json;
  return Title(
    id: 'review:${j['provider']}:${j['providerId']}',
    kind: r.kind,
    titleEn: j['titleEn'] as String?,
    titleRomaji: j['titleRomaji'] as String?,
    titleNative: j['titleNative'] as String?,
    year: (j['year'] as num?)?.toInt(),
    format: j['format'] as String?,
    status: (j['status'] as String?) ?? 'unknown',
    episodes: (j['episodes'] as num?)?.toInt(),
    chapters: (j['chapters'] as num?)?.toInt(),
    posterUrl: j['posterUrl'] as String?,
  );
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({required this.observation});
  final SourceObservation observation;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  late final _query = TextEditingController(text: widget.observation.rawTitle);
  List<CatalogItemDto>? _results;
  String? _message;
  bool _busy = false;
  int _searchEpoch = 0;

  /// Ticked results in tick order; the first keeps the entry's rating.
  final _picked = <CatalogItemDto>[];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final epoch = ++_searchEpoch;
    setState(() {
      _busy = true;
      _message = null;
      _results = null;
      _picked.clear();
    });
    try {
      final r = await ref.read(catalogRepositoryProvider).search(_query.text);
      if (mounted && epoch == _searchEpoch) {
        setState(() {
          _results = r.items;
          _message = r.warning;
        });
      }
    } on Object catch (error) {
      debugPrint('Import review search failed (${error.runtimeType}).');
      if (mounted && epoch == _searchEpoch) {
        setState(() => _message = 'Search could not finish. Try again.');
      }
    } finally {
      if (mounted && epoch == _searchEpoch) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    await _save(
      () => ref.read(importServiceProvider).dismiss(widget.observation),
    );
  }

  Future<void> _link() async {
    if (_picked.isEmpty) return;
    await _save(() async {
      final service = ref.read(importServiceProvider);
      final profileId = await service.observationProfile(widget.observation);
      final ids = await ref.read(catalogRepositoryProvider).upsert(_picked);
      await service.resolve(
        profileId,
        widget.observation,
        ids.first,
        alsoSeen: ids.skip(1),
      );
      await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
    });
  }

  void _toggle(CatalogItemDto r) =>
      setState(() => _picked.contains(r) ? _picked.remove(r) : _picked.add(r));

  /// Results linked to [r] by AniList's season and parent links, walked
  /// both ways, in release order.
  List<CatalogItemDto> _franchise(CatalogItemDto r) {
    final all = _results ?? const <CatalogItemDto>[];
    int? idOf(CatalogItemDto d) => d.json['provider'] == 'anilist'
        ? int.tryParse('${d.json['providerId']}')
        : null;
    final links = <int, Set<int>>{};
    for (final d in all) {
      final id = idOf(d);
      if (id == null) continue;
      for (final c in (d.json['continues'] as List?) ?? const []) {
        if (c is! int) continue;
        (links[id] ??= {}).add(c);
        (links[c] ??= {}).add(id);
      }
    }
    final start = idOf(r);
    if (start == null) return [r];
    final seen = {start};
    final queue = [start];
    while (queue.isNotEmpty) {
      for (final n in links[queue.removeLast()] ?? const <int>{}) {
        if (seen.add(n)) queue.add(n);
      }
    }
    return [
      for (final d in all)
        if (d.kind == r.kind && seen.contains(idOf(d))) d,
    ]..sort(
      (a, b) => ((a.json['year'] as num?) ?? 9999).compareTo(
        (b.json['year'] as num?) ?? 9999,
      ),
    );
  }

  Widget _row(CatalogItemDto r) {
    final t = reviewPreview(r);
    final ticked = _picked.contains(r);
    final meta = [
      r.kind.label,
      ?reviewFormats[t.format],
      if (t.year != null) '${t.year}',
      ?t.lengthLabel,
    ].join(' · ');
    return Semantics(
      checked: ticked,
      label: '${t.displayTitle}, $meta',
      excludeSemantics: true,
      child: InkWell(
        onTap: _busy ? null : () => _toggle(r),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            spacing: CueSpace.md,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 40,
                  height: 56,
                  child: Poster(title: t, alignment: Alignment.center),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CueColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: ticked,
                onChanged: _busy ? null : (_) => _toggle(r),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      ref.read(libraryVersionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      debugPrint('Import review save failed (${error.runtimeType}).');
      if (mounted) {
        setState(() => _message = 'Could not save your review. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _resultList() {
    final results = _results ?? const <CatalogItemDto>[];
    if (results.isEmpty) return const [];
    final first = _picked.isEmpty ? null : _picked.first;
    final family = first == null ? const <CatalogItemDto>[] : _franchise(first);
    final missing = family.where((d) => !_picked.contains(d)).toList();
    return [
      if (missing.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _picked.addAll(missing)),
            style: TextButton.styleFrom(
              minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
            ),
            child: Text('Select all ${family.length} in this series'),
          ),
        ),
      for (final r in results) _row(r),
      const SizedBox(height: CueSpace.md),
      SizedBox(
        width: double.infinity,
        child: CuePrimaryButton(
          label: switch (_picked.length) {
            0 => 'Tick the matching title',
            1 => 'Link this title',
            final n => 'Link $n titles',
          },
          onPressed: _busy || _picked.isEmpty ? null : _link,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tick the matching title. Watched several seasons? Tick each, or use Select all.',
          style: TextStyle(fontSize: 14, color: CueColors.textMuted),
        ),
        const SizedBox(height: CueSpace.md),
        Row(
          spacing: CueSpace.sm,
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                maxLength: 200,
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (_) => _search(),
              ),
            ),
            CueSecondaryButton(
              label: 'Search',
              onPressed: _busy ? null : _search,
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(color: CueColors.accent),
        const SizedBox(height: CueSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : _dismiss,
            style: TextButton.styleFrom(
              minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
              foregroundColor: CueColors.textMuted,
            ),
            child: const Text('This is not in my history'),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              style: const TextStyle(color: CueColors.notInterested),
            ),
          ),
        if (_results != null && _results!.isEmpty && _message == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No catalog matches. Try another spelling.'),
          ),
        ..._resultList(),
      ],
    );
  }
}
