import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'client_palette.dart';
import 'app_design_system.dart';

/// Мягкий переход в стиле iOS: слайд справа + лёгкое затухание.
class _SmoothSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  static const _curve = Curves.easeOutCubic;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: _curve);
    final slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(curved);
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: fade,
        child: child,
      ),
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData _base(ClientPalette p) {
    final isDark = p.brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: p.navBg,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: p.gold1,
            secondary: p.gold1,
            surface: p.surface,
            error: p.error,
            onPrimary: p.onAccent,
            onSecondary: p.onAccent,
            onSurface: p.textPrimary,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: p.gold1,
            secondary: p.gold2,
            surface: p.surface,
            error: p.error,
            onPrimary: p.onAccent,
            onSecondary: p.onAccent,
            onSurface: p.textPrimary,
            onError: Colors.white,
          );

    return ThemeData(
      brightness: p.brightness,
      scaffoldBackgroundColor: p.background,
      primaryColor: p.gold1,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
        systemOverlayStyle: overlayStyle,
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.navBg,
        selectedItemColor: p.navActive,
        unselectedItemColor: p.navInactive,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.navActive),
        unselectedLabelStyle: TextStyle(fontSize: 11, color: p.navInactive),
        showUnselectedLabels: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: p.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
          side: BorderSide(color: p.strokeGold.withValues(alpha: isDark ? 0.14 : 0.18), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bgCard,
        hintStyle: TextStyle(color: p.textPlaceholder, fontSize: 15),
        labelStyle: TextStyle(color: p.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
          borderSide: BorderSide(color: isDark ? p.strokeSoft : p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
          borderSide: BorderSide(color: isDark ? p.strokeSoft : p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
          borderSide: BorderSide(color: p.gold2, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
          borderSide: BorderSide(color: p.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.gold2,
          foregroundColor: p.onAccent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.gold1,
          side: BorderSide(color: p.gold1),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.gold1,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: p.gold1,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.textPrimary),
        secondaryLabelStyle: TextStyle(fontSize: 12, color: p.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesignSystem.radiusStatCard)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.bgCard2,
        contentTextStyle: TextStyle(color: p.textPrimary, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.cardBg,
        contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        titleTextStyle: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothSlidePageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get dark => _base(ClientPalette.dark);

  static ThemeData get light => _base(ClientPalette.light);
}
