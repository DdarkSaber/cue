import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../app/tokens.dart';

/// Card-shaped loading state (no blocking welcome screen), and the same
/// shape for empty and offline messages.
class LoadingCard extends StatelessWidget {
  const LoadingCard({
    super.key,
    this.message,
    this.action,
    this.loadingLabel = 'Loading recommendations',
  });

  /// When set, the card explains why it is empty instead of loading.
  final String? message;
  final Widget? action;

  /// Read out while [message] is null.
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final radius = desktop ? CueRadius.cardDesktop : CueRadius.cardPhone;
    return Semantics(
      label: message ?? loadingLabel,
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 48,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 56 : 24,
            24,
            24,
            desktop ? 70 : 22,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: message == null
                ? const _Bars()
                : ExcludeSemantics(
                    excluding: false,
                    // Scrolls only when large text outgrows a short card.
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message!,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: CueColors.text,
                              ),
                            ),
                            if (action != null) ...[
                              const SizedBox(height: CueSpace.lg),
                              action!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) {
    return const FractionallySizedBox(
      widthFactor: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bar(widthFactor: 0.32, height: 10),
          SizedBox(height: 14),
          _Bar(widthFactor: 0.78, height: 30),
          SizedBox(height: 10),
          _Bar(widthFactor: 0.5, height: 30),
          SizedBox(height: 16),
          _Bar(widthFactor: 0.66, height: 12),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
