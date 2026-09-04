import 'package:flutter/material.dart';

/// Stitch / SlickBills 2026 palette.
abstract final class SbColors {
  static const Color deepNavy = Color(0xFF0B2545);
  static const Color primary = Color(0xFF001E33);
  static const Color primaryContainer = Color(0xFF003453);
  static const Color electricCyan = Color(0xFF00C2FF);
  static const Color secondary = Color(0xFF00629E);
  static const Color secondaryContainer = Color(0xFF67B6FF);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color error = Color(0xFFBA1A1A);

  static const Color surface = Color(0xFFF4FAFB);
  static const Color surfaceBright = Color(0xFFF4FAFB);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFEFF5F6);
  static const Color surfaceContainer = Color(0xFFE9EFF0);
  static const Color surfaceHigh = Color(0xFFE3E9EA);
  static const Color surfaceHighest = Color(0xFFDDE4E5);

  static const Color onSurface = Color(0xFF161D1E);
  static const Color onSurfaceVariant = Color(0xFF42474D);
  static const Color outline = Color(0xFF72777E);
  static const Color outlineVariant = Color(0xFFC2C7CE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryFixedDim = Color(0xFFA3CBF1);

  static const Color obsidian = Color(0xFF0A0B0C);
}

abstract final class SbRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

abstract final class SbSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double page = 20;
}

abstract final class SbShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF003453).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardSoft = [
    BoxShadow(
      color: const Color(0xFF003453).withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> navyButton = [
    BoxShadow(
      color: SbColors.deepNavy.withValues(alpha: 0.2),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];
}
