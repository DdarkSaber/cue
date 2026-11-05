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
    // Notification bars match the deck's dark glass toast: dark surface,
    // rounded, floating, accent action, and a sideways swipe dismisses them.
    // Opaque surfaceHigh keeps text at well over 4.5:1 whatever sits behind.
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      backgroundColor: CueColors.surfaceHigh,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: CueColors.line),
      ),
      contentTextStyle: TextStyle(
        fontFamily: cueFontFamily,
        color: CueColors.text,
        fontSize: 14,
        height: 1.4,
      ),
      actionTextColor: CueColors.accent,
      disabledActionTextColor: CueColors.textMuted,
      closeIconColor: CueColors.textMuted,
      insetPadding: EdgeInsets.fromLTRB(
        CueSpace.lg,
        CueSpace.sm,
        CueSpace.lg,
        CueSpace.md,
      ),
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
