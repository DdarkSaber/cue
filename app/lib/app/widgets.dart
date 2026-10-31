import 'package:flutter/material.dart';

import 'icons.dart';
import 'tokens.dart';

/// Focus ring used by every Cue control: a 2 px ice-blue outline.
const _focusSide = BorderSide(color: CueColors.accent, width: 2);

WidgetStateProperty<BorderSide?> _side(BorderSide rest) =>
    WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.focused) ? _focusSide : rest,
    );

/// Round, quiet icon button (header filter, undo, card info).
/// Visual size can be smaller than 48, but the hit target never is.
class CueRoundButton extends StatelessWidget {
  const CueRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.visualSize = 44,
    this.iconSize = 20,
    this.badge = false,
  });

  final CueIcons icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double visualSize;
  final double iconSize;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: CueSize.minTarget,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                OutlinedButton(
                  onPressed: onPressed,
                  style: ButtonStyle(
                    fixedSize: WidgetStatePropertyAll(Size.square(visualSize)),
                    minimumSize: WidgetStatePropertyAll(
                      Size.square(visualSize),
                    ),
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const WidgetStatePropertyAll(CircleBorder()),
                    backgroundColor: const WidgetStatePropertyAll(
                      Color(0x09FFFFFF),
                    ),
                    side: _side(const BorderSide(color: Color(0x20FFFFFF))),
                    foregroundColor: WidgetStatePropertyAll(
                      enabled ? CueColors.text : CueColors.textMuted,
                    ),
                    overlayColor: const WidgetStatePropertyAll(
                      Color(0x0FFFFFFF),
                    ),
                  ),
                  child: CueIcon(icon, size: iconSize),
                ),
                if (badge)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: CueColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: CueColors.bg, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "cue" wordmark: the C/play mark plus the lowercase name.
class CueWordmark extends StatelessWidget {
  const CueWordmark({super.key, this.fontSize = 33});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cue',
      header: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CueIcon(
            CueIcons.cue,
            size: fontSize * 0.78,
            strokeWidth: 2,
            color: CueColors.text,
          ),
          const SizedBox(width: 7),
          Text(
            'cue',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -fontSize * 0.058,
              height: 1,
              color: CueColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Route header used by Will try, Library and Settings.
class CueRouteHeader extends StatelessWidget {
  const CueRouteHeader({super.key, required this.kicker, required this.title});

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: const TextStyle(fontSize: 13, color: Color(0xFFA7B5C5)),
        ),
        const SizedBox(height: CueSpace.xs),
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.1,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}
