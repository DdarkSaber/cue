import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'deck_controller.dart';
import 'loading_card.dart';
import 'mood_rail.dart';
import 'mood_read_chip.dart';
import 'swipe_tutorial.dart';
import 'poster.dart';
import 'swipe_deck.dart';
import 'toast.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeShowSwipeTutorial(context, ref),
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _say(String text, {Decision? decision}) => setState(
    () => _toast = ToastMessage(text, decision: decision, id: ++_toastId),
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
    );
    await ref.read(deckControllerProvider.notifier).decide(decision);
  }

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

  Future<void> _openDetails() async {
    final top = ref.read(deckControllerProvider).top;
    if (top == null) return;
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

    ref.listen(deckControllerProvider.select((s) => s.error), (_, err) {
      if (err != null) {
        _say(err);
        ref.read(deckControllerProvider.notifier).clearError();
      }
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
        enabled: !_sheetOpen,
        reduceMotion: settings.reduceMotion,
        haptics: settings.haptics,
      );
    } else if (deck.loading) {
      cardArea = const LoadingCard();
    } else {
      cardArea = LoadingCard(
        message: deck.emptyMessage ?? 'No stories right now.',
        action: _EmptyAction(
          hasFilters: filters.activeCount > 0,
          revisit: filters.isRevisit,
        ),
      );
    }

    final showInvite =
        deck.sessionDecisions >= 6 && !settings.inviteDismissed && top != null;

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
              if (deck.notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    deck.notice!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CueColors.textMuted,
                    ),
                  ),
                ),
              if (showInvite) const _ImportInvite(),
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
                reading: top?.title.kind.isReading ?? false,
              ),
              if (desktop) ...[
                const SizedBox(height: CueSpace.sm),
                Center(
                  child: TextButton.icon(
                    onPressed: deck.canUndo ? _undo : null,
                    icon: const CueIcon(CueIcons.undo, size: 16),
                    label: const Text('Undo'),
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
  const _EmptyAction({required this.hasFilters, required this.revisit});
  final bool hasFilters;
  final bool revisit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (revisit) {
      return CuePrimaryButton(
        label: 'Open Library',
        onPressed: () => context.go(CueRoutes.library),
      );
    }
    if (hasFilters) {
      return CuePrimaryButton(
        label: 'Reset filters',
        onPressed: () => ref.read(deckFiltersProvider.notifier).reset(),
      );
    }
    return CuePrimaryButton(
      label: 'Try again',
      onPressed: () => ref.read(deckControllerProvider.notifier).redeal(),
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
