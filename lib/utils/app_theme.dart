import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Design System for Sortir en Corse.
/// All colors, text styles, and themes are defined here.
class AppColors {
  // ── Core Brand ──
  static const Color primaryOrange = Color(0xFFFF9E00);
  static const Color primaryPurple = Color(0xFF9D4EDD);
  static const Color accentBlue = Color(0xFF3B82F6);

  // ── Dark Theme ──
  static const Color darkBackground = Color(0xFF050505);
  static const Color darkSurface = Color(0xFF0A0A0A);
  static const Color darkCard = Color(0xFF111111);
  static const Color darkNavBar = Color(0xFF0D0D0D);

  // ── Light Theme ──
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);

  // ── Glass ──
  static Color glassWhite(double opacity) => Colors.white.withValues(alpha: opacity);
  static Color glassBlack(double opacity) => Colors.black.withValues(alpha: opacity);

  // ── Semantic ──
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // ── Segment Colors ──
  static Color segmentColor(String segment) {
    switch (segment) {
      case 'party':
        return Colors.purple.shade600;
      default:
        return Colors.amber.shade700;
    }
  }
}

class AppTextStyles {
  // ── Headings ──
  static TextStyle heading1({Color? color}) => GoogleFonts.outfit(
        color: color ?? Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        height: 1.1,
        letterSpacing: -0.5,
      );

  static TextStyle heading2({Color? color}) => GoogleFonts.outfit(
        color: color ?? Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle heading3({Color? color}) => GoogleFonts.outfit(
        color: color ?? Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  // ── Body ──
  static TextStyle body({Color? color}) => GoogleFonts.outfit(
        color: color ?? Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.outfit(
        color: color ?? Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  // ── Captions / Labels ──
  static TextStyle caption({Color? color}) => GoogleFonts.outfit(
        color: color ?? Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );

  static TextStyle label({Color? color}) => GoogleFonts.outfit(
        color: color ?? Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      );

  // ── Navigation ──
  static TextStyle navLabel({Color? color, bool active = false}) =>
      GoogleFonts.outfit(
        color: color ?? (active ? Colors.white : Colors.white38),
        fontSize: 10,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      );

  // ── Brand ──
  static TextStyle brand({Color? color}) => GoogleFonts.philosopher(
        color: color ?? Colors.white.withValues(alpha: 0.9),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
}

class AppTheme {
  // ── Dark Theme ──
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryOrange,
        secondary: AppColors.primaryPurple,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.white10,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ── Light Theme ──
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryOrange,
        secondary: AppColors.primaryPurple,
        surface: AppColors.lightSurface,
        error: AppColors.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: const Color(0xFF1A1A2E),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
