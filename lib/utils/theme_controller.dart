import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  // Singleton instance
  static final ThemeController _instance = ThemeController._internal();

  factory ThemeController() => _instance;

  ThemeController._internal() : super(ThemeMode.system);

  /// Load saved theme from SharedPreferences
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    if (themeString == 'light') {
      value = ThemeMode.light;
    } else if (themeString == 'dark') {
      value = ThemeMode.dark;
    } else {
      value = ThemeMode.system;
    }
  }

  /// Toggle or set theme
  Future<void> setTheme(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) {
      await prefs.setString('theme_mode', 'light');
    } else if (mode == ThemeMode.dark) {
      await prefs.setString('theme_mode', 'dark');
    } else {
      await prefs.remove('theme_mode'); // Default to system
    }
  }

  /// Helper to toggle between light and dark (skipping system for simple toggle UI)
  Future<void> toggleTheme(bool isDark) async {
    await setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
