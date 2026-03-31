import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Премиальный тёмный дизайн: отступы, скругления, тени, градиенты карточек.
class AppDesignSystem {
  AppDesignSystem._();

  // --- Spacing (много воздуха) ---
  static const double pagePaddingH = 20.0;
  static const double pagePaddingV = 16.0;
  static const double blockSpacing = 18.0;
  static const double cardPadding = 22.0;
  static const double titleToContent = 14.0;

  // --- Radii ---
  static const double radiusSmall = 16.0;
  static const double radiusStatCard = 24.0;
  static const double radiusOrderCard = 28.0;
  static const double radiusPill = 999.0;

  // --- Stat card: градиент + бордер + тень ---
  static BoxDecoration get statCardDecoration => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A191E),
            const Color(0xFF111115),
          ],
        ),
        borderRadius: BorderRadius.circular(radiusStatCard),
        border: Border.all(
          color: AppColors.strokeGold.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      );

  // --- Order card: многослойный градиент + бордер + тени ---
  static BoxDecoration orderCardDecoration({bool withInsetGlow = true}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusOrderCard),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.0, 0.55, 1.0],
        colors: [
          Color(0xFF1A191D),
          Color(0xFF131217),
          Color(0xFF101014),
        ],
      ),
      border: Border.all(
        color: AppColors.strokeGold.withValues(alpha: 0.16),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowDark,
          blurRadius: 40,
          offset: const Offset(0, 14),
        ),
        if (withInsetGlow) ...[
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.gold2.withValues(alpha: 0.05),
            blurRadius: 0,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ],
    );
  }

  // --- Premium button (pill) ---
  static BoxDecoration premiumButtonDecoration({bool isActive = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusPill),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isActive
            ? [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.02),
              ]
            : [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.01),
              ],
      ),
      border: Border.all(
        color: AppColors.strokeGold.withValues(alpha: isActive ? 0.28 : 0.24),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowDark,
          blurRadius: isActive ? 24 : 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: isActive ? 0.08 : 0.06),
          blurRadius: 0,
          offset: const Offset(0, 1),
          spreadRadius: 0,
        ),
        if (isActive)
          BoxShadow(
            color: AppColors.gold2.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: Offset.zero,
          ),
      ],
    );
  }

  /// Карточка с градиентом для CarCard и подобных.
  static BoxDecoration get carCardDecoration => BoxDecoration(
        borderRadius: BorderRadius.circular(radiusOrderCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B1A20),
            const Color(0xFF141318),
            const Color(0xFF0F0F12),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: AppColors.strokeGold.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 0,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.gold2.withValues(alpha: 0.08),
            blurRadius: 0,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      );
}
