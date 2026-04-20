import 'package:flutter/material.dart';
import 'client_palette.dart';

/// Отступы, скругления, декорации карточек — с учётом [ClientPalette] (тёмная / светлая тема).
class AppDesignSystem {
  AppDesignSystem._();

  static const double pagePaddingH = 20.0;
  static const double pagePaddingV = 16.0;
  static const double blockSpacing = 18.0;
  static const double cardPadding = 22.0;
  static const double titleToContent = 14.0;

  static const double radiusSmall = 16.0;
  static const double radiusStatCard = 24.0;
  static const double radiusOrderCard = 28.0;
  static const double radiusPill = 999.0;

  static BoxDecoration statCardDecoration(ClientPalette p) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.brightness == Brightness.dark
              ? [const Color(0xFF1A191E), const Color(0xFF111115)]
              : [Colors.white, const Color(0xFFF0F4FC)],
        ),
        borderRadius: BorderRadius.circular(radiusStatCard),
        border: Border.all(
          color: p.gold2.withValues(alpha: p.brightness == Brightness.dark ? 0.14 : 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadowDark,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (p.brightness == Brightness.dark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04),
              blurRadius: 0,
              offset: const Offset(0, 1),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 0,
              offset: const Offset(0, 1),
            ),
        ],
      );

  static BoxDecoration orderCardDecoration(ClientPalette p, {bool withInsetGlow = true}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusOrderCard),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.55, 1.0],
        colors: p.brightness == Brightness.dark
            ? [const Color(0xFF1A191D), const Color(0xFF131217), const Color(0xFF101014)]
            : [Colors.white, const Color(0xFFF5F8FF), const Color(0xFFE8EEF8)],
      ),
      border: Border.all(
        color: p.gold2.withValues(alpha: p.brightness == Brightness.dark ? 0.16 : 0.22),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: p.shadowDark,
          blurRadius: p.brightness == Brightness.dark ? 40 : 24,
          offset: Offset(0, p.brightness == Brightness.dark ? 14 : 10),
        ),
        if (withInsetGlow) ...[
          BoxShadow(
            color: p.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.9),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: p.gold2.withValues(alpha: p.brightness == Brightness.dark ? 0.05 : 0.08),
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ],
    );
  }

  static BoxDecoration premiumButtonDecoration(ClientPalette p, {bool isActive = false}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusPill),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: p.brightness == Brightness.dark
            ? (isActive
                ? [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.02),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.01),
                  ])
            : (isActive
                ? [
                    p.gold1.withValues(alpha: 0.12),
                    p.gold1.withValues(alpha: 0.04),
                  ]
                : [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.01),
                  ]),
      ),
      border: Border.all(
        color: p.gold2.withValues(alpha: isActive ? 0.28 : 0.24),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: p.shadowDark,
          blurRadius: isActive ? 24 : 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: p.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: isActive ? 0.08 : 0.06)
              : Colors.black.withValues(alpha: isActive ? 0.06 : 0.04),
          blurRadius: 0,
          offset: const Offset(0, 1),
        ),
        if (isActive)
          BoxShadow(
            color: p.gold2.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: Offset.zero,
          ),
      ],
    );
  }

  static BoxDecoration carCardDecoration(ClientPalette p) => BoxDecoration(
        borderRadius: BorderRadius.circular(radiusOrderCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.brightness == Brightness.dark
              ? [const Color(0xFF1B1A20), const Color(0xFF141318), const Color(0xFF0F0F12)]
              : [Colors.white, const Color(0xFFF7F9FE), const Color(0xFFEEF2FA)],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: p.gold2.withValues(alpha: p.brightness == Brightness.dark ? 0.18 : 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadowDark,
            blurRadius: p.brightness == Brightness.dark ? 30 : 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: p.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: p.gold2.withValues(alpha: p.brightness == Brightness.dark ? 0.08 : 0.1),
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      );
}
