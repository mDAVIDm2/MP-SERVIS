import 'package:flutter/material.dart';

/// Светлая тема для desktop-приложения Business (по спецификации из docs).
/// Чистый, корпоративный, премиальный стиль.
class AppColorsDesktop {
  AppColorsDesktop._();

  /// Единая светлая тема desktop: фон, карточки, разделители.
  static const Color background = Color(0xFFF2F3F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color nestedBg = Color(0xFFEBEEF2);

  static const Color border = Color(0xFFE2E4E8);
  static const Color borderLight = Color(0xFFECEEF1);

  /// Основной акцент — глубокий синий
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryLight = Color(0xFF2C5282);
  static const Color primaryDark = Color(0xFF0F2744);

  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF5C6370);
  static const Color textTertiary = Color(0xFF8B929E);
  static const Color textPlaceholder = Color(0xFFB8BEC8);

  // Статусы заказов: читаемые, не кислотные (ТЗ п.2.3)
  /// Подтверждён — мягкий синий
  static const Color statusConfirmed = Color(0xFF2563EB);
  /// Требует согласования — мягкий оранжевый
  static const Color statusApproval = Color(0xFFEA580C);
  /// В работе — насыщенный синий
  static const Color statusInProgress = Color(0xFF1D4ED8);
  /// Готов к выдаче / Завершён — зелёный
  static const Color statusCompleted = Color(0xFF059669);
  static const Color statusDone = Color(0xFF047857);
  /// Ожидает подтверждения — янтарный
  static const Color statusPending = Color(0xFFD97706);
  /// Отменён — красный, но сдержанный
  static const Color statusCancelled = Color(0xFFB91C1C);
  static const Color statusConflict = Color(0xFFDC2626);

  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  static const Color navBg = Color(0xFFFFFFFF);
  static const Color navActive = Color(0xFF1E3A5F);
  static const Color navInactive = Color(0xFF6B7280);
  static const Color navHover = Color(0xFFF3F4F6);

  /// Оранжевый только для денег, итогов, важных CTA (по ТЗ).
  static const Color accentMoney = Color(0xFFEA580C);
  static const Color accentMoneyLight = Color(0xFFFFF7ED);
}
