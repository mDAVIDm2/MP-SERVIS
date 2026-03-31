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
  });

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

  String get displayName {
    final m = model.trim().isEmpty ? '(модель не указана)' : model;
    return generation != null && generation!.trim().isNotEmpty
        ? '$brand $m ($generation)'
        : '$brand $m';
  }

  String get shortDisplayName =>
      "'${year.toString().substring(2)} $brand $model";

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
    photoUrl: m['photoUrl'] as String?,
  );
}
