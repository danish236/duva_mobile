import 'package:flutter/material.dart';

class AppTheme {
  // --- BUBBLEGUM FANTASY COLOR PALETTE ---
  static const Color duskBlue = Color(0xFF084B83);
  static const Color skySurge = Color(0xFF42BFDD);
  static const Color frozenWater = Color(0xFFBBE6E4);
  static const Color whiteSmoke = Color(0xFFF0F6F6);
  static const Color hotPink = Color(0xFFFF66B3);

  // Dark Mode specific background colors
  static const Color darkBackground = Color(0xFF0B1320); // Deep midnight blue
  static const Color darkSurface = Color(0xFF142538);    // Slightly lighter card blue

  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: skySurge,
      scaffoldBackgroundColor: whiteSmoke,
      fontFamily: 'Inter', // Default to a clean modern font if you add it later
      
      colorScheme: const ColorScheme.light(
        primary: skySurge,
        secondary: hotPink,
        tertiary: duskBlue,
        surface: Colors.white,
        background: whiteSmoke,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: duskBlue, // Text on cards will be dusk blue for a softer look than black
        onBackground: duskBlue,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: whiteSmoke,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: duskBlue),
        titleTextStyle: TextStyle(color: duskBlue, fontSize: 20, fontWeight: FontWeight.bold),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: skySurge,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: skySurge.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: skySurge, width: 2)),
        labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: frozenWater,
        labelStyle: const TextStyle(color: duskBlue, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[300]!)),
      ),
    );
  }

  // --- DARK THEME ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: skySurge,
      scaffoldBackgroundColor: darkBackground,
      
      colorScheme: const ColorScheme.dark(
        primary: skySurge,
        secondary: hotPink,
        tertiary: frozenWater,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: whiteSmoke, // Light text on dark cards
        onBackground: whiteSmoke,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: whiteSmoke),
        titleTextStyle: TextStyle(color: whiteSmoke, fontSize: 20, fontWeight: FontWeight.bold),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: skySurge,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: skySurge.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: skySurge, width: 2)),
        labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: skySurge.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: whiteSmoke, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      ),
    );
  }
}