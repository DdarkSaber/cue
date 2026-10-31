import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/icons.dart';
import '../../app/theme.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/quick_mood.dart';
import 'deck_controller.dart';

/// Horizontal chip rail. One tap re-deals for that mood; no sheet.
class MoodRail extends ConsumerWidget {
  const MoodRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(deckFiltersProvider.select((f) => f.mood));
    return Semantics(
      container: true,
      label: 'Quick mood',
      // A plain scrolling row, not a lazy list: every chip stays built so
      // screen readers and keyboard focus can reach all six.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          spacing: CueSpace.sm,
          children: [
            for (final mood in QuickMood.values)
              MoodPill(
                mood: mood,
                selected: mood == selected,
                onTap: () =>
                    ref.read(deckFiltersProvider.notifier).setMood(mood),
              ),
          ],
        ),
      ),
    );
  }
}

class MoodPill extends StatelessWidget {
  const MoodPill({
    super.key,
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final QuickMood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final revisit = mood == QuickMood.revisit;
    final Color bg, fg, border;
    if (selected) {
      bg = revisit ? CueColors.accent : CueColors.actionPrimary;
      fg = revisit ? const Color(0xFF0C1A28) : CueColors.onActionPrimary;
      border = bg;
    } else {
      bg = const Color(0x08FFFFFF);
      fg = revisit ? CueColors.accent : const Color(0xFFC5CFDB);
      border = revisit ? const Color(0x38A9D7FF) : const Color(0x22FFFFFF);
    }
    return PressScale(
      enabled: true,
      child: MergeSemantics(
        child: Semantics(
          selected: selected,
          child: Center(
            child: OutlinedButton(
              onPressed: onTap,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 15),
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: const WidgetStatePropertyAll(StadiumBorder()),
                backgroundColor: WidgetStatePropertyAll(bg),
                foregroundColor: WidgetStatePropertyAll(fg),
                overlayColor: const WidgetStatePropertyAll(Color(0x0FFFFFFF)),
                side: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.focused)
                      ? const BorderSide(color: CueColors.accent, width: 2)
                      : BorderSide(color: border),
                ),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: cueFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (revisit) ...[
                    CueIcon(CueIcons.repeat, size: 16, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(mood.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
