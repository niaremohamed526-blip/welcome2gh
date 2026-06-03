import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Accent colours — always const, never change between themes.
class AppColors {
  static const yellow    = Color(0xFFFFCC00);
  static const yellowDark = Color(0xFFE6B800);
  static const red       = Color(0xFFE53935);
  static const green     = Color(0xFF43A047);
  static const teal      = Color(0xFF00897B);

  // Background / text / surface — runtime values, change with theme.
  static bool _isDark = true;
  static void setDark(bool v) => _isDark = v;
  static bool get isDark => _isDark;

  static Color get navy      => _isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F4F8);
  static Color get navyLight => _isDark ? const Color(0xFF162032) : const Color(0xFFE4EAF2);
  static Color get navyCard  => _isDark ? const Color(0xFF1A2535) : const Color(0xFFFFFFFF);
  static Color get white     => _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0D1B2A);
  static Color get grey      => _isDark ? const Color(0xFF8B9AAB) : const Color(0xFF4A5A6A);
  static Color get greyLight => _isDark ? const Color(0xFFB0BEC5) : const Color(0xFF6A7A8A);
  static Color get cardBorder => _isDark ? const Color(0xFF243044) : const Color(0xFFD8E2EE);
  static Color get overlay   => _isDark ? const Color(0x99000000) : const Color(0x22000000);
}

class AppTheme {
  static ThemeData get dark => _build(true);
  static ThemeData get light => _build(false);

  static ThemeData _build(bool dark) {
    final bg       = dark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F4F8);
    final card     = dark ? const Color(0xFF1A2535) : const Color(0xFFFFFFFF);
    final navLight = dark ? const Color(0xFF162032) : const Color(0xFFE4EAF2);
    final onSurf   = dark ? const Color(0xFFFFFFFF) : const Color(0xFF0D1B2A);
    final onSurf60 = dark ? const Color(0xFFB0BEC5) : const Color(0xFF4A5A6A);
    final border   = dark ? const Color(0xFF243044) : const Color(0xFFD8E2EE);
    final scheme   = dark ? Brightness.dark : Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: scheme,
        primary: AppColors.yellow,
        onPrimary: const Color(0xFF0D1B2A),
        secondary: AppColors.yellow,
        onSecondary: const Color(0xFF0D1B2A),
        error: AppColors.red,
        onError: const Color(0xFFFFFFFF),
        surface: card,
        onSurface: onSurf,
        outline: border,
        outlineVariant: border,
        surfaceContainerHighest: navLight,
      ),
      textTheme: GoogleFonts.interTextTheme(
        dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.barlow(fontSize: 48, fontWeight: FontWeight.w900, color: onSurf, letterSpacing: -1),
        displayMedium: GoogleFonts.barlow(fontSize: 36, fontWeight: FontWeight.w800, color: onSurf, letterSpacing: -0.5),
        displaySmall: GoogleFonts.barlow(fontSize: 28, fontWeight: FontWeight.w800, color: onSurf),
        headlineLarge: GoogleFonts.barlow(fontSize: 24, fontWeight: FontWeight.w700, color: onSurf),
        headlineMedium: GoogleFonts.barlow(fontSize: 20, fontWeight: FontWeight.w700, color: onSurf),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: onSurf),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: onSurf),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: onSurf60),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: onSurf60),
        labelSmall: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.yellow),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: onSurf),
        titleTextStyle: GoogleFonts.barlow(fontSize: 20, fontWeight: FontWeight.w700, color: onSurf),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navLight,
        selectedItemColor: AppColors.yellow,
        unselectedItemColor: onSurf60,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow, width: 1.5)),
        hintStyle: GoogleFonts.inter(color: onSurf60, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: const Color(0xFF0D1B2A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.barlow(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border)),
      ),
    );
  }
}
