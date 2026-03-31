/// Коды вида точки: те же строки, что `business_kind` / `organization_business_kind` в API.
abstract final class OrgBusinessKind {
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

  /// Заказы только с этих точек участвуют в автоподстановке регламентных работ из истории заказов.
  static const Set<String> codesForGarageMaintenanceFromOrders = {
    sto,
    tireService,
    evService,
  };

  static String? normalizeCode(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().toLowerCase().replaceAll('-', '_');
    if (s.isEmpty) return null;
    return s;
  }

  /// Строго: без кода или не из whitelist — не подтягиваем работы в гараж.
  static bool isGarageMaintenanceSource(String? organizationBusinessKind) {
    final k = normalizeCode(organizationBusinessKind);
    if (k == null) return false;
    return codesForGarageMaintenanceFromOrders.contains(k);
  }

  /// Только известные значения; иначе null — не подставляем устаревшие фолбэки.
  static String? normalizeSchedulingMode(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'bay_based' || s == 'staff_based') return s;
    return null;
  }

  static const List<(String code, String label)> _labels = [
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

  /// Подпись вида точки из заказа (без фолбэка «автосервис» для неизвестного кода).
  static String labelForOrderSnapshot(String? code) {
    if (code == null || code.trim().isEmpty) return '';
    final c = code.trim().toLowerCase().replaceAll('-', '_');
    for (final o in _labels) {
      if (o.$1 == c) return o.$2;
    }
    return code.trim();
  }

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
