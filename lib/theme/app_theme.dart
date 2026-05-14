import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors (IBO Pro Style) ──
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF8B7FF0);
  static const Color primaryDark = Color(0xFF4834D4);
  static const Color accent = Color(0xFF00D2FF);
  static const Color gold = Color(0xFFF0C040);
  static const Color goldLight = Color(0xFFFFD966);

  // ── Background (Dark Purple) ──
  static const Color bgDark = Color(0xFF0D1033);
  static const Color bgCard = Color(0xFF1A1150);
  static const Color bgElevated = Color(0xFF221A5C);
  static const Color bgInput = Color(0xFF1A1150);

  // ── Surface ──
  static const Color surfaceLight = Color(0xFF2A2070);
  static const Color surfaceBorder = Color(0xFF3D2D88);

  // ── Text ──
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFB0A8D0);
  static const Color textMuted = Color(0xFF6E64A0);

  // ── Status ──
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB74D);

  // ── Gradients ──
  static const LinearGradient bgGradient = LinearGradient(
    colors: [
      Color(0xFF1A0E3E),
      Color(0xFF15104A),
      Color(0xFF0D1033),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF2A1B6E), Color(0xFF1A1050)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [bgCard, Color(0xFF181C35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF00F5A0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Keep for backwards compat
  static const LinearGradient meshGradientBg = bgGradient;

  // ── Theme Data ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgCard,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: surfaceBorder, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
        headlineLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textMuted),
        labelLarge: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: gold,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: surfaceBorder, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgElevated,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Alias for compat
  static ThemeData get lightTheme => darkTheme;
}
