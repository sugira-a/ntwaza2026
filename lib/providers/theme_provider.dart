library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;  // Default to dark mode
  static const String _themeKey = 'isDarkMode';
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _brandGreenDark = Color(0xFF059669);

  ThemeProvider() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;

  // Load theme preference from storage
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? true;  // Default to dark mode
      notifyListeners();
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }

  // Toggle theme and save preference
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  // Set specific theme mode
  Future<void> setThemeMode(bool isDark) async {
    if (_isDarkMode == isDark) return;
    
    _isDarkMode = isDark;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  // Get theme data for MaterialApp
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: _brandGreen,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),  // Light grey background
      colorScheme: const ColorScheme.light(
        primary: _brandGreen,
        secondary: _brandGreenDark,
        surface: Color(0xFFFFFFFF),          // White surface
        surfaceContainerHighest: Color(0xFFF0F0F0),
        onSurface: Color(0xFF1A1A1A),        // Dark text on light surface
        onSurfaceVariant: Color(0xFF616161),  // Medium grey secondary text
        outline: Color(0xFFE0E0E0),           // Light grey outlines
        surfaceTint: _brandGreen,
        tertiary: _brandGreenDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),   // White app bar
        foregroundColor: Color(0xFF1A1A1A),   // Dark text in app bar
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardColor: Colors.white,
      cardTheme: CardThemeData(
        color: Colors.white,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
      ),
      useMaterial3: true,
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _brandGreen,  // Light green primary
      scaffoldBackgroundColor: const Color(0xFF000000),  // True black background
      colorScheme: const ColorScheme.dark(
        primary: _brandGreen,  // Light green
        secondary: _brandGreenDark,  // Darker green
        surface: Color(0xFF000000),
        surfaceVariant: Color(0xFF000000),
        onSurfaceVariant: Color(0xFFA3A3A3),
        outline: Color(0xFF1A1A1A),
        surfaceTint: _brandGreen,
        tertiary: _brandGreen,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardColor: Colors.transparent,
      cardTheme: const CardThemeData(
        color: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      useMaterial3: true,
    );
  }

  // Helper getters for common colors
  Color get backgroundColor => _isDarkMode ? const Color(0xFF000000) : const Color(0xFFF5F5F5);
  Color get cardColor => _isDarkMode ? Colors.transparent : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get subtextColor => _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
}
