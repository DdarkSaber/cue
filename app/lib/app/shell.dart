import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'layout.dart';
import 'nav_dock.dart';

/// Frame around every destination: content width, safe areas and the nav.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final layout = context.cueLayout;
    final desktop = layout == CueLayout.desktop;
    final nav = NavDock(
      currentIndex: navigationShell.currentIndex,
      onSelect: _select,
      horizontal: desktop,
    );

    final Widget body;
    if (desktop) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280, maxHeight: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 24, 48, 45),
          child: Stack(
            children: [
              Positioned.fill(child: navigationShell),
              Align(alignment: Alignment.topCenter, child: nav),
            ],
          ),
        ),
      );
    } else {
      body = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: layout == CueLayout.tablet ? 460 : 480,
          maxHeight: 1100,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child: Column(
            children: [
              Expanded(child: navigationShell),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: nav,
              ),
            ],
          ),
        ),
      );
    }

    // System Back on a secondary destination returns to For you instead of
    // closing the app; Back on For you behaves normally.
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: SafeArea(child: Center(child: body)),
      ),
    );
  }
}
