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
    final items = [
      for (final a in actionOrder)
        Flexible(
          child: _ActionItem(
            decision: a,
            label: a.labelFor(reading: reading),
            desktop: desktop,
            keyHint: keyHints[a],
            onPressed: onAction == null ? null : () => onAction!(a),
            onLongPress: onAction == null || onLongAction == null
                ? null
                : () => onLongAction!(a),
          ),
        ),
    ];
    return Row(
      mainAxisAlignment: desktop
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: desktop
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      spacing: desktop ? 34 : CueSpace.xs,
      children: items,
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.decision,
    required this.label,
    required this.desktop,
    required this.onPressed,
    this.onLongPress,
    this.keyHint,
  });

  final Decision decision;
  final String label;
  final bool desktop;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? keyHint;

  @override
  Widget build(BuildContext context) {
    final primary = decision == Decision.willTry;
    final style = DecisionStyle.of(decision);
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
    final hint = keyHint;
    return desktop && hint != null
        ? Tooltip(message: '$label ($hint)', child: button)
        : button;
  }
}
