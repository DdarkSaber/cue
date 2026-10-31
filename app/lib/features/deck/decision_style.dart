import 'package:flutter/material.dart';

import '../../app/icons.dart';
import '../../app/tokens.dart';
import '../../domain/models/decision.dart';

/// Colour, icon and stamp treatment per decision. Colour never carries the
/// meaning alone: every use also shows the label and icon.
class DecisionStyle {
  const DecisionStyle({
    required this.color,
    required this.icon,
    required this.stampBackground,
    required this.stampText,
  });

  final Color color;
  final CueIcons icon;
  final Color stampBackground;
  final Color stampText;

  static DecisionStyle of(Decision d) => switch (d) {
    Decision.willTry => const DecisionStyle(
      color: CueColors.willTry,
      icon: CueIcons.arrow,
      stampBackground: Color(0xE61A3B31),
      stampText: Color(0xFFE3FFF3),
    ),
    Decision.notNow => const DecisionStyle(
      color: CueColors.notNow,
      icon: CueIcons.down,
      stampBackground: Color(0xE6443B27),
      stampText: Color(0xFFFFF1D2),
    ),
    Decision.watched => const DecisionStyle(
      color: CueColors.watched,
      icon: CueIcons.check,
      stampBackground: Color(0xE6223447),
      stampText: Color(0xFFDCECFF),
    ),
    Decision.notInterested => const DecisionStyle(
      color: CueColors.notInterested,
      icon: CueIcons.close,
      stampBackground: Color(0xE6402330),
      stampText: Color(0xFFFFE0E8),
    ),
  };
}
