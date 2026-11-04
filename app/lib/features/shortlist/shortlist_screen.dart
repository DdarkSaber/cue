import 'dart:math';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/providers.dart';
import '../../app/route_scaffold.dart';
import '../../app/router.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../data/try_now_repository.dart';
import '../../domain/decisions.dart';
import '../../domain/models/decision.dart';
import '../../domain/models/title.dart';
import '../deck/deck_controller.dart';
import '../deck/story_card.dart';
import '../details/details_sheet.dart';
import 'quick_rating_sheet.dart';

final shortlistProvider = FutureProvider.autoDispose<List<Title>>((ref) async {
  ref.watch(libraryVersionProvider);
  ref.watch(decisionVersionProvider);
  final id = await ref.watch(profileIdProvider.future);
  final titles = await ref.read(libraryRepositoryProvider).shortlist(id);
  final intents = await TryNowRepository(ref.read(databaseProvider)).all(id);
  return [
    ...titles.where((t) => intents[t.id]?.active == true),
    ...titles.where((t) => intents[t.id]?.active != true),
  ];
});

final tryNowIntentsProvider =
    FutureProvider.autoDispose<Map<String, TryNowIntent>>((ref) async {
      ref.watch(decisionVersionProvider);
      final id = await ref.watch(profileIdProvider.future);
      return TryNowRepository(ref.read(databaseProvider)).all(id);
    });

/// Will try: the shortlist as cards with an explicit "Next story". Right
/// never silently means next; decisions keep their meanings.
class ShortlistScreen extends ConsumerStatefulWidget {
  const ShortlistScreen({super.key});

  @override
  ConsumerState<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends ConsumerState<ShortlistScreen> {
  int _index = 0;
  String? _message;
  bool _tonightOnly = false;
  String? _undoProfileId;
  String? _undoEventId;

  bool _isCurrentProfile(String profileId) =>
      mounted && ref.read(profileIdProvider).value == profileId;

  void _reportError() {
    if (!mounted) return;
    setState(() {
      _undoProfileId = null;
      _undoEventId = null;
      _message = 'Could not save that change. Please try again.';
    });
  }

  Future<void> _decide(Title t, Decision d) async {
    try {
      final id = await ref.read(profileIdProvider.future);
      await ref
          .read(decisionServiceProvider)
          .decide(id, t, d, context: DeckContext.shortlist);
      if (!_isCurrentProfile(id)) return;
      ref.read(decisionVersionProvider.notifier).bump();
      setState(() {
        _undoProfileId = null;
        _undoEventId = null;
        _message = switch (d) {
          Decision.watched =>
            t.kind.isReading ? 'Marked as read' : 'Marked as watched',
          Decision.notInterested => 'Removed. Restore it in Library.',
          Decision.notNow => 'Hidden for 14 days',
          Decision.willTry => null,
        };
      });
      if (d == Decision.watched && mounted) {
        final rated = await showQuickRatingSheet(context, ref, t);
        if (rated != null && mounted) {
          setState(
            () => _message = 'Rated ${rated.label}. Cue will use it for picks.',
          );
        }
      }
    } on Object {
      _reportError();
    }
  }

  Future<void> _remove(Title t) async {
    try {
      final id = await ref.read(profileIdProvider.future);
      await ref.read(libraryRepositoryProvider).removeFromShortlist(id, t.id);
      if (!_isCurrentProfile(id)) return;
      ref.read(decisionVersionProvider.notifier).bump();
      setState(() {
        _undoProfileId = null;
        _undoEventId = null;
        _message = 'Removed from Will try';
      });
    } on Object {
      _reportError();
    }
  }

  Future<void> _promote(Title t) async {
    try {
      final id = await ref.read(profileIdProvider.future);
      final result = await ref.read(decisionServiceProvider).tryNow(id, t);
      if (!_isCurrentProfile(id)) return;
      ref.read(decisionVersionProvider.notifier).bump();
      if (result.tryNow && !result.repeated) {
        await ref
            .read(deckControllerProvider.notifier)
            .immediateInterest(id, t, result.eventId);
      }
      if (!_isCurrentProfile(id)) return;
      setState(() {
        _undoProfileId = result.tryNow && !result.repeated ? id : null;
        _undoEventId = result.tryNow && !result.repeated
            ? result.eventId
            : null;
        _message = result.repeated
            ? 'Already marked Try now.'
            : 'Saved for tonight and moved to the top of Will try.';
      });
    } on Object {
      _reportError();
    }
  }

  Future<void> _undoPromotion() async {
    final id = _undoProfileId;
    final eventId = _undoEventId;
    if (id == null || eventId == null) return;
    try {
      if (!_isCurrentProfile(id)) return;
      final result = await ref
          .read(decisionServiceProvider)
          .undoTryNow(id, eventId);
      if (!_isCurrentProfile(id)) return;
      if (result == null) {
        setState(() {
          _undoProfileId = null;
          _undoEventId = null;
          _message =
              'This Try now choice changed elsewhere; Undo was not applied.';
        });
        return;
      }
      ref.read(decisionVersionProvider.notifier).bump();
      await ref
          .read(deckControllerProvider.notifier)
          .undoImmediateInterest(id, eventId);
      if (!_isCurrentProfile(id)) return;
      setState(() {
        _undoProfileId = null;
        _undoEventId = null;
        _message = 'Try now undone. The previous saved state was restored.';
      });
    } on Object {
      _reportError();
    }
  }

  /// Chooses one title for tonight: from the Try now markers when there are
  /// any, otherwise from everything saved.
  void _pickTonight(List<Title> titles, Map<String, TryNowIntent> intents) {
    if (titles.isEmpty) return;
    final marked = titles.where((t) => intents[t.id]?.active == true).toList();
    final pool = marked.isEmpty ? titles : marked;
    final pick = pool[Random().nextInt(pool.length)];
    final index = titles.indexWhere((t) => t.id == pick.id);
    setState(() {
      _tonightOnly = false;
      _index = index < 0 ? 0 : index;
      _message = marked.isEmpty
          ? 'Tonight: ${pick.displayTitle}. Picked from your saved titles.'
          : 'Tonight: ${pick.displayTitle}. Picked from your Try now titles.';
    });
  }

  Future<void> _pickFromSaved(List<Title> titles) async {
    try {
      final picked = await showDialog<Title>(
        context: context,
        builder: (context) => _SavedPickDeck(titles: titles),
      );
      if (picked == null || !mounted) return;
      final index = titles.indexWhere((t) => t.id == picked.id);
      setState(() {
        _tonightOnly = false;
        _index = index < 0 ? 0 : index;
        _message = 'Showing ${picked.displayTitle} from your saved picks.';
      });
    } on Object {
      _reportError();
    }
  }

  Future<void> _compare(List<Title> titles) async {
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => _CompareSavedTitles(titles: titles),
      );
    } on Object {
      _reportError();
    }
  }

  Future<void> _savedOptions(
    List<Title> titles,
    Title? current,
    bool currentIsTryNow,
  ) async {
    try {
      final option = await showModalBottomSheet<_SavedOption>(
        context: context,
        showDragHandle: true,
        builder: (context) => _SavedOptionsSheet(
          tonightOnly: _tonightOnly,
          canPick: titles.isNotEmpty,
          canCompare: titles.length > 1,
          canTryNow: current != null && !currentIsTryNow,
        ),
      );
      if (!mounted || option == null) return;
      switch (option) {
        case _SavedOption.toggleTonight:
          setState(() {
            _tonightOnly = !_tonightOnly;
            _index = 0;
          });
        case _SavedOption.pick:
          await _pickFromSaved(titles);
        case _SavedOption.compare:
          await _compare(titles);
        case _SavedOption.tryNow:
          if (current != null) await _promote(current);
      }
    } on Object {
      _reportError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(shortlistProvider);
    return list.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: CueColors.accent),
      ),
      error: (_, _) => const Center(child: Text('Will try could not be read.')),
      data: (titles) {
        final intents = ref.watch(tryNowIntentsProvider).value ?? const {};
        final visible = _tonightOnly
            ? titles.where((t) => intents[t.id]?.active == true).toList()
            : titles;
        if (visible.isEmpty) {
          return RouteScaffold(
            kicker: 'Your shortlist',
            title: _tonightOnly ? "Tonight's picks" : 'Will try',
            children: [
              Text(
                _tonightOnly && titles.isNotEmpty
                    ? 'No titles are marked Try now yet. Open Saved options, choose a title and mark it Try now, and it waits here for tonight.'
                    : 'Nothing saved yet. Swipe right on a story, or tap Will try, and it waits here. Already watched things? Import them in Library so Cue stops suggesting them.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: CueColors.textMuted,
                ),
              ),
              if (titles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: CueSpace.sm),
                  child: Wrap(
                    spacing: CueSpace.sm,
                    runSpacing: CueSpace.sm,
                    children: [
                      if (_tonightOnly)
                        CueSecondaryButton(
                          label: 'Show all saved',
                          onPressed: () => setState(() {
                            _tonightOnly = false;
                            _index = 0;
                          }),
                        ),
                      CueSecondaryButton(
                        label: 'Saved options',
                        onPressed: () => _savedOptions(titles, null, false),
                      ),
                    ],
                  ),
                ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: const TextStyle(color: Color(0xFFC1DEF7)),
                ),
              ],
              const SizedBox(height: CueSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: CuePrimaryButton(
                  label: 'Find a story',
                  onPressed: () => context.go(CueRoutes.forYou),
                ),
              ),
            ],
          );
        }
        final i = _index.clamp(0, visible.length - 1);
        final t = visible[i];
        final desktop = context.cueLayout == CueLayout.desktop;
        final card = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: desktop ? 640 : 700),
          child: StoryCard(
            key: ValueKey(t.id),
            title: t,
            reason: 'On your Will try list.',
            onDetails: () => showDetailsSheet(context, t, showActions: false),
          ),
        );
        return LayoutBuilder(
          builder: (context, box) {
            // Large text or a short window: scroll instead of squeezing the
            // card, so no control is ever clipped.
            final compact =
                MediaQuery.textScalerOf(context).scale(14) > 18 ||
                box.maxHeight < 600;
            final children = <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: CueRouteHeader(
                        kicker: 'Your shortlist',
                        title: 'Will try',
                      ),
                    ),
                    Text(
                      '${i + 1} of ${visible.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CueColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: CueSpace.sm,
                  runSpacing: CueSpace.sm,
                  children: [
                    if (titles.length > 1)
                      CueSecondaryButton(
                        label: 'Pick for tonight',
                        onPressed: () => _pickTonight(titles, intents),
                      ),
                    CueSecondaryButton(
                      label: 'Saved options',
                      onPressed: () => _savedOptions(
                        titles,
                        t,
                        intents[t.id]?.active == true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (compact)
                SizedBox(height: 440, child: Center(child: card))
              else
                Expanded(child: Center(child: card)),
              if (intents[t.id]?.active == true)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    'TRY NOW - priority marker only; not consumed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: CueColors.willTry,
                    ),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC1DEF7),
                      ),
                    ),
                  ),
                ),
              if (_undoEventId != null)
                Center(
                  child: TextButton.icon(
                    onPressed: _undoPromotion,
                    icon: const CueIcon(
                      CueIcons.undo,
                      size: 16,
                      color: CueColors.accent,
                    ),
                    label: const Text('Undo Try now'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        CueSize.minTarget,
                        CueSize.minTarget,
                      ),
                      foregroundColor: CueColors.accent,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: CueSpace.sm,
                runSpacing: CueSpace.sm,
                children: [
                  CueSecondaryButton(
                    label: 'Previous',
                    onPressed: i == 0
                        ? null
                        : () => setState(() => _index = i - 1),
                  ),
                  CueSecondaryButton(
                    label: Decision.watched.labelFor(reading: t.kind.isReading),
                    onPressed: () => _decide(t, Decision.watched),
                  ),
                  CueSecondaryButton(
                    label: 'Remove',
                    onPressed: () => _remove(t),
                  ),
                  CuePrimaryButton(
                    label: 'Next story',
                    onPressed: i >= visible.length - 1
                        ? null
                        : () => setState(() => _index = i + 1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () => _decide(t, Decision.notInterested),
                  icon: const CueIcon(
                    CueIcons.close,
                    size: 14,
                    color: CueColors.notInterested,
                  ),
                  label: const Text('Not interested after all'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      CueSize.minTarget,
                      CueSize.minTarget,
                    ),
                    foregroundColor: CueColors.textMuted,
                  ),
                ),
              ),
            ];
            return Padding(
              padding: EdgeInsets.only(top: desktop ? 80 : 0),
              child: compact
                  ? ListView(
                      padding: const EdgeInsets.only(bottom: CueSpace.xl),
                      children: children,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
            );
          },
        );
      },
    );
  }
}

enum _SavedOption { toggleTonight, pick, compare, tryNow }

class _SavedOptionsSheet extends StatelessWidget {
  const _SavedOptionsSheet({
    required this.tonightOnly,
    required this.canPick,
    required this.canCompare,
    required this.canTryNow,
  });

  final bool tonightOnly;
  final bool canPick;
  final bool canCompare;
  final bool canTryNow;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Saved options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          _option(
            context,
            tonightOnly ? 'Show all saved' : "Tonight's picks",
            _SavedOption.toggleTonight,
          ),
          _option(
            context,
            'Pick from saved',
            _SavedOption.pick,
            enabled: canPick,
          ),
          _option(
            context,
            'Compare two saved titles',
            _SavedOption.compare,
            enabled: canCompare,
          ),
          if (canTryNow)
            _option(context, 'Try now this title', _SavedOption.tryNow),
        ],
      ),
    ),
  );

  Widget _option(
    BuildContext context,
    String label,
    _SavedOption option, {
    bool enabled = true,
  }) => Semantics(
    button: true,
    enabled: enabled,
    child: SizedBox(
      height: CueSize.minTarget,
      child: TextButton(
        onPressed: enabled ? () => Navigator.pop(context, option) : null,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: CueColors.text,
        ),
        child: Text(label),
      ),
    ),
  );
}

class _SavedPickDeck extends StatefulWidget {
  const _SavedPickDeck({required this.titles});

  final List<Title> titles;

  @override
  State<_SavedPickDeck> createState() => _SavedPickDeckState();
}

class _SavedPickDeckState extends State<_SavedPickDeck> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final title = widget.titles[_index];
    final desktop = context.cueLayout == CueLayout.desktop;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const CueRouteHeader(
                kicker: 'Choose from your existing shortlist',
                title: 'Pick from saved',
              ),
              const SizedBox(height: 8),
              Text(
                '${_index + 1} of ${widget.titles.length}',
                style: const TextStyle(color: CueColors.textMuted),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: desktop ? 620 : 580),
                    child: StoryCard(
                      key: ValueKey('saved-pick-${title.id}'),
                      title: title,
                      reason: 'Already saved in Will try.',
                      onDetails: () =>
                          showDetailsSheet(context, title, showActions: false),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  CueSecondaryButton(
                    label: 'Previous',
                    onPressed: _index == 0
                        ? null
                        : () => setState(() => _index--),
                  ),
                  CuePrimaryButton(
                    label: 'Show this saved title',
                    onPressed: () => Navigator.pop(context, title),
                  ),
                  CueSecondaryButton(
                    label: 'Next',
                    onPressed: _index >= widget.titles.length - 1
                        ? null
                        : () => setState(() => _index++),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareSavedTitles extends StatefulWidget {
  const _CompareSavedTitles({required this.titles});

  final List<Title> titles;

  @override
  State<_CompareSavedTitles> createState() => _CompareSavedTitlesState();
}

class _CompareSavedTitlesState extends State<_CompareSavedTitles> {
  late String _first = widget.titles[0].id;
  late String _second = widget.titles[1].id;

  Title get _left => widget.titles.firstWhere((title) => title.id == _first);
  Title get _right => widget.titles.firstWhere((title) => title.id == _second);

  String _known(String? value) =>
      value == null || value.isEmpty ? 'Not listed' : value;

  String _score(Title title) =>
      title.score == null ? 'Not listed' : '${title.score} / 100';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Compare saved titles'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Only catalog facts are shown. Cue does not choose a winner.',
                style: TextStyle(color: CueColors.textMuted),
              ),
              const SizedBox(height: 12),
              _titlePicker(
                label: 'First title',
                value: _first,
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _first = id;
                    if (_second == id) {
                      _second = widget.titles.firstWhere((t) => t.id != id).id;
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              _titlePicker(
                label: 'Second title',
                value: _second,
                onChanged: (id) {
                  if (id != null && id != _first) {
                    setState(() => _second = id);
                  }
                },
              ),
              const SizedBox(height: 16),
              Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FlexColumnWidth(0.82),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                children: [
                  _comparisonRow(
                    'Fact',
                    _left.displayTitle,
                    _right.displayTitle,
                    header: true,
                  ),
                  _comparisonRow(
                    'Genres',
                    _known(
                      _left.genres.isEmpty ? null : _left.genres.join(', '),
                    ),
                    _known(
                      _right.genres.isEmpty ? null : _right.genres.join(', '),
                    ),
                  ),
                  _comparisonRow(
                    'Year',
                    _left.year?.toString() ?? 'Not listed',
                    _right.year?.toString() ?? 'Not listed',
                  ),
                  _comparisonRow(
                    'Length',
                    _left.lengthLabel ?? 'Not listed',
                    _right.lengthLabel ?? 'Not listed',
                  ),
                  _comparisonRow(
                    'Catalog score',
                    _score(_left),
                    _score(_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _titlePicker({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final title in widget.titles)
        DropdownMenuItem(
          value: title.id,
          child: Text(title.displayTitle, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );

  TableRow _comparisonRow(
    String label,
    String left,
    String right, {
    bool header = false,
  }) {
    final style = TextStyle(
      fontWeight: header ? FontWeight.w700 : FontWeight.normal,
      color: header ? CueColors.text : CueColors.textMuted,
    );
    return TableRow(
      children: [
        for (final value in [label, left, right])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
            child: Text(value, style: style),
          ),
      ],
    );
  }
}
