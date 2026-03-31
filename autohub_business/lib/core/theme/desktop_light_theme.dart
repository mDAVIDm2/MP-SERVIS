import 'package:flutter/material.dart';
import 'app_colors_desktop.dart';

/// Светлая тема для модальных окон и экранов редактирования на desktop (не наследует тёмную тему приложения).
ThemeData desktopLightUiTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColorsDesktop.border),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColorsDesktop.background,
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColorsDesktop.surface,
      surfaceTintColor: Colors.transparent,
    ),
    colorScheme: ColorScheme.light(
      primary: AppColorsDesktop.primary,
      onPrimary: Colors.white,
      surface: AppColorsDesktop.surface,
      onSurface: AppColorsDesktop.textPrimary,
      outline: AppColorsDesktop.border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColorsDesktop.surface,
      foregroundColor: AppColorsDesktop.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColorsDesktop.textPrimary, fontSize: 14),
      bodyMedium: TextStyle(color: AppColorsDesktop.textPrimary, fontSize: 14),
      titleLarge: TextStyle(color: AppColorsDesktop.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColorsDesktop.nestedBg.withValues(alpha: 0.65),
      labelStyle: const TextStyle(color: AppColorsDesktop.textSecondary),
      hintStyle: const TextStyle(color: AppColorsDesktop.textPlaceholder),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColorsDesktop.primary, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColorsDesktop.primary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColorsDesktop.primary,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColorsDesktop.textPrimary,
        side: const BorderSide(color: AppColorsDesktop.border),
      ),
    ),
  );
}

Widget themeDesktopLight({required Widget child}) {
  return Theme(
    data: desktopLightUiTheme(),
    child: child,
  );
}
