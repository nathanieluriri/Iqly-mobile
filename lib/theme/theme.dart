import 'package:flutter/material.dart';

import 'tokens.g.dart';

export 'tokens.g.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: IqFonts.jakarta,
  );
  return base.copyWith(
    scaffoldBackgroundColor: IqColors.bg,
    colorScheme: const ColorScheme.light(
      primary: IqColors.brand,
      onPrimary: IqColors.card,
      secondary: IqColors.accent,
      onSecondary: IqColors.brand,
      surface: IqColors.bg,
      onSurface: IqColors.fg,
      error: IqColors.err,
      onError: IqColors.card,
      outline: IqColors.line,
    ),
    textTheme: const TextTheme(
      displayLarge: IqText.display,
      headlineMedium: IqText.headline,
      titleLarge: IqText.title,
      titleMedium: IqText.cardTitle,
      bodyLarge: IqText.body,
      bodyMedium: IqText.body,
      bodySmall: IqText.small,
      labelLarge: IqText.button,
      labelMedium: IqText.label,
      labelSmall: IqText.mono,
    ),
    // The Material ripple is not part of the design; press states are drawn by the components.
    splashFactory: NoSplash.splashFactory,
    highlightColor: IqColors.brandWash,
    dividerColor: IqColors.line,
  );
}
