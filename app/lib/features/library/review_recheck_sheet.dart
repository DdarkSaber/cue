import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sheets.dart';
import '../../app/tokens.dart';
import '../../data/catalog_gateway.dart';
import '../../data/db/database.dart';
import '../../imports/import_service.dart';
import '../deck/poster.dart';
import 'review_sheet.dart';

/// Lets Cue check the whole review queue again, then walks through the
/// suggestions it found one at a time. With [confirmOnly] it skips the
/// check and goes straight to the suggestions already stored.
Future<void> showRecheckSheet(
  BuildContext context, {
  bool confirmOnly = false,
}) => showCueSheet<void>(
  context,
  kicker: 'Needs review',
  title: confirmOnly ? 'Confirm suggestions' : 'Check all again',
  body: (_) => _RecheckBody(confirmOnly: confirmOnly),
);

enum _Phase { ready, checking, summary, confirming, finished }

class _RecheckBody extends ConsumerStatefulWidget {
  const _RecheckBody({required this.confirmOnly});
  final bool confirmOnly;

  @override
  ConsumerState<_RecheckBody> createState() => _RecheckBodyState();
}

class _RecheckBodyState extends ConsumerState<_RecheckBody> {
  var _phase = _Phase.ready;
  var _done = 0;
  var _total = 0;
  var _stop = false;
  var _busy = false;
  RecheckSummary? _summary;
  String? _message;

  /// Suggestions still to answer, and how many were linked in this sheet.
  var _suggestions = <SourceObservation>[];
  var _at = 0;
  var _linked = 0;

  @override
  void initState() {
    super.initState();
    if (widget.confirmOnly) _startConfirming();
  }

  @override
  void dispose() {
    _stop = true;
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _phase = _Phase.checking;
      _message = null;
      _stop = false;
    });
    try {
      final profileId = await ref.read(profileIdProvider.future);
      final summary = await ref
          .read(importServiceProvider)
          .recheckReview(
            profileId,
            cancelled: () => _stop,
            onProgress: (done, total) {
              if (mounted) {
                setState(() {
                  _done = done;
                  _total = total;
                });
              }
            },
          );
      ref.read(libraryVersionProvider.notifier).bump();
      if (mounted) {
        setState(() {
          _summary = summary;
          _phase = _Phase.summary;
        });
      }
    } on Object catch (error) {
      debugPrint('Review re-check failed (${error.runtimeType}).');
      ref.read(libraryVersionProvider.notifier).bump();
      if (mounted) {
        setState(() {
          _phase = _Phase.ready;
          _message = 'The check could not finish. What it matched is saved; try again.';
        });
      }
    }
  }

  Future<void> _startConfirming() async {
    final profileId = await ref.read(profileIdProvider.future);
    final queue = await ref.read(importServiceProvider).reviewQueue(profileId);
    if (!mounted) return;
    setState(() {
      _suggestions = [
        for (final o in queue)
          if (o.candidateJson != null) o,
      ];
      _at = 0;
      _phase = _suggestions.isEmpty ? _Phase.finished : _Phase.confirming;
    });
  }

  Future<void> _answer(
    Future<void> Function(SourceObservation o) action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action(_suggestions[_at]);
      if (mounted) {
        setState(() {
          _at++;
          if (_at >= _suggestions.length) _phase = _Phase.finished;
        });
      }
    } on Object catch (error) {
      debugPrint('Suggestion answer failed (${error.runtimeType}).');
      if (mounted) setState(() => _message = 'Could not save that. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _yes(SourceObservation o) async {
    final service = ref.read(importServiceProvider);
    final profileId = await service.observationProfile(o);
    final ids = await ref.read(catalogRepositoryProvider).upsert([_dto(o)]);
    await service.resolve(profileId, o, ids.first);
    _linked++;
  }

  Future<void> _acceptAll() => _answer((_) async {
    final service = ref.read(importServiceProvider);
    final profileId = await ref.read(profileIdProvider.future);
    final rest = _suggestions.skip(_at).toList();
    _linked += await service.acceptAllSimilar(profileId, rest);
    _at = _suggestions.length - 1;
  });

  Future<void> _close() async {
    if (_linked > 0) {
      final profileId = await ref.read(profileIdProvider.future);
      await ref.read(libraryRepositoryProvider).recomputeWeights(profileId);
    }
    ref.read(libraryVersionProvider.notifier).bump();
    if (mounted) Navigator.of(context).pop();
  }

  static CatalogItemDto _dto(SourceObservation o) => CatalogItemDto(
    Map<String, dynamic>.from(jsonDecode(o.candidateJson!) as Map),
  );

  static const _muted = TextStyle(fontSize: 14, color: CueColors.textMuted);

  Widget _wide(Widget child) => SizedBox(width: double.infinity, child: child);

  List<Widget> _ready() => [
    const Text(
      'Cue looks up every title in this list again, more thoroughly than the import did. A title it is sure of is linked on its own. A close one is kept as a suggestion for you to confirm. It can take a few minutes; you can stop at any time and keep what was found.',
      style: _muted,
    ),
    const SizedBox(height: CueSpace.lg),
    _wide(CuePrimaryButton(label: 'Start checking', onPressed: _check)),
  ];

  List<Widget> _checking() => [
    Text(
      _total == 0 ? 'Getting ready' : 'Checked $_done of $_total',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: CueSpace.sm),
    LinearProgressIndicator(
      value: _total == 0 ? null : _done / _total,
      color: CueColors.accent,
    ),
    const SizedBox(height: CueSpace.sm),
    const Text(
      'Keep this open while it runs. Lookups are paced so the catalogs are not flooded.',
      style: _muted,
    ),
    const SizedBox(height: CueSpace.lg),
    CueSecondaryButton(
      label: _stop ? 'Stopping' : 'Stop and keep what was found',
      onPressed: _stop ? null : () => setState(() => _stop = true),
    ),
  ];

  List<Widget> _summaryView() {
    final s = _summary!;
    return [
      Text(
        s.matched == 0
            ? 'No title could be linked on its own'
            : 'Linked ${s.matched} on its own',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: CueSpace.sm),
      if (s.suggested > 0)
        Text(
          '${s.suggested} have a suggestion waiting for your yes or no.',
          style: _muted,
        ),
      if (s.unchecked > 0)
        Text(
          '${s.unchecked} could not be looked up just now. Check again later for those.',
          style: _muted,
        ),
      Text(
        s.remaining == 0
            ? 'Nothing is left to review.'
            : '${s.remaining} are still in the list.',
        style: _muted,
      ),
      const SizedBox(height: CueSpace.lg),
      if (s.suggested > 0) ...[
        _wide(
          CuePrimaryButton(
            label: 'Confirm suggestions one by one',
            onPressed: _startConfirming,
          ),
        ),
        const SizedBox(height: CueSpace.sm),
      ],
      _wide(CueSecondaryButton(label: 'Done', onPressed: _close)),
    ];
  }

  List<Widget> _confirming() {
    final o = _suggestions[_at];
    final dto = _dto(o);
    final t = reviewPreview(dto);
    final meta = [
      dto.kind.label,
      ?reviewFormats[t.format],
      if (t.year != null) '${t.year}',
      ?t.lengthLabel,
    ].join(' · ');
    return [
      Text('${_at + 1} of ${_suggestions.length}', style: _muted),
      const SizedBox(height: CueSpace.sm),
      Text(
        o.rawTitle,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: CueSpace.sm),
      const Text('Is it this one?', style: _muted),
      const SizedBox(height: CueSpace.sm),
      Semantics(
        label: 'Suggested: ${t.displayTitle}, $meta',
        excludeSemantics: true,
        child: Row(
          spacing: CueSpace.md,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 102,
                child: Poster(title: t, alignment: Alignment.center),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(meta, style: _muted),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: CueSpace.lg),
      _wide(
        CuePrimaryButton(
          label: 'Yes, link it',
          onPressed: _busy ? null : () => _answer(_yes),
        ),
      ),
      const SizedBox(height: CueSpace.sm),
      Row(
        spacing: CueSpace.sm,
        children: [
          Expanded(
            child: CueSecondaryButton(
              label: 'No',
              onPressed: _busy
                  ? null
                  : () => _answer(
                      ref.read(importServiceProvider).rejectSuggestion,
                    ),
            ),
          ),
          Expanded(
            child: CueSecondaryButton(
              label: 'Skip',
              onPressed: _busy ? null : () => _answer((_) async {}),
            ),
          ),
        ],
      ),
      if (_suggestions.length - _at > 1)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : _acceptAll,
            style: TextButton.styleFrom(
              minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
            ),
            child: Text('Yes to all ${_suggestions.length - _at} remaining'),
          ),
        ),
    ];
  }

  List<Widget> _finished() => [
    Text(
      _suggestions.isEmpty
          ? 'No suggestions are waiting'
          : 'All suggestions answered',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: CueSpace.sm),
    Text(
      _linked == 0
          ? 'Titles left in the list can be matched by hand.'
          : 'Linked $_linked. Titles left in the list can be matched by hand.',
      style: _muted,
    ),
    const SizedBox(height: CueSpace.lg),
    _wide(CuePrimaryButton(label: 'Done', onPressed: _close)),
  ];

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (_, _) {
      _stop = true;
      // Closed by a swipe or the back button: taste still has to catch up
      // with what was linked here.
      final linked = _linked;
      _linked = 0;
      final library = ref.read(libraryRepositoryProvider);
      final version = ref.read(libraryVersionProvider.notifier);
      final profile = ref.read(profileIdProvider.future);
      unawaited(() async {
        try {
          if (linked > 0) await library.recomputeWeights(await profile);
        } finally {
          version.bump();
        }
      }());
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...switch (_phase) {
          _Phase.ready => _ready(),
          _Phase.checking => _checking(),
          _Phase.summary => _summaryView(),
          _Phase.confirming => _confirming(),
          _Phase.finished => _finished(),
        },
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: CueSpace.sm),
            child: Text(_message!, style: _muted),
          ),
      ],
    ),
  );
}
