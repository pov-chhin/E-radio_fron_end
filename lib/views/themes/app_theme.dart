import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Shared by [light_theme.dart] and [dark_theme.dart] — e-Radio's light and
/// dark themes only ever differ in their [AppColors] tokens, not in
/// structure, so both are this one builder parameterized by brightness.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  );
  final colorScheme = baseScheme.copyWith(
    primary: AppColors.primary,
    secondary: AppColors.brand400,
    tertiary: AppColors.brand600,
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: isDark ? AppColors.darkInk : AppColors.lightInk,
    onSurfaceVariant: isDark ? AppColors.darkInkSoft : AppColors.lightInkSoft,
  );
  final textTheme = GoogleFonts.kantumruyProTextTheme(
    isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 78,
      backgroundColor: colorScheme.surface,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? colorScheme.primary : colorScheme.onSurface,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected ? colorScheme.primary : colorScheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        );
      }),
    ),
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      filled: true,
    ),
  );
}

/// What call sites use (`AppTheme.light()`/`AppTheme.dark()` in [app.dart]) —
/// mirrors 988score-app's `core/theme/app_theme.dart` entry point.
class AppTheme {
  AppTheme._();

  static ThemeData light() => buildAppTheme(Brightness.light);
  static ThemeData dark() => buildAppTheme(Brightness.dark);
}
