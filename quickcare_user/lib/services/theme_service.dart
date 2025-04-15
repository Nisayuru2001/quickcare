import 'package:flutter/material.dart';

class ThemeService {
  // This is a simple in-memory storage without SharedPreferences for now
  static bool _isDarkMode = false;

  // Get the current theme mode (in-memory)
  static bool isDarkMode() {
    return _isDarkMode;
  }

  // Save the current theme mode (in-memory)
  static void setDarkMode(bool isDarkMode) {
    _isDarkMode = isDarkMode;
  }

  // Get ThemeData based on dark mode setting
  static ThemeData getThemeData(bool isDarkMode) {
    final Color primaryColor = const Color(0xFFE53935); // Modern red

    if (isDarkMode) {
      return ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[900],
        dividerColor: Colors.grey[800],
        inputDecorationTheme: InputDecorationTheme(
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      );
    } else {
      return ThemeData.light().copyWith(
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: primaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        dividerColor: Colors.grey[200],
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFFF8F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      );
    }
  }
}