import 'package:flutter/material.dart';

const _standardScheme = ColorScheme.light(
  primary: Color(0xFF0B5C63),
  onPrimary: Colors.white,
  surface: Color(0xFFF7F9F9),
  onSurface: Color(0xFF1A1C1E),
  outline: Color(0xFF5B6770),
);

const _highContrastScheme = ColorScheme.dark(
  primary: Color(0xFF4ADE80),
  onPrimary: Colors.black,
  surface: Colors.black,
  onSurface: Colors.white,
  outline: Color(0xFF4ADE80),
);

ThemeData buildTheme({required bool highContrast}) {
  final scheme = highContrast ? _highContrastScheme : _standardScheme;
  final borderWidth = highContrast ? 3.0 : 1.0;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline, width: borderWidth),
      ),
    ),
    textTheme: Typography.material2021().black.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 12,
      activeTrackColor: scheme.primary,
      // Mid-gray against the light surface keeps the empty track visible.
      inactiveTrackColor: highContrast
          ? const Color(0xFF9AA5A0)
          : const Color(0xFF7F8B94),
      thumbColor: scheme.primary,
      activeTickMarkColor: scheme.onPrimary,
      inactiveTickMarkColor: scheme.surface,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
      overlayColor: scheme.primary.withValues(alpha: 0.2),
      showValueIndicator: ShowValueIndicator.alwaysVisible,
      valueIndicatorColor: scheme.primary,
      valueIndicatorTextStyle: TextStyle(
        color: scheme.onPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
