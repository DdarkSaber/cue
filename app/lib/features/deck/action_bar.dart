import 'package:flutter/material.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';
import '../../domain/models/decision.dart';
import 'decision_style.dart';

/// On-screen order of the four decisions (fixed, whatever the swipe map).
const actionOrder = [
  Decision.notInterested,
  Decision.notNow,
  Decision.watched,
  Decision.willTry,
];

class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.onAction,
    this.onLongAction,
    this.keyHints = const {},
    this.reading = false,
  });

  /// Long press on a button (Not now offers how long to hide).
  final ValueChanged<Decision>? onLongAction;

  /// The key for each action on desktop, shown as a tooltip ("→").
  final Map<Decision, String> keyHints;

  /// Null while there is no card to act on.
  final ValueChanged<Decision>? onAction;

  /// Reading titles say "Read it".
  final bool reading;

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    return _bar(desktop, [
      for (final a in actionOrder)
        _ActionItem(
          label: a.labelFor(reading: reading),
          style: DecisionStyle.of(a),
          primary: a == Decision.willTry,
          hint: a == Decision.notNow
              ? 'Long press to choose how long to hide it'
              : null,
          desktop: desktop,
          keyHint: keyHints[a],
          onPressed: onAction == null ? null : () => onAction!(a),
          onLongPress: onAction == null || onLongAction == null
              ? null
              : () => onLongAction!(a),
        ),
    ]);
  }
}

/// One button in a [ChoiceBar].
class ChoiceBarItem {
  const ChoiceBarItem({required this.choice, this.onPressed, this.keyHint});

  final SwipeChoice choice;

  /// Null while there is no card to act on.
  final VoidCallback? onPressed;

  /// The key for the choice on desktop, shown as a tooltip ("→").
  final String? keyHint;
}

/// The action bar's buttons for any other swipe deck, in the given order.
class ChoiceBar extends StatelessWidget {
  const ChoiceBar({super.key, required this.items});

  final List<ChoiceBarItem> items;

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    return _bar(desktop, [
      for (final item in items)
        _ActionItem(
          label: item.choice.label,
          style: item.choice.style,
          primary: item.choice.primary,
          desktop: desktop,
          keyHint: item.keyHint,
          onPressed: item.onPressed,
        ),
    ]);
  }
}

Widget _bar(bool desktop, List<Widget> items) => Row(
  mainAxisAlignment: desktop
      ? MainAxisAlignment.center
      : MainAxisAlignment.spaceBetween,
  crossAxisAlignment: desktop
      ? CrossAxisAlignment.center
      : CrossAxisAlignment.start,
  spacing: desktop ? 34 : CueSpace.xs,
  children: [for (final item in items) Flexible(child: item)],
);

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.label,
    required this.style,
    required this.primary,
    required this.desktop,
    required this.onPressed,
    this.onLongPress,
    this.keyHint,
    this.hint,
  });

  final String label;
  final DecisionStyle style;
  final bool primary;

  /// Screen-reader hint while enabled (Not now's long press).
  final String? hint;
  final bool desktop;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? keyHint;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final circle = desktop && !primary ? 42.0 : 48.0;
    final icon = Container(
      width: circle,
      height: circle,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary ? CueColors.actionPrimary : const Color(0x07FFFFFF),
        border: Border.all(
          color: primary ? CueColors.actionPrimary : const Color(0x26FFFFFF),
        ),
      ),
      child: Center(
        child: CueIcon(
          style.icon,
          size: 22,
          color: primary ? CueColors.onActionPrimary : style.color,
        ),
      ),
    );
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFFC5CFDB),
        height: 1.2,
      ),
    );
    final button = PressScale(
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: TextButton(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size(CueSize.minTarget, CueSize.minTarget),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStateProperty.resolveWith(
              (s) => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CueRadius.chip),
                side: s.contains(WidgetState.focused)
                    ? const BorderSide(color: CueColors.accent, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
          child: desktop
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 9,
                  children: [
                    icon,
                    Flexible(child: text),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [icon, text],
                ),
        ),
      ),
    );
    final key = keyHint;
    final described = Semantics(hint: enabled ? hint : null, child: button);
    return desktop && key != null
        ? Tooltip(message: '$label ($key)', child: described)
        : described;
  }
}
