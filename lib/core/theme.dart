import 'package:flutter/material.dart';

class AppTheme {
  // Global Theme Notifier (Defaults to Dark Mode)
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  // Dark Theme Colors (Existing)
  static const Color backgroundDark = Color(0xFF0F172A); 
  static const Color primaryAccent = Color(0xFF3B82F6);  
  static const Color secondaryAccent = Color(0xFF10B981); 
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  // Light Theme Colors (NEW)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMutedLight = Color(0xFF64748B);

  // Helper to check if dark mode is active
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Dynamic Input Decoration
  static InputDecoration inputDecoration(String label, IconData icon, BuildContext context) {
    bool dark = isDark(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: dark ? textMuted : textMutedLight),
      prefixIcon: Icon(icon, color: primaryAccent),
      filled: true,
      fillColor: dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryAccent, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  // Define the actual ThemeData objects
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    appBarTheme: const AppBarTheme(backgroundColor: backgroundDark, elevation: 0),
    fontFamily: 'Roboto',
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundLight, 
      elevation: 0,
      iconTheme: IconThemeData(color: textDark),
      titleTextStyle: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.bold)
    ),
    fontFamily: 'Roboto',
  );
}