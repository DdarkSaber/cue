import 'package:flutter/material.dart';

import 'tokens.dart';

const cueFontFamily = 'DM Sans';

ThemeData buildCueTheme() {
  const scheme = ColorScheme.dark(
    surface: CueColors.surface,
    onSurface: CueColors.text,
    onSurfaceVariant: CueColors.textMuted,
    primary: CueColors.actionPrimary,
    onPrimary: CueColors.onActionPrimary,
    secondary: CueColors.accent,
    onSecondary: CueColors.onActionPrimary,
    outline: CueColors.line,
    outlineVariant: CueColors.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: cueFontFamily,
    scaffoldBackgroundColor: CueColors.bg,
    canvasColor: CueColors.bg,
    focusColor: CueColors.accent.withValues(alpha: 0.16),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    // Size overrides first, then apply the family and colours so every style
    // (including the ambient DefaultTextStyle) keeps DM Sans.
    textTheme: base.textTheme
        .copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.5,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.5,
          ),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            fontSize: 12,
            letterSpacing: 0,
          ),
        )
        .apply(
          fontFamily: cueFontFamily,
          bodyColor: CueColors.text,
          displayColor: CueColors.text,
        ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: CueColors.surfaceHigh,
        borderRadius: BorderRadius.all(Radius.circular(CueRadius.chip)),
      ),
      textStyle: TextStyle(
        fontFamily: cueFontFamily,
        color: CueColors.text,
        fontSize: 12,
      ),
    ),
  );
}
