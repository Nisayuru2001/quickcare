import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverThemeService {
  static const String _darkModeKey = 'darkMode';

  // Set dark mode preference
  static Future<void> setDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);
  }

  // Get dark mode preference
  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  // Get theme data based on dark mode
  static ThemeData getThemeData(bool isDarkMode) {
    const Color primaryColor = Color(0xFFE53935);

    if (isDarkMode) {
      return ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColor,
          surface: Colors.grey[850]!,
          background: Colors.black,
          onBackground: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        cardColor: Colors.grey[900],
        useMaterial3: true,
      );
    } else {
      return ThemeData.light().copyWith(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: primaryColor,
          surface: const Color(0xFFF8F9FA),
          background: Colors.white,
          onBackground: const Color(0xFF212121),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: Colors.white,
        useMaterial3: true,
      );
    }
  }
}