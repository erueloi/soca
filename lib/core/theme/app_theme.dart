import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF556B2F), // Dark Olive Green
      brightness: Brightness.light,
      primary: const Color(0xFF556B2F),
      secondary: const Color(0xFF8B4513), // Saddle Brown
      tertiary: const Color(0xFFA0522D), // Sienna
      surface: const Color(0xFFFDFCF5), // Off-white/Cream for paper feel
    ),
    scaffoldBackgroundColor: const Color(0xFFFDFCF5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF556B2F),
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    // cardTheme: CardTheme(
    //   elevation: 2,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    //   color: Colors.white,
    //   surfaceTintColor: Colors.white,
    // ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontFamily:
            'Serif', // Using default serif for a more "classic/nature" look? Or sticking to Sans for readability? Let's stick to default Sans for now but bold.
        fontWeight: FontWeight.bold,
        color: Color(0xFF2E3B1F), // Darker olive for text
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A2212), // Almost black green
      ),
      bodyMedium: TextStyle(
        color: Color(0xFF2E3B1F), // Darker for visibility
        fontWeight: FontWeight.w500, // Slightly bolder
      ),
      bodySmall: TextStyle(
        color: Color(0xFF4A4A4A), // Dark grey instead of light grey
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
