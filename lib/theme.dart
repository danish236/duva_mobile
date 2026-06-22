import 'package:flutter/material.dart';

class AppTheme {
  // Midnight Glass Palette
  static const Color voidBackground = Color(0xFF090C15);
  static const Color surfaceGlass = Color(0xFF161B2A);
  static const Color primaryRose = Color(0xFFF43F5E); // Premium Dating Pink
  static const Color electricCyan = Color(0xFF06B6D4);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: voidBackground,
      primaryColor: primaryRose,
      fontFamily: 'Inter', // Assuming standard modern sans-serif
      colorScheme: const ColorScheme.dark(
        primary: primaryRose,
        secondary: electricCyan,
        surface: surfaceGlass,
        background: voidBackground,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: voidBackground,
        selectedItemColor: primaryRose,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  // We map lightTheme to darkTheme to enforce the premium dark mode universally for now.
  static ThemeData get lightTheme => darkTheme; 
}