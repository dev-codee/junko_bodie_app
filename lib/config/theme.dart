/// Junko Bodie Roulette Tournament — Brand Design Tokens
///
/// Ported from `src/styles/theme.ts` in the Next.js app.
/// All visual constants are locked here. Every widget must reference
/// these tokens — never use raw color values.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Colors
// ──────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  /// Primary background
  static const Color black = Color(0xFF0A0A0A);

  /// Rich gold accent
  static const Color gold = Color(0xFFC9A84C);

  /// Gold hover / lighter
  static const Color goldLight = Color(0xFFD4B85C);

  /// Gold pressed / darker
  static const Color goldDark = Color(0xFFB8973E);

  /// Deep green for structural elements
  static const Color deepGreen = Color(0xFF1A3A2A);

  /// Felt green for table surface
  static const Color feltGreen = Color(0xFF1E4D2B);

  /// Felt green lighter (for gradients)
  static const Color feltGreenLight = Color(0xFF256B3A);

  /// Felt green darker (for depth)
  static const Color feltGreenDark = Color(0xFF163D22);

  /// Roulette red
  static const Color rouletteRed = Color(0xFFC0392B);

  /// Roulette black
  static const Color rouletteBlack = Color(0xFF1A1A1A);

  /// Roulette green (0 / 00)
  static const Color rouletteGreen = Color(0xFF267B4B);

  // Chip denomination colors
  static const Color chipWhite = Color(0xFFF5F5F5);
  static const Color chipOrange = Color(0xFFE67E22);
  static const Color chipBlue = Color(0xFF2B52A2);
  static const Color chipRed = Color(0xFFC0392B);
  static const Color chipGreen = Color(0xFF27AE60);
  static const Color chipBlack = Color(0xFF1A1A1A);
  static const Color chipPurple = Color(0xFF8E44AD);
  static const Color chipYellow = Color(0xFFF1C40F);

  // UI colors
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textGold = Color(0xFFC9A84C);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceLight = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF2A2A2A);
  static const Color overlay = Color(0xB3000000); // rgba(0,0,0,0.7)

  // Page background (from layout.tsx)
  static const Color pageBackground = Color(0xFF0B2B1D);
}

// ──────────────────────────────────────────────────────────────────────────────
// Spacing
// ──────────────────────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ──────────────────────────────────────────────────────────────────────────────
// Border Radius
// ──────────────────────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;
}

// ──────────────────────────────────────────────────────────────────────────────
// Shadows
// ──────────────────────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> gold = [
    BoxShadow(color: Color(0x4DC9A84C), blurRadius: 20),
  ];
  static const List<BoxShadow> goldStrong = [
    BoxShadow(color: Color(0x80C9A84C), blurRadius: 30),
  ];
}

// ──────────────────────────────────────────────────────────────────────────────
// Chip Denominations
// ──────────────────────────────────────────────────────────────────────────────

class ChipDenomination {
  final int value;
  final String label;
  final Color color;
  final Color textColor;

  const ChipDenomination({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });
}

const List<ChipDenomination> chipDenominations = [
  ChipDenomination(
      value: 1,
      label: '\$1',
      color: AppColors.chipWhite,
      textColor: AppColors.black),
  ChipDenomination(
      value: 2,
      label: '\$2',
      color: AppColors.chipOrange,
      textColor: AppColors.textPrimary),
  ChipDenomination(
      value: 5,
      label: '\$5',
      color: AppColors.chipRed,
      textColor: AppColors.textPrimary),
  ChipDenomination(
      value: 10,
      label: '\$10',
      color: AppColors.chipBlue,
      textColor: AppColors.textPrimary),
  ChipDenomination(
      value: 25,
      label: '\$25',
      color: AppColors.chipGreen,
      textColor: AppColors.textPrimary),
  ChipDenomination(
      value: 100,
      label: '\$100',
      color: AppColors.chipBlack,
      textColor: AppColors.gold),
  ChipDenomination(
      value: 500,
      label: '\$500',
      color: AppColors.chipPurple,
      textColor: AppColors.textPrimary),
  ChipDenomination(
      value: 1000,
      label: '\$1000',
      color: AppColors.chipYellow,
      textColor: AppColors.black),
];

// ──────────────────────────────────────────────────────────────────────────────
// Animation Durations
// ──────────────────────────────────────────────────────────────────────────────

class AppTiming {
  AppTiming._();

  static const Duration chipPlace = Duration(milliseconds: 300);
  static const Duration chipRemove = Duration(milliseconds: 250);
  static const Duration spinDuration = Duration(milliseconds: 6000);
  static const Duration resultDisplay = Duration(milliseconds: 3000);
  static const Duration hoverTransition = Duration(milliseconds: 150);
}

// ──────────────────────────────────────────────────────────────────────────────
// Theme
// ──────────────────────────────────────────────────────────────────────────────

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.pageBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.black,
      secondary: AppColors.goldLight,
      onSecondary: AppColors.black,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.rouletteRed,
    ),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.gold,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          color: AppColors.textSecondary,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.gold,
        letterSpacing: 2,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.black,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        elevation: 8,
        shadowColor: const Color(0x40C9A84C),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerColor: AppColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A0A0A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Brand font helpers (for headings that use Playfair Display)
// ──────────────────────────────────────────────────────────────────────────────

TextStyle playfairDisplay({
  double fontSize = 26,
  FontWeight fontWeight = FontWeight.w800,
  Color color = AppColors.textPrimary,
  double letterSpacing = -0.01,
}) {
  return GoogleFonts.playfairDisplay(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

TextStyle cinzelDecorative({
  double fontSize = 20,
  FontWeight fontWeight = FontWeight.w700,
  Color color = AppColors.gold,
  double letterSpacing = 3,
}) {
  return GoogleFonts.cinzelDecorative(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}
