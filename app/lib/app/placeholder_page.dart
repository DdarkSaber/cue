import 'package:flutter/material.dart';

import 'layout.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Shared scaffold for routes that get their content in later milestones.
class RoutePage extends StatelessWidget {
  const RoutePage({
    super.key,
    required this.kicker,
    required this.title,
    required this.body,
  });

  final String kicker;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 4 : 10,
        // Leave room for the desktop nav pill floating at the top.
        desktop ? 96 : CueSpace.lg,
        desktop ? 4 : 10,
        CueSpace.xl,
      ),
      children: [
        CueRouteHeader(kicker: kicker, title: title),
        const SizedBox(height: CueSpace.xl),
        Text(
          body,
          style: const TextStyle(fontSize: 15, color: CueColors.textMuted),
        ),
      ],
    );
  }
}
