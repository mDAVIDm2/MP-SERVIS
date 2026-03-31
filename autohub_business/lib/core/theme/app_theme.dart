import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_colors_desktop.dart';
import 'desktop_design_system.dart';

class AppTheme {
  AppTheme._();

  /// Светлая тема для desktop: единый стиль CRM, мягкие тени, чёткая иерархия.
  static ThemeData get desktop => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColorsDesktop.background,
        primaryColor: AppColorsDesktop.primary,
        colorScheme: const ColorScheme.light(
          primary: AppColorsDesktop.primary,
          surface: AppColorsDesktop.surface,
          error: AppColorsDesktop.error,
          onPrimary: Colors.white,
          onSurface: AppColorsDesktop.textPrimary,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColorsDesktop.surface,
          foregroundColor: AppColorsDesktop.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColorsDesktop.textPrimary,
          ),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: AppColorsDesktop.navBg,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColorsDesktop.cardBg,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
            side: const BorderSide(color: AppColorsDesktop.border, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColorsDesktop.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
            textStyle: DesktopDesignSystem.button,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColorsDesktop.primary,
            side: const BorderSide(color: AppColorsDesktop.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
            textStyle: DesktopDesignSystem.button,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColorsDesktop.textSecondary,
            textStyle: DesktopDesignSystem.button,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColorsDesktop.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: Color(0xFF0D0D0D),
          onSurface: AppColors.textPrimary,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.navBg,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.navBg,
          selectedItemColor: AppColors.navActive,
          unselectedItemColor: AppColors.navInactive,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: const Color(0xFF0D0D0D),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
