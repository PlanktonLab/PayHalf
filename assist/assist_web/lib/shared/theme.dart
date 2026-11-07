import 'package:flutter/material.dart';

import 'tp_colors.dart';

const kFont = 'PingFangTC';

ThemeData buildTheme({double textScale = 1}) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TPColors.primary500,
      primary: TPColors.primary500,
      secondary: TPColors.secondary500,
      error: TPColors.red500,
      surface: TPColors.white,
    ),
    scaffoldBackgroundColor: TPColors.grayscale50,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: TPColors.grayscale800,
      displayColor: TPColors.grayscale900,
      fontFamily: kFont,
    ),
    dividerTheme: const DividerThemeData(color: TPColors.grayscale100, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TPColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TPColors.grayscale200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TPColors.grayscale200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TPColors.primary500, width: 2),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: TPColors.grayscale800, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: TPColors.white, fontSize: 13, fontFamily: kFont),
    ),
  );
}
