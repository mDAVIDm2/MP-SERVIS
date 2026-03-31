/// Коды совпадают с полем `business_kind` в API организации.
abstract final class OrganizationBusinessKindCodes {
  static const sto = 'sto';
  static const carWash = 'car_wash';
  static const detailing = 'detailing';
  static const carAudio = 'car_audio';
  static const tireService = 'tire_service';
  static const bodyShop = 'body_shop';
  static const glass = 'glass';
  static const tuning = 'tuning';
  static const evService = 'ev_service';
  static const other = 'other';

  /// Пары (код, подпись в настройках организации).
  static const List<(String code, String label)> options = [
    (sto, 'Автосервис'),
    (carWash, 'Автомойка'),
    (detailing, 'Детейлинг'),
    (carAudio, 'Автозвук'),
    (tireService, 'Шиномонтаж'),
    (bodyShop, 'Кузовной ремонт'),
    (glass, 'Автостёкла'),
    (tuning, 'Тюнинг'),
    (evService, 'Сервис электромобилей'),
    (other, 'Другое'),
  ];

  static String normalize(String? raw) {
    final s = (raw ?? sto).trim().toLowerCase().replaceAll('-', '_');
    const known = {
      sto,
      carWash,
      detailing,
      carAudio,
      tireService,
      bodyShop,
      glass,
      tuning,
      evService,
      other,
    };
    return known.contains(s) ? s : sto;
  }

  static String labelForCode(String? code) {
    final c = normalize(code);
    for (final o in options) {
      if (o.$1 == c) return o.$2;
    }
    return 'Автосервис';
  }

  /// Подпись вида точки из снимка заказа: без подстановки `sto` для неизвестного кода.
  static String labelForOrderSnapshot(String? code) {
    if (code == null || code.trim().isEmpty) return '';
    final c = code.trim().toLowerCase().replaceAll('-', '_');
    for (final o in options) {
      if (o.$1 == c) return o.$2;
    }
    return code.trim();
  }

  /// `organization_scheduling_mode` — коротко для списков и сводки.
  static String schedulingModeShortLabel(String? mode) {
    switch (mode?.trim().toLowerCase()) {
      case 'bay_based':
        return 'Окно / пост';
      case 'staff_based':
        return 'К специалисту';
      default:
        return '';
    }
  }
}
