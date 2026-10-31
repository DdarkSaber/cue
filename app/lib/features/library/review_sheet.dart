import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/catalog_gateway.dart';
import '../../data/db/database.dart';

/// Match a queued import entry to a catalog title by searching for it.
Future<bool?> showReviewSheet(BuildContext context, SourceObservation o) =>
    showCueSheet<bool>(
      context,
      kicker: 'Needs review',
      title: o.rawTitle,
      body: (_) => _ReviewBody(observation: o),
    );

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
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r = await ref.read(catalogGatewayProvider).search(_query.text);
      if (mounted) setState(() => _results = r);
    } on CatalogUnavailable {
      if (mounted) {
        setState(() => _message = 'Offline. Search needs a connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    await ref.read(importServiceProvider).dismiss(widget.observation);
    ref.read(libraryVersionProvider.notifier).bump();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pick(CatalogItemDto dto) async {
    final ids = await ref.read(catalogRepositoryProvider).upsert([dto]);
    final profileId = await ref.read(profileIdProvider.future);
    await ref
        .read(importServiceProvider)
        .resolve(profileId, widget.observation, ids.first);
    await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
    ref.read(libraryVersionProvider.notifier).bump();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pick the matching title. Only your choice links this entry; nothing is guessed.',
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
            onPressed: _dismiss,
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
        if (_results != null && _results!.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No catalog matches. Try another spelling.'),
          ),
        for (final r in _results ?? const <CatalogItemDto>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              (r.json['titleEn'] ??
                      r.json['titleRomaji'] ??
                      r.json['titleNative'] ??
                      '')
                  .toString(),
            ),
            subtitle: Text(
              [
                r.kind.label,
                if (r.json['year'] != null) '${r.json['year']}',
                if (r.json['titleRomaji'] != null && r.json['titleEn'] != null)
                  '${r.json['titleRomaji']}',
              ].join(' · '),
              style: const TextStyle(fontSize: 13, color: CueColors.textMuted),
            ),
            trailing: CueSecondaryButton(
              label: 'This one',
              onPressed: () => _pick(r),
            ),
          ),
      ],
    );
  }
}
