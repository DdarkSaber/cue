import 'package:flutter/material.dart';

import '../../app/icons.dart';
import '../../app/layout.dart';
import '../../app/tokens.dart';
import '../../app/widgets.dart';

/// The four fixed decisions, in on-screen order.
enum DeckAction {
  notInterested('Not interested', CueIcons.close, CueColors.notInterested),
  notNow('Not now', CueIcons.down, CueColors.notNow),
  watched('Watched', CueIcons.check, CueColors.watched),
  willTry('Will try', CueIcons.arrow, CueColors.onActionPrimary);

  const DeckAction(this.label, this.icon, this.color);
  final String label;
  final CueIcons icon;
  final Color color;
}

class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.onAction});

  /// Null while there is no card to act on.
  final ValueChanged<DeckAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final items = [
      for (final a in DeckAction.values)
        Flexible(
          child: _ActionItem(
            action: a,
            desktop: desktop,
            onPressed: onAction == null ? null : () => onAction!(a),
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
    required this.action,
    required this.desktop,
    required this.onPressed,
  });

  final DeckAction action;
  final bool desktop;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = action == DeckAction.willTry;
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
      child: Center(child: CueIcon(action.icon, size: 22, color: action.color)),
    );
    final label = Text(
      action.label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFFC5CFDB),
        height: 1.2,
      ),
    );
    return PressScale(
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: TextButton(
          onPressed: onPressed,
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
                    Flexible(child: label),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [icon, label],
                ),
        ),
      ),
    );
  }
}
