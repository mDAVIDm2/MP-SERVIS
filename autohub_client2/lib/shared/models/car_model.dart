import '../../core/config/app_config.dart';

enum ReminderType {
  oil,
  brakes,
  antifreeze,
  battery,
  tires,
  osago,
  inspection,
  maintenance,
}

enum ReminderStatus { overdue, upcoming, ok }

/// Режим записи в гараже: владелец или бывший владелец (только просмотр).
enum CarOwnershipMode { owner, former }

class CarReminder {
  final String id;
  final ReminderType type;
  final String title;
  final int currentMileage;
  final int recommendedMileage;
  final ReminderStatus status;
  final String statusText;
  final bool isDismissed;

  const CarReminder({
    required this.id,
    required this.type,
    required this.title,
    required this.currentMileage,
    required this.recommendedMileage,
    required this.status,
    required this.statusText,
    this.isDismissed = false,
  });

  String get icon {
    switch (type) {
      case ReminderType.oil:
        return '🛢';
      case ReminderType.brakes:
        return '🔧';
      case ReminderType.antifreeze:
        return '❄️';
      case ReminderType.battery:
        return '🔋';
      case ReminderType.tires:
        return '🛞';
      case ReminderType.osago:
        return '📄';
      case ReminderType.inspection:
        return '🔍';
      case ReminderType.maintenance:
        return '⚙️';
    }
  }
}

class Car {
  final String id;
  final String brand;
  final String model;
  final String? generation;

  /// Id марки в справочнике БД; null — пользователь ввёл вручную, ожидает подтверждения.
  final int? brandId;

  /// Id модели в справочнике БД; null — введено вручную, ожидает подтверждения.
  final int? modelId;

  /// Id поколения в справочнике БД; null — введено вручную, ожидает подтверждения.
  final int? generationId;
  final int year;
  final String? nickname;
  final String? plateNumber;
  final String? vin;
  final int mileage;
  final String? engineType;
  final String? transmission;
  final String? drivetrain;
  final String? bodyType;
  final String? color;
  final String? photoUrl;
  final List<CarReminder> reminders;

  /// Собрано из истории заказов при пустом локальном гараже (нет id справочника в данных заказа).
  final bool mergedFromOrders;

  final CarOwnershipMode ownershipMode;

  /// Заполнено для [CarOwnershipMode.former] — id передачи в БД.
  final String? serverTransferId;

  const Car({
    required this.id,
    required this.brand,
    required this.model,
    this.generation,
    this.brandId,
    this.modelId,
    this.generationId,
    required this.year,
    this.nickname,
    this.plateNumber,
    this.vin,
    required this.mileage,
    this.engineType,
    this.transmission,
    this.drivetrain,
    this.bodyType,
    this.color,
    this.photoUrl,
    this.reminders = const [],
    this.mergedFromOrders = false,
    this.ownershipMode = CarOwnershipMode.owner,
    this.serverTransferId,
  });

  bool get isFormerOwnerReadonly => ownershipMode == CarOwnershipMode.former;

  /// Только подтверждённые (из БД) данные — для отправки при записи в сервис.
  String get confirmedCarInfo {
    final parts = <String>[];
    if (brandId != null && brand.isNotEmpty) parts.add(brand);
    if (modelId != null && model.isNotEmpty) parts.add(model);
    if (generationId != null && generation != null && generation!.isNotEmpty) {
      parts.add('($generation)');
    }
    if (parts.isEmpty) return 'Автомобиль, $year';
    return '${parts.join(' ')}, $year';
  }

  bool get hasPendingBrand => brandId == null && brand.isNotEmpty;
  bool get hasPendingModel => modelId == null && model.isNotEmpty;
  bool get hasPendingGeneration =>
      generationId == null && generation != null && generation!.isNotEmpty;

  /// Чипы «ожидает разработчиков» — только для ручного ввода марки/модели, не для авто из заказов.
  bool get hasManualReferencePending =>
      !mergedFromOrders && (hasPendingBrand || hasPendingModel || hasPendingGeneration);

  String get displayName {
    final m = model.trim().isEmpty ? '(модель не указана)' : model;
    return generation != null && generation!.trim().isNotEmpty
        ? '$brand $m ($generation)'
        : '$brand $m';
  }

  String get shortDisplayName {
    final y = year.toString();
    final yy = y.length < 2 ? y : y.substring(y.length - 2);
    return "'$yy $brand $model";
  }

  static String? _normalizePhotoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return AppConfig.resolveCarOrOrderPhotoUrl(raw.trim());
  }

  static CarOwnershipMode _parseOwnershipMode(String? raw) {
    if (raw == 'former') return CarOwnershipMode.former;
    return CarOwnershipMode.owner;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'model': model,
    'generation': generation,
    'brandId': brandId,
    'modelId': modelId,
    'generationId': generationId,
    'year': year,
    'nickname': nickname,
    'plateNumber': plateNumber,
    'vin': vin,
    'mileage': mileage,
    'engineType': engineType,
    'transmission': transmission,
    'drivetrain': drivetrain,
    'bodyType': bodyType,
    'color': color,
    'photoUrl': photoUrl,
    'mergedFromOrders': mergedFromOrders,
    'ownershipMode': ownershipMode.name,
    'serverTransferId': serverTransferId,
  };

  static Car fromJson(Map<String, dynamic> m) => Car(
    id: m['id'] as String? ?? '',
    brand: m['brand'] as String? ?? '',
    model: (m['model'] as String?) ?? m['modelName'] as String? ?? '',
    generation: m['generation'] as String?,
    brandId: (m['brandId'] as num?)?.toInt(),
    modelId: (m['modelId'] as num?)?.toInt(),
    generationId: (m['generationId'] as num?)?.toInt(),
    year: (m['year'] as num?)?.toInt() ?? 0,
    nickname: m['nickname'] as String?,
    plateNumber: m['plateNumber'] as String?,
    vin: m['vin'] as String?,
    mileage: (m['mileage'] as num?)?.toInt() ?? 0,
    engineType: m['engineType'] as String?,
    transmission: m['transmission'] as String?,
    drivetrain: m['drivetrain'] as String?,
    bodyType: m['bodyType'] as String? ?? m['body_type'] as String?,
    color: m['color'] as String?,
    photoUrl: _normalizePhotoUrl(m['photoUrl'] as String?),
    mergedFromOrders: m['mergedFromOrders'] == true,
    ownershipMode: _parseOwnershipMode(m['ownershipMode'] as String?),
    serverTransferId: m['serverTransferId'] as String?,
  );

  /// Ответ GET/POST/PATCH `/profile/cars` (snake_case).
  static Car fromProfileApiJson(Map<String, dynamic> m) => Car(
    id: m['id'] as String? ?? '',
    brand: m['brand'] as String? ?? '',
    model: m['model'] as String? ?? '',
    generation: m['generation'] as String?,
    brandId: (m['brand_id'] as num?)?.toInt(),
    modelId: (m['model_id'] as num?)?.toInt(),
    generationId: (m['generation_id'] as num?)?.toInt(),
    year: (m['year'] as num?)?.toInt() ?? 0,
    nickname: m['nickname'] as String?,
    plateNumber: m['plate_number'] as String?,
    vin: m['vin'] as String?,
    mileage: (m['mileage'] as num?)?.toInt() ?? 0,
    engineType: m['engine_type'] as String?,
    transmission: m['transmission'] as String?,
    drivetrain: m['drivetrain'] as String?,
    bodyType: m['body_type'] as String?,
    color: m['color'] as String?,
    photoUrl: _normalizePhotoUrl(m['photo_url'] as String?),
    mergedFromOrders: m['merged_from_orders'] == true,
    ownershipMode: _parseOwnershipMode(m['ownership_mode'] as String?),
    serverTransferId: m['transfer_id'] as String?,
  );
}
