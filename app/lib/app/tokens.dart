import 'dart:ui' show Color;

/// Cinema design tokens.
/// Values here are the single source for colour, spacing, shape and motion.
abstract final class CueColors {
  static const bg = Color(0xFF080A0D);
  static const surface = Color(0xFF171B20);
  static const surfaceHigh = Color(0xFF1F262E);
  static const line = Color(0x1FFFFFFF);
  static const text = Color(0xFFF7F8FA);
  static const textMuted = Color(0xFFB7C0CC);
  static const actionPrimary = Color(0xFFF3F5F8);
  static const onActionPrimary = Color(0xFF10151D);
  static const accent = Color(0xFFA9D7FF);
  static const willTry = Color(0xFFB6DFCF);
  static const notNow = Color(0xFFE2D4B8);
  static const watched = Color(0xFFC6D8ED);
  static const notInterested = Color(0xFFE8C7D0);

  /// Toasts use surfaceHigh at 95% opacity.
  static const toast = Color(0xF21F262E);
}

abstract final class CueSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class CueRadius {
  static const double cardPhone = 17;
  static const double cardDesktop = 26;
  static const double sheet = 26;
  static const double sheetMax = 28;
  static const double chip = 10;
  static const double pill = 999;
}

abstract final class CueSize {
  /// Minimum interactive target.
  static const double minTarget = 48;

  /// Width at which the desktop split layout starts.
  static const double desktopBreakpoint = 1000;

  /// Width below which the phone layout applies (prototype breakpoint).
  static const double phoneBreakpoint = 700;
}

/// Gesture and motion numbers. Distances in logical px.
abstract final class CueMotion {
  static const double touchSlop = 8;
  static const double previewDistance = 18;
  static const double axisDominance = 1.35;
  static const double axisLock = 40;
  static const double commitFraction = 0.25;
  static const double commitMin = 72;
  static const double commitMax = 120;
  static const double flickVelocity = 900;
  static const double flickMinDistance = 32;
  static const double maxRotationDeg = 8;
  static const Duration springMin = Duration(milliseconds: 220);
  static const Duration springMax = Duration(milliseconds: 320);
  static const Duration exitMin = Duration(milliseconds: 180);
  static const Duration exitMax = Duration(milliseconds: 240);
  static const double nextCardScale = 0.972;
  static const double downRubberBandAfter = 60;
  static const double backEdgeInset = 24;

  /// Commit distance for a card dimension, clamped to [commitMin, commitMax].
  static double commitDistance(double cardDimension) =>
      (cardDimension * commitFraction).clamp(commitMin, commitMax);
}
