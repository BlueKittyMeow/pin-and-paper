import 'package:flutter/material.dart';

class AppTheme {
  // Witchy Flatlay Color Palette
  static const Color warmWood = Color(0xFF8B7355);
  static const Color kraftPaper = Color(0xFFD4B896);
  static const Color creamPaper = Color(0xFFF5F1E8);
  static const Color deepShadow = Color(0xFF4A3F35);
  static const Color richBlack = Color(0xFF1C1C1C);
  static const Color mutedLavender = Color(0xFF9B8FA5);
  static const Color softSage = Color(0xFF8FA596);
  static const Color warmBeige = Color(0xFFE8DDD3);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: deepShadow,
        secondary: mutedLavender,
        surface: creamPaper,
        onPrimary: creamPaper,
        onSecondary: richBlack,
        onSurface: richBlack,
      ),
      scaffoldBackgroundColor: warmBeige,

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: richBlack,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: richBlack,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: deepShadow,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamPaper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kraftPaper, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kraftPaper, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: deepShadow, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return deepShadow;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(creamPaper),
        side: const BorderSide(color: deepShadow, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepShadow,
          foregroundColor: creamPaper,
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
