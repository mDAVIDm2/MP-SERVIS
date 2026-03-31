import 'package:flutter/material.dart';

/// Тема AutoHub Business: тёмная, акцент #FF6B00 (как в промпте).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color cardBg = Color(0xFF252525);
  static const Color nestedBg = Color(0xFF2D2D2D);

  static const Color border = Color(0xFF333333);
  static const Color borderLight = Color(0xFF404040);

  /// Акцент бренда Business — оранжевый
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF8533);
  static const Color primaryDark = Color(0xFFE55A00);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF999999);
  static const Color textTertiary = Color(0xFF666666);
  static const Color textPlaceholder = Color(0xFF525252);

  // Статусы заказов (как в клиенте)
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusConfirmed = Color(0xFF3B82F6);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusApproval = Color(0xFFF59E0B);
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusDone = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFFEF4444);

  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const Color navBg = Color(0xFF1A1A1A);
  static const Color navActive = Color(0xFFFF6B00);
  static const Color navInactive = Color(0xFF666666);
}
