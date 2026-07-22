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
  static const Color sidebarBackgroundDark = Color(
    0xFF111827,
  ); // тёмный слейтовый

  // Статусы (общие для обеих тем)
  static const Color info = Color(0xFF104AFF);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF1C40F);
  static const Color error = Color(0xFFE74C3C);

  static InputDecorationTheme _buildInputDecorationTheme({
    required Color borderColor,
    required Color focusedColor,
    required Color fillColor,
    required Color labelColor,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor, width: 0.8),
    );

    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: TextStyle(color: labelColor),
      hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.9)),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: focusedColor, width: 1.0),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: error, width: 1.0),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: error, width: 1.0),
      ),
    );
  }

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
      textTheme: const TextTheme(bodyMedium: TextStyle(color: lightBaseText)),
      colorScheme: const ColorScheme.light(
        surface: lightBackground,
        primary: lightBaseText,
        secondary: lightAdditionalText,
        error: error,
      ),
      inputDecorationTheme: _buildInputDecorationTheme(
        borderColor: lightBorders,
        focusedColor: lightBaseText,
        fillColor: const Color(0xFFF7F8FA),
        labelColor: lightAdditionalText,
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
      textTheme: const TextTheme(bodyMedium: TextStyle(color: darkBaseText)),
      colorScheme: const ColorScheme.dark(
        surface: darkBackground,
        primary: darkBaseText,
        secondary: darkAdditionalText,
        error: error,
      ),
      inputDecorationTheme: _buildInputDecorationTheme(
        borderColor: darkBorders,
        focusedColor: darkBaseText,
        fillColor: const Color(0xFF1F2937),
        labelColor: darkAdditionalText,
      ),
    );
  }
}
