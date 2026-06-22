import 'package:flutter/material.dart';

class AppTheme {
  // --- BUBBLEGUM FANTASY COLOR PALETTE ---
  static const Color duskBlue = Color(0xFF084B83);
  static const Color skySurge = Color(0xFF42BFDD);
  static const Color frozenWater = Color(0xFFBBE6E4);
  static const Color whiteSmoke = Color(0xFFF0F6F6);
  static const Color hotPink = Color(0xFFFF66B3);

  // Deepened the Dark Mode background for MAXIMUM neon contrast
  static const Color voidBackground = Color(0xFF020B14); 
  static const Color cardSurface = Color(0xFF051726);

  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: whiteSmoke,
      primaryColor: skySurge,
      colorScheme: const ColorScheme.light(
        primary: skySurge,
        secondary: hotPink,
        tertiary: frozenWater,
        surface: Colors.white,
        background: whiteSmoke,
        onPrimary: Colors.white,
        onSurface: duskBlue,
        onBackground: duskBlue,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // Floating app bar look
        foregroundColor: duskBlue,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: duskBlue, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: hotPink,
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: hotPink.withValues(alpha: 0.6), // Punchy Pink Glow
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: hotPink,
        unselectedItemColor: frozenWater,
        elevation: 20,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // --- DARK THEME ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: voidBackground,
      primaryColor: skySurge,
      colorScheme: const ColorScheme.dark(
        primary: skySurge,
        secondary: hotPink,
        tertiary: frozenWater,
        surface: cardSurface,
        background: voidBackground,
        onPrimary: Colors.white,
        onSurface: Colors.white,
        onBackground: whiteSmoke,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: skySurge,
          foregroundColor: voidBackground, // Dark text on bright button
          elevation: 15,
          shadowColor: skySurge.withValues(alpha: 0.8), // Punchy Cyan Glow
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardSurface,
        selectedItemColor: hotPink,
        unselectedItemColor: duskBlue,
        elevation: 20,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}