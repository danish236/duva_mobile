import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryRose = Color(0xFFF43F5E); 
  static const Color electricCyan = Color(0xFF06B6D4);
  static const Color voidBackground = Color(0xFF07090E); // Deepened further
  static const Color surfaceGlass = Color(0xFF131824);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: voidBackground,
      primaryColor: primaryRose,
      // MODERN TYPOGRAPHY INJECTION
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: -1.5),
        displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: -1.0),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        bodyLarge: GoogleFonts.outfit(fontWeight: FontWeight.w500, letterSpacing: 0.2),
        bodyMedium: GoogleFonts.outfit(fontWeight: FontWeight.w400, letterSpacing: 0.1),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryRose,
        secondary: electricCyan,
        surface: surfaceGlass,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
      // GLOBAL FLUID ANIMATIONS
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme; 
}