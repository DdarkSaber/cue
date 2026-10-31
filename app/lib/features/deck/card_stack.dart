import 'package:flutter/material.dart';

import '../../app/layout.dart';
import '../../app/tokens.dart';

/// The deck area. In M0 it shows the card-shaped loading state (no blocking
/// welcome screen) with the next card peeking below.
class CardStack extends StatelessWidget {
  const CardStack({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = context.cueLayout == CueLayout.desktop;
    final radius = desktop ? CueRadius.cardDesktop : CueRadius.cardPhone;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: desktop ? 760 : 790),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Next card: scaled to 0.972 and nudged down.
          Transform.translate(
            offset: const Offset(0, 7),
            child: Transform.scale(
              scale: CueMotion.nextCardScale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2027),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
              ),
            ),
          ),
          _LoadingCard(radius: radius, desktop: desktop),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.radius, required this.desktop});

  final double radius;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading recommendations',
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          boxShadow: const [
            // Softer than the prototype so the next card's edge stays visible.
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 48,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            // Title block sits in the lower third on phones, left half on desktop.
            final width = desktop ? c.maxWidth * 0.43 : c.maxWidth - 48;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                desktop ? 56 : 24,
                24,
                24,
                desktop ? 70 : 22,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: width,
                  child: const Column(
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
                ),
              ),
            );
          },
        ),
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
