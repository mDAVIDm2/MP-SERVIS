import 'package:flutter/material.dart';
import 'app_colors_desktop.dart';

/// Единая дизайн-система для desktop UI MP-Servis Business (проект autohub_business).
/// Spacing, радиусы, тени, типографика — один стиль для всех экранов.
class DesktopDesignSystem {
  DesktopDesignSystem._();

  // --- Spacing ---
  static const double pagePadding = 24.0;
  static const double blockSpacing = 20.0;
  static const double cardPadding = 16.0;
  static const double cardPaddingLarge = 20.0;
  static const double elementSpacing = 12.0;
  static const double elementSpacingSmall = 8.0;

  // --- Radii ---
  static const double radiusContainer = 14.0;
  static const double radiusCard = 16.0;
  static const double radiusCardLarge = 20.0;
  static const double radiusButton = 12.0;
  static const double radiusBadge = 100.0; // pill

  // --- Shadows (мягкие, без тяжёлых) ---
  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> get shadowCardHover => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> get shadowDropdown => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // --- Sidebar ---
  static const double sidebarWidth = 248.0;
  static const double sidebarLogoHeight = 48.0;
  static const double sidebarItemPaddingH = 16.0;
  static const double sidebarItemPaddingV = 10.0;
  static const double sidebarItemRadius = 10.0;
  static const double sidebarProfilePadding = 16.0;

  // --- Topbar ---
  static const double topbarHeight = 56.0;
  static const double topbarPaddingH = 24.0;

  // --- Typography ---
  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColorsDesktop.textPrimary,
    letterSpacing: -0.3,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColorsDesktop.textPrimary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColorsDesktop.textSecondary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColorsDesktop.textPrimary,
  );
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColorsDesktop.textSecondary,
  );
  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColorsDesktop.textTertiary,
  );
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}
