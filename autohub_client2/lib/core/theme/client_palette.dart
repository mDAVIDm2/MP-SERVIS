import 'package:flutter/material.dart';

/// Семантические цвета, одинаковые в обеих темах (статусы заказов, маркеры).
abstract final class SemanticColors {
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1E88E5);
  static const Color statusPending = Color(0xFFF9A825);
  static const Color statusConfirmed = Color(0xFF43A047);
  static const Color statusInProgress = Color(0xFF1E88E5);
  static const Color statusApproval = Color(0xFFF9A825);
  static const Color statusCompleted = Color(0xFF43A047);
  static const Color statusDone = Color(0xFF43A047);
  static const Color statusCancelled = Color(0xFFD32F2F);
  static const Color markerSTO = statusConfirmed;
  static const Color markerWash = info;
  static const Color markerDetailing = Color(0xFF7E57C2);
  static const Color markerTire = warning;
  static const Color markerBody = error;
  static const Color markerOther = Color(0xFF78909C);
}

/// Палитра клиентского приложения: тёмная (золото) и светлая (белый фон, синий акцент).
@immutable
class ClientPalette extends ThemeExtension<ClientPalette> {
  const ClientPalette({
    required this.brightness,
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgElevated,
    required this.bgCard,
    required this.bgCard2,
    required this.nestedBg,
    required this.hoverBg,
    required this.gold1,
    required this.gold2,
    required this.gold3,
    required this.gold4,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textPlaceholder,
    required this.border,
    required this.borderLight,
    required this.strokeSoft,
    required this.shadowDark,
    required this.navBg,
    required this.navActive,
    required this.navInactive,
    required this.onAccent,
    required this.chipSelectedForeground,
  });

  final Brightness brightness;

  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgElevated;
  final Color bgCard;
  final Color bgCard2;
  final Color nestedBg;
  final Color hoverBg;

  /// Акцент: золото (тёмная тема) или синий (светлая).
  final Color gold1;
  final Color gold2;
  final Color gold3;
  final Color gold4;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textPlaceholder;

  final Color border;
  final Color borderLight;

  /// Линии / разделители.
  final Color strokeSoft;

  final Color shadowDark;

  final Color navBg;
  final Color navActive;
  final Color navInactive;

  /// Текст и индикаторы на градиентной кнопке (CTA).
  final Color onAccent;

  /// Текст на выбранном chip с заливкой primary.
  final Color chipSelectedForeground;

  // --- Алиасы (как в старом AppColors) ---
  Color get background => bgPrimary;
  Color get surface => bgSecondary;
  Color get cardBg => bgCard;
  Color get cardElevated => bgElevated;
  Color get primary => gold1;
  Color get primaryLight => gold1;
  Color get primaryDark => gold3;
  Color get primaryMuted => gold2;

  Color get textTertiary => textMuted;

  Color get success => SemanticColors.success;
  Color get warning => SemanticColors.warning;
  Color get error => SemanticColors.error;
  Color get info => SemanticColors.info;

  Color get successBg => success.withValues(alpha: 0.14);
  Color get warningBg => warning.withValues(alpha: 0.14);

  Color get strokeGold => gold2.withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.35);

  Color get glowGold => gold2.withValues(alpha: brightness == Brightness.dark ? 0.18 : 0.12);

  Color get statusPending => SemanticColors.statusPending;
  Color get statusConfirmed => SemanticColors.statusConfirmed;
  Color get statusInProgress => SemanticColors.statusInProgress;
  Color get statusApproval => SemanticColors.statusApproval;
  Color get statusCompleted => SemanticColors.statusCompleted;
  Color get statusDone => SemanticColors.statusDone;
  Color get statusCancelled => SemanticColors.statusCancelled;

  Color get markerSTO => SemanticColors.markerSTO;
  Color get markerWash => SemanticColors.markerWash;
  Color get markerDetailing => SemanticColors.markerDetailing;
  Color get markerTire => SemanticColors.markerTire;
  Color get markerBody => SemanticColors.markerBody;
  Color get markerOther => SemanticColors.markerOther;

  LinearGradient get primaryGradient => LinearGradient(
        colors: [gold1, gold2, gold3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get cardGradient => LinearGradient(
        colors: brightness == Brightness.dark
            ? [bgCard, bgCard2]
            : [Colors.white, const Color(0xFFF0F4FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get goldShine => LinearGradient(
        begin: const Alignment(-0.8, -0.6),
        end: const Alignment(0.8, 0.6),
        colors: [
          gold2.withValues(alpha: 0),
          gold2.withValues(alpha: brightness == Brightness.dark ? 0.12 : 0.08),
          gold2.withValues(alpha: 0),
        ],
      );

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.07),
          blurRadius: brightness == Brightness.dark ? 20 : 16,
          offset: const Offset(0, 8),
        ),
      ];

  List<BoxShadow> get goldGlow => [
        BoxShadow(
          color: gold2.withValues(alpha: brightness == Brightness.dark ? 0.25 : 0.2),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  static const ClientPalette dark = ClientPalette(
    brightness: Brightness.dark,
    bgPrimary: Color(0xFF070707),
    bgSecondary: Color(0xFF0D0D10),
    bgElevated: Color(0xFF121216),
    bgCard: Color(0xFF16151A),
    bgCard2: Color(0xFF1A181D),
    nestedBg: Color(0xFF1F1F24),
    hoverBg: Color(0xFF2A2A30),
    gold1: Color(0xFFF6D58A),
    gold2: Color(0xFFD9A441),
    gold3: Color(0xFFB9781E),
    gold4: Color(0xFF7A5318),
    textPrimary: Color(0xFFF5F2EA),
    textSecondary: Color(0xFFB8B1A5),
    textMuted: Color(0xFF7F7A72),
    textPlaceholder: Color(0xFF5C5852),
    border: Color(0xFF2A282D),
    borderLight: Color(0xFF3D3A40),
    strokeSoft: Color(0x14FFFFFF),
    shadowDark: Color(0x8C000000),
    navBg: Color(0xFF0D0D10),
    navActive: Color(0xFFF6D58A),
    navInactive: Color(0xFF7F7A72),
    onAccent: Color(0xFF18181B),
    chipSelectedForeground: Color(0xFF18181B),
  );

  /// Светлая тема: белый/светло-серый фон, синий акцент, тёмный текст.
  static const ClientPalette light = ClientPalette(
    brightness: Brightness.light,
    bgPrimary: Color(0xFFFFFFFF),
    bgSecondary: Color(0xFFF5F7FB),
    bgElevated: Color(0xFFEFF2F8),
    bgCard: Color(0xFFFFFFFF),
    bgCard2: Color(0xFFF0F4FC),
    nestedBg: Color(0xFFF1F5F9),
    hoverBg: Color(0xFFE2E8F0),
    gold1: Color(0xFF1565C0),
    gold2: Color(0xFF1976D2),
    gold3: Color(0xFF0D47A1),
    gold4: Color(0xFF082952),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    textPlaceholder: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    borderLight: Color(0xFFCBD5E1),
    strokeSoft: Color(0x14000000),
    shadowDark: Color(0x14000000),
    navBg: Color(0xFFFFFFFF),
    navActive: Color(0xFF1565C0),
    navInactive: Color(0xFF64748B),
    onAccent: Color(0xFFFFFFFF),
    chipSelectedForeground: Color(0xFFFFFFFF),
  );

  @override
  ClientPalette copyWith({
    Brightness? brightness,
    Color? bgPrimary,
    Color? gold1,
  }) {
    return ClientPalette(
      brightness: brightness ?? this.brightness,
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary,
      bgElevated: bgElevated,
      bgCard: bgCard,
      bgCard2: bgCard2,
      nestedBg: nestedBg,
      hoverBg: hoverBg,
      gold1: gold1 ?? this.gold1,
      gold2: gold2,
      gold3: gold3,
      gold4: gold4,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      textPlaceholder: textPlaceholder,
      border: border,
      borderLight: borderLight,
      strokeSoft: strokeSoft,
      shadowDark: shadowDark,
      navBg: navBg,
      navActive: navActive,
      navInactive: navInactive,
      onAccent: onAccent,
      chipSelectedForeground: chipSelectedForeground,
    );
  }

  @override
  ThemeExtension<ClientPalette> lerp(ThemeExtension<ClientPalette>? other, double t) {
    if (other is! ClientPalette) return this;
    if (t < 0.5) return this;
    return other;
  }
}

extension ClientPaletteContext on BuildContext {
  ClientPalette get palette {
    final p = Theme.of(this).extension<ClientPalette>();
    return p ?? ClientPalette.dark;
  }
}
