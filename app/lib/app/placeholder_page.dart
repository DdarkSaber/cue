import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'layout.dart';
import 'router.dart';
import 'theme.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Shared scaffold for routes that get their content in later milestones.
/// Empty states say why they are empty and offer one next step.
class RoutePage extends StatelessWidget {
  const RoutePage({
    super.key,
    required this.kicker,
    required this.title,
    required this.body,
    this.actionLabel,
  });

  final String kicker;
  final String title;
  final String body;

  /// Label for the single next step, which returns to the deck.
  final String? actionLabel;

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
        ConstrainedBox(
          // Keep the measure readable on wide screens.
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: CueColors.textMuted,
            ),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: CueSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: PressScale(
              enabled: true,
              child: FilledButton(
                onPressed: () => context.go(CueRoutes.forYou),
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(
                    Size(CueSize.minTarget, CueSize.minTarget),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 20),
                  ),
                  backgroundColor: const WidgetStatePropertyAll(
                    CueColors.actionPrimary,
                  ),
                  foregroundColor: const WidgetStatePropertyAll(
                    CueColors.onActionPrimary,
                  ),
                  shape: WidgetStateProperty.resolveWith(
                    (s) => RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CueRadius.chip),
                      side: s.contains(WidgetState.focused)
                          ? const BorderSide(color: CueColors.accent, width: 2)
                          : BorderSide.none,
                    ),
                  ),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: cueFontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
