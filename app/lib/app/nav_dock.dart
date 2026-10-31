import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'icons.dart';
import 'tokens.dart';
import 'widgets.dart';

class NavDestination {
  const NavDestination(this.label, this.icon);
  final String label;
  final CueIcons icon;
}

const navDestinations = [
  NavDestination('For you', CueIcons.cue),
  NavDestination('Will try', CueIcons.save),
  NavDestination('Library', CueIcons.library),
  NavDestination('Settings', CueIcons.settings),
];

/// Floating glass nav: a dock at the bottom on phones, a pill at the top
/// centre on desktop (section 4.5).
class NavDock extends StatelessWidget {
  const NavDock({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.horizontal,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Desktop pill: icon and label side by side.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    // Outer radius = item radius + padding (22 + 5 desktop, 17 + 7 phone).
    final radius = BorderRadius.circular(horizontal ? 27 : 24);
    return Semantics(
      container: true,
      label: 'Main navigation',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: const Color(0x1EFFFFFF)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xAB2C333B), Color(0xE6151A21)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal ? 7 : 9,
                  vertical: horizontal ? 5 : 7,
                ),
                child: Row(
                  mainAxisSize: horizontal
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  spacing: 6,
                  children: [
                    for (var i = 0; i < navDestinations.length; i++)
                      _wrap(
                        _NavItem(
                          destination: navDestinations[i],
                          active: i == currentIndex,
                          horizontal: horizontal,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wrap(Widget child) => horizontal ? child : Expanded(child: child);
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.active,
    required this.horizontal,
    required this.onTap,
  });

  final NavDestination destination;
  final bool active;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : CueColors.textMuted;
    final icon = CueIcon(
      destination.icon,
      size: horizontal ? 18 : 19,
      color: color,
    );
    final label = Text(
      destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: color, height: 1.2),
    );
    return PressScale(
      enabled: true,
      child: MergeSemantics(
        child: Semantics(
          selected: active,
          child: TextButton(
            onPressed: onTap,
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(
                Size(horizontal ? 84 : CueSize.minTarget, CueSize.minTarget),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              ),
              backgroundColor: WidgetStatePropertyAll(
                active ? const Color(0x12FFFFFF) : Colors.transparent,
              ),
              overlayColor: const WidgetStatePropertyAll(Color(0x0AFFFFFF)),
              shape: WidgetStateProperty.resolveWith(
                (s) => RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(horizontal ? 22 : 17),
                  side: s.contains(WidgetState.focused)
                      ? const BorderSide(color: CueColors.accent, width: 2)
                      : BorderSide.none,
                ),
              ),
            ),
            child: horizontal
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [icon, label],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [icon, label],
                  ),
          ),
        ),
      ),
    );
  }
}
