import 'package:flutter/material.dart';

class AppColors {
  // Светлая тема
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightBorders = Color(0xFFD0D0D0);
  static const Color lightBaseText = Color(0xFF000000);
  static const Color lightAdditionalText = Color(0xFF6F6F6F);
  static const Color sidebarBackgroundLight = Color(0xFFF9FAFB); // как было

  // Тёмная тема
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkBorders = Color(0xFF3A3A3A);
  static const Color darkBaseText = Color(0xFFFFFFFF);
  static const Color darkAdditionalText = Color(0xFFA0A0A0);
  static const Color sidebarBackgroundDark = Color(0xFF111827);  // тёмный слейтовый

  // Статусы (общие для обеих тем)
  static const Color info = Color(0xFF104AFF);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF1C40F);
  static const Color error = Color(0xFFE74C3C);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightBaseText,
      dividerColor: lightBorders,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightBaseText,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: lightBaseText),
      ),
      colorScheme: const ColorScheme.light(
        background: lightBackground,
        primary: lightBaseText,
        secondary: lightAdditionalText,
        error: error,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkBaseText,
      dividerColor: darkBorders,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkBaseText,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: darkBaseText),
      ),
      colorScheme: const ColorScheme.dark(
        background: darkBackground,
        primary: darkBaseText,
        secondary: darkAdditionalText,
        error: error,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
