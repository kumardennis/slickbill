import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

extension CustomColorScheme on ColorScheme {
  Color get lightYellow => const Color(0xFFFEF3C7);
  Color get yellow => SbColors.warningAmber;
  Color get blue => SbColors.deepNavy;
  Color get lighterBlue => SbColors.electricCyan;
  Color get darkerBlue => SbColors.deepNavy;
  Color get lightGreen => const Color(0xFFD1FAE5);
  Color get darkGreen => SbColors.primary;
  Color get turqouise => SbColors.primaryContainer;
  Color get green => SbColors.successGreen;
  Color get red => SbColors.error;
  Color get light => brightness == Brightness.dark ? Colors.white : SbColors.surface;
  Color get dark => onSurface;
  Color get gray => outline;
  Color get lightGray => outlineVariant;
  Color get darkGray => onSurfaceVariant;

  Color get electricCyan => SbColors.electricCyan;
  Color get deepNavy => SbColors.deepNavy;
  Color get successGreen => SbColors.successGreen;
  Color get warningAmber => SbColors.warningAmber;
  Color get surfaceLowest => SbColors.surfaceLowest;
  Color get surfaceLow => SbColors.surfaceLow;
  Color get surfaceContainer => SbColors.surfaceContainer;
  Color get surfaceHigh => SbColors.surfaceHigh;
}

Map customColorScheme = {
  'lightYellow': const Color(0xFFFEF3C7),
  'yellow': SbColors.warningAmber,
  'blue': SbColors.deepNavy,
  'lighterBlue': SbColors.electricCyan,
  'darkerBlue': SbColors.deepNavy,
  'lightGreen': const Color(0xFFD1FAE5),
  'darkGreen': SbColors.primary,
  'turqouise': SbColors.primaryContainer,
  'green': SbColors.successGreen,
  'red': SbColors.error,
  'light': SbColors.surface,
  'dark': SbColors.obsidian,
  'gray': SbColors.outline,
  'lightGray': SbColors.outlineVariant,
  'darkGray': SbColors.onSurfaceVariant,
};
