/// Локальный черновик создания заказа (не на сервере). Источник: [kSourceQuick] или [kSourceCalendar].
class OrderCreationDraft {
  OrderCreationDraft({
    required this.id,
    required this.source,
    required this.updatedAt,
    required this.data,
  });

  static const kSourceQuick = 'quick';
  static const kSourceCalendar = 'calendar';

  final String id;
  /// [kSourceQuick] | [kSourceCalendar]
  final String source;
  final DateTime updatedAt;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'updatedAt': updatedAt.toIso8601String(),
        'data': data,
      };

  factory OrderCreationDraft.fromJson(Map<String, dynamic> j) {
    return OrderCreationDraft(
      id: j['id'] as String? ?? '',
      source: j['source'] as String? ?? kSourceQuick,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      data: Map<String, dynamic>.from(j['data'] as Map? ?? {}),
    );
  }

  /// Краткая строка для списка черновиков.
  String get previewSubtitle {
    if (source == kSourceCalendar) {
      final n = (data['clientName'] as String?)?.trim() ?? '';
      final car = (data['carInfo'] as String?)?.trim() ?? '';
      final parts = <String>[];
      if (n.isNotEmpty) parts.add(n);
      if (car.isNotEmpty) parts.add(car);
      return parts.isEmpty ? 'Без клиента' : parts.join(' • ');
    }
    final n = (data['clientName'] as String?)?.trim() ?? '';
    final car = data['selectedCar'] is Map
        ? ((data['selectedCar'] as Map)['carInfo'] as String?)?.trim() ?? ''
        : '';
    final free = (data['carInfoFree'] as String?)?.trim() ?? '';
    final carLine = car.isNotEmpty ? car : free;
    final parts = <String>[];
    if (n.isNotEmpty) parts.add(n);
    if (carLine.isNotEmpty) parts.add(carLine);
    return parts.isEmpty ? 'Без клиента' : parts.join(' • ');
  }

  String get previewMeta {
    final dtStr = data['dateTime'] as String?;
    final dt = dtStr != null ? DateTime.tryParse(dtStr) : null;
    final dateLabel = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
    int services = 0;
    int customs = 0;
    if (data['selectedServiceIds'] is List) {
      services = (data['selectedServiceIds'] as List).length;
    }
    if (data['customItems'] is List) {
      customs = (data['customItems'] as List).length;
    }
    final nLines = services + customs;
    final lines = nLines > 0 ? '$nLines поз.' : 'без работ';
    if (dateLabel.isEmpty) return lines;
    return '$dateLabel · $lines';
  }

  String get sourceLabel => source == kSourceCalendar ? 'Календарь' : 'Быстрая запись';
}
