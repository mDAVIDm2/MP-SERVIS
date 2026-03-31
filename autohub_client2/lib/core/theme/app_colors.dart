import 'package:flutter/material.dart';

/// Премиальная тёмная палитра: графит, тёплое золото, мягкие тексты.
class AppColors {
  AppColors._();

  // --- Фон (не чисто чёрный, тёмный графит) ---
  static const Color bgPrimary = Color(0xFF070707);
  static const Color bgSecondary = Color(0xFF0D0D10);
  static const Color bgElevated = Color(0xFF121216);
  static const Color bgCard = Color(0xFF16151A);
  static const Color bgCard2 = Color(0xFF1A181D);

  // Обратная совместимость
  static const Color background = bgPrimary;
  static const Color surface = bgSecondary;
  static const Color cardBg = bgCard;
  static const Color cardElevated = bgElevated;
  static const Color nestedBg = Color(0xFF1F1F24);
  static const Color hoverBg = Color(0xFF2A2A30);

  // --- Тёплое золото / шампань ---
  static const Color gold1 = Color(0xFFF6D58A);
  static const Color gold2 = Color(0xFFD9A441);
  static const Color gold3 = Color(0xFFB9781E);
  static const Color gold4 = Color(0xFF7A5318);

  static const Color primary = gold1;
  static const Color primaryLight = gold1;
  static const Color primaryDark = gold3;
  static const Color primaryMuted = gold2;

  // --- Текст (уровни контраста) ---
  static const Color textPrimary = Color(0xFFF5F2EA);
  static const Color textSecondary = Color(0xFFB8B1A5);
  static const Color textMuted = Color(0xFF7F7A72);
  static const Color textTertiary = textMuted;
  static const Color textPlaceholder = Color(0xFF5C5852);

  // --- Статусы ---
  static const Color success = Color(0xFF79D98A);
  static Color get successBg => success.withValues(alpha: 0.14);

  static const Color warning = Color(0xFFE7B450);
  static Color get warningBg => warning.withValues(alpha: 0.14);

  // --- Бордеры / свечения ---
  static Color get strokeSoft => Colors.white.withValues(alpha: 0.08);
  static Color get strokeGold => gold1.withValues(alpha: 0.22);
  static Color get glowGold => gold2.withValues(alpha: 0.18);
  static const Color shadowDark = Color(0x8C000000); // rgba(0,0,0,0.55)

  // Рамки (обратная совместимость)
  static const Color border = Color(0xFF2A282D);
  static const Color borderLight = Color(0xFF3D3A40);

  // --- Статусы заказов (премиальные оттенки) ---
  static const Color statusPending = Color(0xFFE7B450);
  static const Color statusConfirmed = Color(0xFF79D98A);
  static const Color statusInProgress = Color(0xFF6BB3E8);
  static const Color statusApproval = Color(0xFFE7B450);
  static const Color statusCompleted = Color(0xFF79D98A);
  static const Color statusDone = Color(0xFF79D98A);
  static const Color statusCancelled = Color(0xFFE87A6B);

  // Семантические
  static const Color error = Color(0xFFE87A6B);
  static const Color info = Color(0xFF6BB3E8);

  // Навигация
  static const Color navBg = bgSecondary;
  static const Color navActive = gold1;
  static const Color navInactive = textMuted;

  // Карта маркеры
  static const Color markerSTO = success;
  static const Color markerWash = info;
  static const Color markerDetailing = Color(0xFFA78BFA);
  static const Color markerTire = warning;
  static const Color markerBody = error;
  static const Color markerOther = textMuted;

  // --- Градиенты (премиальный перелив) ---
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [gold1, gold2, gold3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get cardGradient => const LinearGradient(
        colors: [bgCard, bgCard2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get goldShine => LinearGradient(
        begin: const Alignment(-0.8, -0.6),
        end: const Alignment(0.8, 0.6),
        colors: [
          gold2.withValues(alpha: 0),
          gold2.withValues(alpha: 0.12),
          gold2.withValues(alpha: 0),
        ],
      );

  // --- Тени ---
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get goldGlow => [
        BoxShadow(
          color: gold2.withValues(alpha: 0.25),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];
}
