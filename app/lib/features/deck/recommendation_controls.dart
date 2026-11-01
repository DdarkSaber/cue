import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../domain/models/decision.dart';
import 'deck_controller.dart';
import 'not_now_options.dart';

final localRecommendationMeasuresProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      ref.watch(decisionVersionProvider);
      ref.watch(libraryVersionProvider);
      ref.watch(recommendationMeasuresVersionProvider);
      final id = await ref.watch(profileIdProvider.future);
      return ref.read(recommendationRepositoryProvider).read(id);
    });

Future<void> showRecommendationControls(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RecommendationControls(),
    );

class RecommendationControls extends ConsumerStatefulWidget {
  const RecommendationControls({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<RecommendationControls> createState() =>
      _RecommendationControlsState();
}

class _RecommendationControlsState
    extends ConsumerState<RecommendationControls> {
  double? _draft;
  bool _busy = false;
  String? _message;
  bool _savedHere = false;

  Future<void> _run(Future<void> Function() work, String message) async {
    setState(() => _busy = true);
    try {
      await work();
      if (mounted) setState(() => _message = message);
    } on Object {
      if (mounted) {
        setState(
          () =>
              _message = 'Could not update recommendation controls. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deckControllerProvider);
    final deck = ref.read(deckControllerProvider.notifier);
    final measures = ref.watch(localRecommendationMeasuresProvider);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('For this session', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Session tools use your current deck filters, not un-applied drafts. More / Less, traits and exploration stay in memory: reset after 45 minutes away, a new day, changing library or Reset session. Ratings and long-term taste stay unchanged.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy || state.top == null
              ? null
              : () => _run(
                  () async {
                    final result = await deck.tryNow(
                      expectedTitleId: state.top!.title.id,
                    );
                    if (result == null) throw StateError('card_changed');
                    _savedHere = true;
                  },
                  'Try now saved to Tonight\u2019s picks. Interest, not a rating.',
                ),
          child: const Text('Try now'),
        ),
        const Text(
          'Or double-tap a card. Keyboard: Shift + Enter. Four swipes are unchanged.',
        ),
        TextButton(
          onPressed: _busy || state.top == null
              ? null
              : () => _run(() async {
                  final titleId = state.top!.title.id;
                  final picked = await showNotNowOptions(context);
                  if (picked == null) return;
                  final result = await deck.decide(
                    Decision.notNow,
                    defer: picked.delay,
                    notNowReason: picked.reason,
                    expectedTitleId: titleId,
                  );
                  if (result == null) throw StateError('card_changed');
                  _savedHere = true;
                }, 'Delay saved. Context affects only this session.'),
          child: const Text('Bring back later / context'),
        ),
        if (_savedHere && state.canUndo)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await deck.undo();
                    _savedHere = false;
                  }, 'Last choice undone.'),
            child: const Text('Undo last choice'),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy || state.top == null
                  ? null
                  : () => _run(
                      () => deck.temporaryFeedback(true),
                      'More like this, only for this session.',
                    ),
              child: const Text('More like this'),
            ),
            OutlinedButton(
              onPressed: _busy || state.top == null
                  ? null
                  : () => _run(
                      () => deck.temporaryFeedback(false),
                      'Less like this, only for this session.',
                    ),
              child: const Text('Less like this'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Familiar  \u2194  Explore'),
        Slider(
          value: _draft ?? deck.exploration,
          divisions: 10,
          semanticFormatterCallback: (v) =>
              'Exploration preference level ${(v * 10).round()} of 10, only this session',
          onChanged: _busy ? null : (v) => setState(() => _draft = v),
          onChangeEnd: _busy
              ? null
              : (v) => _run(() async {
                  await deck.setExploration(v);
                  _draft = null;
                }, 'Exploration updated. Your hard filters still apply.'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  deck.repeatedNotNow ? deck.differentDirection : deck.surprise,
                  'A different mix for the next five choices, within your hard filters.',
                ),
          child: Text(
            deck.repeatedNotNow ? 'Different direction' : 'Surprise me',
          ),
        ),
        if (deck.surpriseRemaining > 0)
          Text(
            'Exploration boost: ${deck.surpriseRemaining} choices remaining. Your familiar preference returns afterwards.',
          ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () async {
                    await deck.resetSession();
                    _draft = null;
                  },
                  'Temporary preferences reset; library ratings and mood learning kept.',
                ),
          child: const Text('Reset session'),
        ),
        const Divider(),
        const Text(
          'Why this card?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          state.top?.reason ??
              'No eligible card. Change explicit filters or retry the catalog.',
        ),
        const SizedBox(height: 12),
        Text(
          '${deck.poolSize} cached candidates in the selected formats, before history and hard filters. This is a growing sample, not every title in every catalog.',
        ),
        if (deck.clusters.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Interest themes, separate from today\u2019s mood:'),
          for (final cluster in deck.clusters)
            Text(cluster.features.take(4).join(' \u00b7 ')),
        ],
        const Divider(),
        const Text(
          'Local recommendation measures',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const Text(
          'Device-only proxies, not an accuracy score. Never sent with technical diagnostics or sync.',
        ),
        measures.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Local measures could not be read.'),
          data: (m) {
            final picks = m['picks'] as int? ?? 0;
            final answers = m['followupAnswers'] as int? ?? 0;
            return Text(
              'Choices per Will try: ${picks == 0 ? "not enough data" : ((m["choicesToPick"] as int? ?? 0) / picks).toStringAsFixed(1)}\n'
              'Later enjoyment: ${answers == 0 ? "not enough explicit answers" : "${m["enjoyed"] ?? 0}/$answers"}\n'
              'Visible cards: ${m["presented"] ?? 0}; repeats within 24 hours: ${m["repeated"] ?? 0}\n'
              'Formats shown: ${(m["kinds"] as List? ?? []).length}; detected hard-filter/history leaks: ${m["constraintLeaks"] ?? 0}.',
            );
          },
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final id = await ref.read(profileIdProvider.future);
                  await ref
                      .read(recommendationRepositoryProvider)
                      .clearMeasures(id);
                  ref.invalidate(localRecommendationMeasuresProvider);
                }, 'Local measures cleared; dismissed follow-ups kept.'),
          child: const Text('Clear local recommendation measures'),
        ),
        if (_message != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              style: const TextStyle(color: CueColors.textMuted),
            ),
          ),
        if (!widget.embedded)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
      ],
    );
    if (widget.embedded) return content;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: content,
        ),
      ),
    );
  }
}
