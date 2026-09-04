import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slickbill/theme/sb_colors.dart';

ThemeData buildSlickBillsTheme() {
  final inter = GoogleFonts.interTextTheme();

  TextStyle interStyle({
    required double size,
    required FontWeight weight,
    double height = 1.3,
    double letterSpacing = 0,
    Color color = SbColors.onSurface,
  }) {
    return inter.bodyMedium!.copyWith(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: SbColors.surface,
    canvasColor: SbColors.surface,
    colorScheme: const ColorScheme.light(
      primary: SbColors.deepNavy,
      onPrimary: SbColors.onPrimary,
      primaryContainer: SbColors.primaryContainer,
      onPrimaryContainer: SbColors.onPrimary,
      secondary: SbColors.secondary,
      onSecondary: SbColors.onPrimary,
      secondaryContainer: SbColors.secondaryContainer,
      surface: SbColors.surface,
      onSurface: SbColors.onSurface,
      onSurfaceVariant: SbColors.onSurfaceVariant,
      error: SbColors.error,
      onError: SbColors.onPrimary,
      outline: SbColors.outline,
      outlineVariant: SbColors.outlineVariant,
    ),
    textTheme: inter.copyWith(
      displayLarge: interStyle(size: 32, weight: FontWeight.w800, height: 1.2, letterSpacing: -0.03 * 32),
      displayMedium: interStyle(size: 22, weight: FontWeight.w600, height: 1.25),
      displaySmall: interStyle(size: 16, weight: FontWeight.w600),
      headlineLarge: interStyle(size: 28, weight: FontWeight.w700, height: 1.28, letterSpacing: -0.01 * 28),
      headlineMedium: interStyle(size: 22, weight: FontWeight.w600, height: 1.27),
      headlineSmall: interStyle(size: 18, weight: FontWeight.w600, height: 1.33),
      titleLarge: interStyle(size: 18, weight: FontWeight.w600),
      titleMedium: interStyle(size: 16, weight: FontWeight.w600),
      titleSmall: interStyle(size: 14, weight: FontWeight.w600, letterSpacing: 0.14),
      bodyLarge: interStyle(size: 16, weight: FontWeight.w400, height: 1.5),
      bodyMedium: interStyle(size: 14, weight: FontWeight.w400, height: 1.43),
      bodySmall: interStyle(size: 12, weight: FontWeight.w400, height: 1.33, color: SbColors.onSurfaceVariant),
      labelLarge: interStyle(size: 14, weight: FontWeight.w600, letterSpacing: 0.14),
      labelMedium: interStyle(size: 12, weight: FontWeight.w600, letterSpacing: 0.12),
      labelSmall: interStyle(size: 10, weight: FontWeight.w600, letterSpacing: 0.1),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xCCF4FAFB),
      foregroundColor: SbColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: SbColors.surfaceLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SbRadii.md),
      ),
    ),
    dividerColor: SbColors.surfaceContainer,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SbColors.deepNavy,
        foregroundColor: SbColors.onPrimary,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SbRadii.md),
        ),
        textStyle: interStyle(size: 14, weight: FontWeight.w600, color: SbColors.onPrimary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SbColors.deepNavy,
        side: const BorderSide(color: SbColors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SbRadii.md),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SbColors.surfaceLow,
      hintStyle: interStyle(size: 14, weight: FontWeight.w400, color: SbColors.outline),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SbRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SbRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SbRadii.md),
        borderSide: const BorderSide(color: SbColors.electricCyan, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: SbColors.surfaceHigh,
      selectedColor: SbColors.deepNavy,
      labelStyle: interStyle(size: 12, weight: FontWeight.w600),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xE6F4FAFB),
      selectedItemColor: SbColors.onPrimary,
      unselectedItemColor: SbColors.onSurfaceVariant,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
