import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import 'action_bar.dart';
import 'card_stack.dart';
import 'deck_providers.dart';
import 'mood_rail.dart';

/// For you: the home screen. Header, mood rail, card, four actions.
class DeckScreen extends ConsumerWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final canUndo = ref.watch(canUndoProvider);
    final hasCard = ref.watch(hasCardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(desktop: desktop, showUndo: !desktop && canUndo),
        SizedBox(height: desktop ? 4 : 2),
        const MoodRail(),
        SizedBox(height: desktop ? 16 : 10),
        const Expanded(child: Center(child: CardStack())),
        SizedBox(height: desktop ? 22 : 14),
        ActionBar(onAction: hasCard ? (_) {} : null),
        if (desktop) ...[
          const SizedBox(height: CueSpace.sm),
          Center(
            child: TextButton.icon(
              onPressed: canUndo ? () {} : null,
              icon: const CueIcon(CueIcons.undo, size: 16),
              label: const Text('Undo'),
              style: TextButton.styleFrom(
                minimumSize: const Size(CueSize.minTarget, CueSize.minTarget),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.desktop, required this.showUndo});

  final bool desktop;
  final bool showUndo;

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
              onPressed: () {},
            ),
          // Filters arrive in M3; the control is present but inactive.
          const CueRoundButton(
            icon: CueIcons.tune,
            tooltip: 'Filters and mood',
            onPressed: null,
          ),
        ],
      ),
    );
  }
}
