import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color background = Color(0xFF000000); // Deep Black
  static const Color surface = Color(0xFF121212); // Dark Grey
  static const Color primary = Color(0xFFFFFFFF); // White for text/accents
  static const Color secondary = Color(0xFFAAAAAA); // Grey for secondary text

  // Accent colors (dynamic later, but defaults here)
  static const Color accentRed = Color(0xFFFF3B30); // Apple red
  static const Color accentYellow = Color(0xFFFFCC00); // Apple yellow
  static const Color accentGreen = Color(0xFF34C759); // Apple green
  static const Color accentBlue = Color(0xFF0A84FF); // Apple blue

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: const TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: const TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: const TextStyle(color: primary),
          bodyMedium: const TextStyle(color: secondary),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: secondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primary),
      ),
    );
  }
}
