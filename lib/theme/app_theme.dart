import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    surface: HColors.panel,
    onSurface: HColors.text,
    primary: HColors.peach,
    onPrimary: HColors.onPeach,
    secondary: HColors.mint,
    onSecondary: HColors.onMint,
    error: HColors.coral,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: HColors.bg,
    fontFamily: HFonts.body,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: HFonts.display, fontWeight: FontWeight.w600, color: HColors.text),
      titleLarge: TextStyle(fontFamily: HFonts.display, fontWeight: FontWeight.w600, color: HColors.text),
      titleMedium: TextStyle(fontFamily: HFonts.display, fontWeight: FontWeight.w500, color: HColors.text),
      bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: HColors.body),
      bodyMedium: TextStyle(fontWeight: FontWeight.w600, color: HColors.body),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, color: HColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HColors.surface,
      hintStyle: const TextStyle(color: HColors.placeholder),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(HRadii.input), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HRadii.input),
        borderSide: const BorderSide(color: HColors.mint, width: 2),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
