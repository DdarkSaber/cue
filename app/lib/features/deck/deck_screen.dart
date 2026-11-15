import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart'
    show BooleanExpressionOperators, StringExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/decision.dart';
import '../details/details_sheet.dart';
import '../filters/filter_sheet.dart';
import 'action_bar.dart';
import '../../domain/models/deck_filters.dart';
import 'candidate_sources.dart';
import 'deck_controller.dart';
import 'deck_fallback.dart';
import 'loading_card.dart';
import 'mood_rail.dart';
import 'mood_read_chip.dart';
import '../imports/import_job.dart';
import '../onboarding/taste_quickstart.dart';
import 'swipe_tutorial.dart';
import 'poster.dart';
import 'swipe_deck.dart';
import 'toast.dart';
import '../../domain/recommendation_context.dart';
import 'not_now_options.dart';

/// For you: the home screen. Header, mood rail, card, four actions.
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  final _deckKey = GlobalKey<SwipeDeckState>();
  final _focus = FocusNode(debugLabel: 'deck');
  ToastMessage? _toast;
  int _toastId = 0;
  bool _sheetOpen = false;

  /// Filters the person chose to keep after seeing a relaxed card.
  DeckFilters? _keptFilters;

  /// Set by the Not now long-press menu for the next Not now.
  Duration? _pendingDefer;
  NotNowReason? _pendingReason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await maybeOfferTasteQuickstart(context, ref);
      if (mounted) await maybeShowSwipeTutorial(context, ref);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _say(String text, {Decision? decision, VoidCallback? onUndo}) =>
      setState(
        () => _toast = ToastMessage(
          text,
          decision: decision,
          id: ++_toastId,
          onUndo: onUndo,
        ),
      );

  /// Every way in (swipe, button, key, screen reader) lands here.
  Future<void> _onSwipe(SwipeDirection dir) async {
    final settings = ref.read(currentSettingsProvider);
    final decision = settings.swipeMap.decisionFor(dir);
    final top = ref.read(deckControllerProvider).top;
    if (top == null) return;
    // Confirm at once; if storing fails the card returns with a message.
    _say(
      toastText(decision, reading: top.title.kind.isReading),
      decision: decision,
      onUndo: () => unawaited(_undo()),
    );
    final defer = decision == Decision.notNow ? _pendingDefer : null;
    final reason = decision == Decision.notNow ? _pendingReason : null;
    _pendingDefer = null;
    _pendingReason = null;
    await ref
        .read(deckControllerProvider.notifier)
        .decide(decision, defer: defer, notNowReason: reason);
  }

  /// Long press on Not now: choose how long to hide the title.
  Future<void> _longAct(Decision d) async {
    if (d != Decision.notNow) return _act(d);
    final picked = await showNotNowOptions(context);
    if (picked == null || !mounted) return;
    _pendingDefer = picked.delay;
    _pendingReason = picked.reason;
    _act(Decision.notNow);
  }

  static const _arrows = {
    SwipeDirection.right: '→',
    SwipeDirection.left: '←',
    SwipeDirection.up: '↑',
    SwipeDirection.down: '↓',
  };

  void _act(Decision d) {
    final dir = ref.read(currentSettingsProvider).swipeMap.directionFor(d);
    _deckKey.currentState?.swipe(dir);
  }

  Future<void> _undo() async {
    final undone = await ref.read(deckControllerProvider.notifier).undo();
    if (!mounted || undone == null) return;
    final d = undone.decision;
    if (d != null) {
      final from = ref.read(currentSettingsProvider).swipeMap.directionFor(d);
      await _deckKey.currentState?.bringBack(from);
    }
    if (mounted) _say('Undone');
  }

  Future<void> _tryNow(String titleId) async {
    if (_sheetOpen) return;
    final result = await ref
        .read(deckControllerProvider.notifier)
        .tryNow(expectedTitleId: titleId);
    if (!mounted || result == null) return;
    _say(
      result.repeated
          ? 'Already in Tonight\u2019s picks'
          : 'Try now saved. Undo is available.',
    );
  }

  Future<void> _openDetails() async {
    final top = ref.read(deckControllerProvider).top;
    if (top == null) return;
    ref.read(deckControllerProvider.notifier).signalDetailsOpened(top.title.id);
    setState(() => _sheetOpen = true);
    final picked = await showDetailsSheet(
      context,
      top.title,
      reason: top.reason,
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (picked != null) _act(picked);
  }

  Future<void> _openFilters() async {
    setState(() => _sheetOpen = true);
    await showFilterSheet(context);
    if (mounted) setState(() => _sheetOpen = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || _sheetOpen) return KeyEventResult.ignored;
    // Arrow keys only act when focus is on the deck, not in a text field.
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isShiftPressed) {
      final top = ref.read(deckControllerProvider).top;
      if (top == null) return KeyEventResult.ignored;
      unawaited(_tryNow(top.title.id));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.keyU ||
        (e.logicalKey == LogicalKeyboardKey.keyZ &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed))) {
      if (!ref.read(deckControllerProvider).canUndo) {
        return KeyEventResult.ignored;
      }
      unawaited(_undo());
      return KeyEventResult.handled;
    }
    final dir = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowLeft => SwipeDirection.left,
      LogicalKeyboardKey.arrowRight => SwipeDirection.right,
      LogicalKeyboardKey.arrowUp => SwipeDirection.up,
      LogicalKeyboardKey.arrowDown => SwipeDirection.down,
      _ => null,
    };
    if (dir == null) return KeyEventResult.ignored;
    if (ref.read(deckControllerProvider).top == null) {
      return KeyEventResult.ignored;
    }
    _deckKey.currentState?.swipe(dir);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final deck = ref.watch(deckControllerProvider);
    final settings = ref.watch(currentSettingsProvider);
    final filters = ref.watch(deckFiltersProvider);
    final top = deck.top;
    if (top != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            (ModalRoute.of(context)?.isCurrent ?? true) &&
            ref.read(deckControllerProvider).top?.title.id == top.title.id) {
          unawaited(
            ref.read(deckControllerProvider.notifier).recordVisible(top.title),
          );
        }
      });
    }

    ref.listen(deckControllerProvider.select((s) => s.error), (_, err) {
      if (err != null) {
        _say(err);
        ref.read(deckControllerProvider.notifier).clearError();
      }
    });
    ref.listen(deckControllerProvider.select((s) => s.directionSuggestion), (
      _,
      offer,
    ) {
      if (!offer) return;
      ref.read(deckControllerProvider.notifier).dismissDirectionSuggestion();
      if (_sheetOpen || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Not the right mix? Try a different direction.'),
          action: SnackBarAction(
            label: 'Shift mix',
            onPressed: () async {
              try {
                await ref
                    .read(deckControllerProvider.notifier)
                    .differentDirection();
              } on Object {
                if (mounted) _say('Could not shift the mix. Try again.');
              }
            },
          ),
        ),
      );
    });

    // Decode the next two posters while this one is on screen.
    if (deck.cards.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          predecodePosters(
            context,
            ref,
            deck.cards.skip(1).take(2).map((c) => c.title),
          );
        }
      });
    }

    final Widget cardArea;
    if (top != null) {
      cardArea = SwipeDeck(
        key: _deckKey,
        cards: deck.cards,
        swipeMap: settings.swipeMap,
        onSwipe: _onSwipe,
        onDetails: _openDetails,
        onPosterHold: ref
            .read(deckControllerProvider.notifier)
            .signalPosterHeld,
        onTryNow: (id) => unawaited(_tryNow(id)),
        enabled: !_sheetOpen,
        reduceMotion: settings.reduceMotion,
        haptics: settings.haptics,
      );
    } else if (deck.loading || deck.refreshing || deck.emptyMessage == null) {
      // Still looking: a card-shaped placeholder, never a dead end.
      cardArea = const LoadingCard();
    } else {
      // Only when no eligible title is reachable (e.g. offline, empty cache).
      cardArea = LoadingCard(
        message: deck.emptyMessage,
        action: _EmptyAction(revisit: filters.isRevisit),
      );
    }
    final relaxation = deck.topRelaxation;
    final showRelaxed =
        relaxation != null &&
        relaxation.misses.isNotEmpty &&
        _keptFilters != filters;

    // Only for people who have not brought a list yet.
    final showInvite =
        deck.sessionDecisions >= 6 &&
        !settings.inviteDismissed &&
        top != null &&
        ref.watch(_hasImportedProvider).value == false;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      // Keyboard routing only; it must not merge the screen into one node.
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                desktop: desktop,
                showUndo: !desktop && deck.canUndo,
                onUndo: _undo,
                onFilters: _openFilters,
                filterBadge: filters.activeCount > 0,
              ),
              SizedBox(height: desktop ? 4 : 2),
              const MoodRail(),
              const MoodReadChip(),
              const ImportJobBanner(),
              const TasteHint(),
              const AiPicksPrompt(),
              if (deck.notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Catalog and mood status'),
                        content: SingleChildScrollView(
                          child: Text(deck.notice!),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    icon: const CueIcon(CueIcons.info, size: 16),
                    label: const Text(
                      'Catalog / AI status · Details',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              if (showInvite) const _ImportInvite(),
              if (showRelaxed)
                _RelaxedFilterChip(
                  relaxation: relaxation,
                  onKeep: () => setState(() => _keptFilters = filters),
                  onClear: () => ref
                      .read(deckFiltersProvider.notifier)
                      .apply(relaxation.clearedFrom(filters)),
                ),
              SizedBox(height: desktop ? 16 : 10),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: desktop ? 760 : 790),
                    child: cardArea,
                  ),
                ),
              ),
              SizedBox(height: desktop ? 22 : 14),
              ActionBar(
                onAction: top == null || _sheetOpen ? null : _act,
                onLongAction: _longAct,
                keyHints: {
                  for (final d in Decision.values)
                    d:
                        _arrows[ref
                            .watch(currentSettingsProvider)
                            .swipeMap
                            .directionFor(d)]!,
                },
                reading: top?.title.kind.isReading ?? false,
              ),
              if (desktop) ...[
                const SizedBox(height: CueSpace.sm),
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    spacing: 18,
                    children: [
                      TextButton.icon(
                        onPressed: deck.canUndo ? _undo : null,
                        icon: const CueIcon(CueIcons.undo, size: 16),
                        label: const Text('Undo (U)'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            CueSize.minTarget,
                            CueSize.minTarget,
                          ),
                          foregroundColor: const Color(0xFFC1CEDD),
                          disabledForegroundColor: const Color(0x66C1CEDD),
                          textStyle: const TextStyle(
                            fontFamily: cueFontFamily,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Text(
                        'Keys: arrows choose · Shift+Enter Try now · '
                        'U undo · click card for details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9FADBD),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: desktop ? 120 : 100,
            child: Center(child: DeckToast(message: _toast)),
          ),
        ],
      ),
    );
  }
}

class _EmptyAction extends ConsumerWidget {
  const _EmptyAction({required this.revisit});
  final bool revisit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (revisit) {
      return CuePrimaryButton(
        label: 'Open Library',
        onPressed: () => context.go(CueRoutes.library),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CuePrimaryButton(
          label: 'Try again',
          onPressed: () => ref.read(deckControllerProvider.notifier).redeal(),
        ),
        TextButton(
          onPressed: () => context.go(CueRoutes.willTry),
          child: const Text('Choose from saved'),
        ),
      ],
    );
  }
}

class _ImportInvite extends ConsumerWidget {
  const _ImportInvite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          color: const Color(0x0AA9D7FF),
          borderRadius: BorderRadius.circular(CueRadius.chip),
          border: Border.all(color: const Color(0x26A9D7FF)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Already have a list? Bring it with you.',
                style: TextStyle(fontSize: 13, color: Color(0xFFCFE6FB)),
              ),
            ),
            TextButton(
              onPressed: () => context.go(CueRoutes.importer),
              style: TextButton.styleFrom(
                minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
                foregroundColor: CueColors.accent,
              ),
              child: const Text('Import'),
            ),
            CueRoundButton(
              icon: CueIcons.close,
              tooltip: 'Dismiss',
              visualSize: 32,
              iconSize: 14,
              onPressed: () => ref
                  .read(settingsProvider.notifier)
                  .change((s) => s.copyWith(inviteDismissed: true)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline note for a card outside the person's explicit filters, with a
/// one-tap choice to keep or clear the filter that excluded everything.
class _RelaxedFilterChip extends StatelessWidget {
  const _RelaxedFilterChip({
    required this.relaxation,
    required this.onKeep,
    required this.onClear,
  });

  final DeckRelaxation relaxation;
  final VoidCallback onKeep;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final longer = relaxation.rung == DeckRung.longer;
    final text = longer
        ? 'Longer than requested: no short matches left'
        : outsideLabel(relaxation.misses);
    final plural = relaxation.misses.length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        container: true,
        label: text,
        child: Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            color: const Color(0x0AA9D7FF),
            borderRadius: BorderRadius.circular(CueRadius.chip),
            border: Border.all(color: const Color(0x26A9D7FF)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ExcludeSemantics(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFCFE6FB),
                  ),
                ),
              ),
              TextButton(
                onPressed: onKeep,
                style: TextButton.styleFrom(
                  minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
                  foregroundColor: const Color(0xFFC1CEDD),
                ),
                child: Text(plural ? 'Keep filters' : 'Keep filter'),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
                  foregroundColor: CueColors.accent,
                ),
                child: Text(plural ? 'Clear filters' : 'Clear filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.desktop,
    required this.showUndo,
    required this.onUndo,
    required this.onFilters,
    required this.filterBadge,
  });

  final bool desktop;
  final bool showUndo;
  final VoidCallback onUndo;
  final VoidCallback onFilters;
  final bool filterBadge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: desktop ? 54 : CueSize.minTarget,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: desktop ? 4 : 10),
            child: CueWordmark(fontSize: desktop ? 38 : 31),
          ),
          const Spacer(),
          if (showUndo)
            CueRoundButton(
              icon: CueIcons.undo,
              tooltip: 'Undo last swipe',
              iconSize: 18,
              onPressed: onUndo,
            ),
          CueRoundButton(
            icon: CueIcons.tune,
            tooltip: 'Filters and mood',
            badge: filterBadge,
            onPressed: onFilters,
          ),
        ],
      ),
    );
  }
}

/// Whether this library already holds anything from an import.
final _hasImportedProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(libraryVersionProvider);
  final profile = await ref.watch(profileIdProvider.future);
  final db = ref.watch(databaseProvider);
  final row =
      await (db.select(db.userTitles)
            ..where(
              (u) => u.profileId.equals(profile) & u.source.like('import:%'),
            )
            ..limit(1))
          .getSingleOrNull();
  return row != null;
});
