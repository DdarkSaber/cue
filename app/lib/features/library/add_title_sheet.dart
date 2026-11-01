import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sheets.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/catalog_gateway.dart';
import '../../domain/models/decision.dart';

/// "Add a title": find something you have seen (or want to) and mark it,
/// without waiting for it to turn up in the deck.
class AddTitleButton extends StatelessWidget {
  const AddTitleButton({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: CueSecondaryButton(
      label: 'Add a title',
      onPressed: () => showCueSheet<void>(
        context,
        kicker: 'Library',
        title: 'Add a title',
        body: (_) => const _AddTitleBody(),
      ),
    ),
  );
}

class _AddTitleBody extends ConsumerStatefulWidget {
  const _AddTitleBody();

  @override
  ConsumerState<_AddTitleBody> createState() => _AddTitleBodyState();
}

class _AddTitleBodyState extends ConsumerState<_AddTitleBody> {
  final _query = TextEditingController();
  List<CatalogItemDto>? _results;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r = await ref.read(catalogGatewayProvider).search(q);
      if (mounted) setState(() => _results = r);
    } on CatalogUnavailable {
      if (mounted) {
        setState(() => _message = 'Offline. Search needs a connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mark(CatalogItemDto dto, Decision d) async {
    final catalog = ref.read(catalogRepositoryProvider);
    final ids = await catalog.upsert([dto]);
    final title = await catalog.titleById(ids.first);
    if (title == null) return;
    final profileId = await ref.read(profileIdProvider.future);
    await ref.read(decisionServiceProvider).decide(profileId, title, d);
    ref.read(decisionVersionProvider.notifier).bump();
    ref.read(libraryVersionProvider.notifier).bump();
    if (!mounted) return;
    setState(
      () => _message =
          '${title.displayTitle}: ${d.labelFor(reading: title.kind.isReading)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: CueSpace.sm,
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                autofocus: true,
                maxLength: 200,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'Title, in any language',
                ),
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
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: const TextStyle(color: CueColors.textMuted),
              ),
            ),
          ),
        if (_results != null && _results!.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No matches. Try another spelling or name.'),
          ),
        for (final r in _results ?? const <CatalogItemDto>[])
          Padding(
            padding: const EdgeInsets.only(top: CueSpace.sm),
            child: Row(
              spacing: CueSpace.sm,
              children: [
                Expanded(
                  child: Text(
                    [
                      r.json['titleEn'] ?? r.json['titleRomaji'] ?? '',
                      if (r.json['year'] != null) '(${r.json['year']})',
                    ].join(' '),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                TextButton(
                  onPressed: () => _mark(r, Decision.watched),
                  child: const Text('Seen'),
                ),
                TextButton(
                  onPressed: () => _mark(r, Decision.willTry),
                  child: const Text('Will try'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
