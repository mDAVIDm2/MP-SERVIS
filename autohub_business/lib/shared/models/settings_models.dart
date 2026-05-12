/// Категория услуг (ТО, Кузовной ремонт и т.д.).
class ServiceCategory {
  final String id;
  final String name;
  final int order;

  const ServiceCategory({required this.id, required this.name, this.order = 0});

  ServiceCategory copyWith({String? id, String? name, int? order}) {
    return ServiceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'order': order};

  factory ServiceCategory.fromJson(Map<String, dynamic> j) {
    return ServiceCategory(
      id: j['id'] as String,
      name: j['name'] as String,
      order: j['order'] as int? ?? 0,
    );
  }
}

/// Название «ТО и обслуживание» (единый регистр в справочнике).
const String kToServiceCategoryName = 'ТО и обслуживание';

/// Категории в UI: «ТО и обслуживание» всегда первая, если есть; остальные по [ServiceCategory.order].
List<ServiceCategory> sortedServiceCategoriesForDisplay(List<ServiceCategory> categories) {
  final list = List<ServiceCategory>.from(categories);
  list.sort((a, b) => a.order.compareTo(b.order));
  final idx = list.indexWhere((c) => c.name.trim().toLowerCase() == kToServiceCategoryName.toLowerCase());
  if (idx > 0) {
    final t = list.removeAt(idx);
    list.insert(0, t);
  }
  return list;
}

/// Подпись категории в интерфейсе (регистр для известных шаблонов).
String displayServiceCategoryTitle(String name) {
  final t = name.trim();
  if (t.toLowerCase() == 'двигатель') return 'Двигатель';
  return name;
}

/// Услуга (позиция с ценой и длительностью).
class ServiceItem {
  final String id;
  final String categoryId;
  final String name;
  final int priceKopecks;
  final int durationMinutes;

  /// Требуемый навык мастера: MAINTENANCE, ENGINE, ELECTRICAL, DIAGNOSTICS, SUSPENSION, TIRES, BODY.
  final String? requiredSkill;

  /// Id позиции из единого справочника MP-Servis (`GET /reference/service-catalog`).
  final String? catalogItemId;

  /// Включить отдельные цену/длительность по типу кузова.
  final bool useBodyTypePricing;

  /// Тарифы по типам кузова для услуги (если [useBodyTypePricing] == true).
  final List<ServiceBodyTypePricing> bodyTypePricing;

  const ServiceItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceKopecks,
    this.durationMinutes = 60,
    this.requiredSkill,
    this.catalogItemId,
    this.useBodyTypePricing = false,
    this.bodyTypePricing = const [],
  });

  bool get isFromCatalog => catalogItemId != null && catalogItemId!.isNotEmpty;

  ServiceItem copyWith({
    String? id,
    String? categoryId,
    String? name,
    int? priceKopecks,
    int? durationMinutes,
    String? requiredSkill,
    String? catalogItemId,
    bool? useBodyTypePricing,
    List<ServiceBodyTypePricing>? bodyTypePricing,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      priceKopecks: priceKopecks ?? this.priceKopecks,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      requiredSkill: requiredSkill ?? this.requiredSkill,
      catalogItemId: catalogItemId ?? this.catalogItemId,
      useBodyTypePricing: useBodyTypePricing ?? this.useBodyTypePricing,
      bodyTypePricing: bodyTypePricing ?? this.bodyTypePricing,
    );
  }

  ServiceBodyTypePricing? pricingForBodyType(String? bodyType) {
    if (!useBodyTypePricing || bodyType == null || bodyType.trim().isEmpty) {
      return null;
    }
    final normalized = bodyType.trim().toLowerCase();
    for (final p in bodyTypePricing) {
      if (p.bodyType.trim().toLowerCase() == normalized) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'name': name,
    'priceKopecks': priceKopecks,
    'durationMinutes': durationMinutes,
    if (requiredSkill != null) 'required_skill': requiredSkill,
    if (catalogItemId != null && catalogItemId!.isNotEmpty)
      'catalog_item_id': catalogItemId,
    'use_body_type_pricing': useBodyTypePricing,
    if (bodyTypePricing.isNotEmpty)
      'body_type_pricing': bodyTypePricing.map((e) => e.toJson()).toList(),
  };

  factory ServiceItem.fromJson(Map<String, dynamic> j) {
    return ServiceItem(
      id: j['id'] as String,
      categoryId: j['category_id'] as String? ?? j['categoryId'] as String,
      name: j['name'] as String,
      priceKopecks: j['price_kopecks'] as int? ?? j['priceKopecks'] as int,
      durationMinutes:
          j['duration_minutes'] as int? ?? j['durationMinutes'] as int? ?? 60,
      requiredSkill: j['required_skill'] as String?,
      catalogItemId:
          j['catalog_item_id'] as String? ?? j['catalogItemId'] as String?,
      useBodyTypePricing:
          j['use_body_type_pricing'] as bool? ??
          j['useBodyTypePricing'] as bool? ??
          false,
      bodyTypePricing:
          ((j['body_type_pricing'] as List<dynamic>?) ??
                  (j['bodyTypePricing'] as List<dynamic>?) ??
                  const [])
              .whereType<Map<String, dynamic>>()
              .map(ServiceBodyTypePricing.fromJson)
              .toList(),
    );
  }
}

class ServiceBodyTypePricing {
  final String bodyType;
  final int priceKopecks;
  final int durationMinutes;

  const ServiceBodyTypePricing({
    required this.bodyType,
    required this.priceKopecks,
    required this.durationMinutes,
  });

  ServiceBodyTypePricing copyWith({
    String? bodyType,
    int? priceKopecks,
    int? durationMinutes,
  }) {
    return ServiceBodyTypePricing(
      bodyType: bodyType ?? this.bodyType,
      priceKopecks: priceKopecks ?? this.priceKopecks,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'body_type': bodyType,
    'price_kopecks': priceKopecks,
    'duration_minutes': durationMinutes,
  };

  factory ServiceBodyTypePricing.fromJson(Map<String, dynamic> j) {
    return ServiceBodyTypePricing(
      bodyType: j['body_type'] as String? ?? j['bodyType'] as String? ?? '',
      priceKopecks:
          j['price_kopecks'] as int? ?? j['priceKopecks'] as int? ?? 0,
      durationMinutes:
          j['duration_minutes'] as int? ?? j['durationMinutes'] as int? ?? 60,
    );
  }
}

class ServicePackageAddon {
  final String serviceId;

  /// Наценка за услугу при выборе в пакете (может быть 0).
  final int extraPriceKopecks;

  /// Доп. время при добавлении к комплексу; `0` — взять длительность из карточки услуги.
  final int extraDurationMinutes;

  const ServicePackageAddon({
    required this.serviceId,
    this.extraPriceKopecks = 0,
    this.extraDurationMinutes = 0,
  });

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    'extra_price_kopecks': extraPriceKopecks,
    if (extraDurationMinutes > 0) 'extra_duration_minutes': extraDurationMinutes,
  };

  factory ServicePackageAddon.fromJson(Map<String, dynamic> j) {
    return ServicePackageAddon(
      serviceId: j['service_id'] as String? ?? j['serviceId'] as String? ?? '',
      extraPriceKopecks:
          j['extra_price_kopecks'] as int? ??
          j['extraPriceKopecks'] as int? ??
          0,
      extraDurationMinutes:
          j['extra_duration_minutes'] as int? ??
          j['extraDurationMinutes'] as int? ??
          0,
    );
  }
}

class ServicePackage {
  final String id;
  final String name;
  final String categoryId;
  final int packagePriceKopecks;
  final List<String> includedServiceIds;
  final List<ServicePackageAddon> addons;

  /// Длительность комплекса в минутах. `0` — в интерфейсе считается как сумма длительностей входящих услуг.
  final int packageDurationMinutes;

  const ServicePackage({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.packagePriceKopecks,
    this.includedServiceIds = const [],
    this.addons = const [],
    this.packageDurationMinutes = 0,
  });

  ServicePackage copyWith({
    String? id,
    String? name,
    String? categoryId,
    int? packagePriceKopecks,
    List<String>? includedServiceIds,
    List<ServicePackageAddon>? addons,
    int? packageDurationMinutes,
  }) {
    return ServicePackage(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      packagePriceKopecks: packagePriceKopecks ?? this.packagePriceKopecks,
      includedServiceIds: includedServiceIds ?? this.includedServiceIds,
      addons: addons ?? this.addons,
      packageDurationMinutes: packageDurationMinutes ?? this.packageDurationMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category_id': categoryId,
    'package_price_kopecks': packagePriceKopecks,
    'included_service_ids': includedServiceIds,
    'addons': addons.map((e) => e.toJson()).toList(),
    if (packageDurationMinutes > 0) 'package_duration_minutes': packageDurationMinutes,
  };

  factory ServicePackage.fromJson(Map<String, dynamic> j) {
    return ServicePackage(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      categoryId:
          j['category_id'] as String? ?? j['categoryId'] as String? ?? '',
      packagePriceKopecks:
          j['package_price_kopecks'] as int? ??
          j['packagePriceKopecks'] as int? ??
          0,
      includedServiceIds:
          ((j['included_service_ids'] as List<dynamic>?) ??
                  (j['includedServiceIds'] as List<dynamic>?) ??
                  const [])
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList(),
      addons: ((j['addons'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ServicePackageAddon.fromJson)
          .toList(),
      packageDurationMinutes:
          j['package_duration_minutes'] as int? ??
          j['packageDurationMinutes'] as int? ??
          0,
    );
  }
}

/// Именованный пост/бокс (мойка, шиномонтаж). В API: `slots.bays`.
class ServiceBay {
  final String id;
  final String name;

  const ServiceBay({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ServiceBay.fromJson(Map<String, dynamic> j) {
    return ServiceBay(
      id: j['id']?.toString() ?? '',
      name: (j['name']?.toString() ?? 'Пост').trim().isEmpty
          ? 'Пост'
          : (j['name']?.toString() ?? 'Пост'),
    );
  }
}

/// Слоты и таймаут подтверждения записи.
/// [workDayStart] и [workDayEnd] — границы рабочего дня в формате "HH:mm" (например "09:00", "20:00").
/// Ячейки расписания и записи строятся от начала до конца дня (последняя ячейка — за 30 мин до конца).
class SlotsSettings {
  final int slotDurationMinutes;
  final int confirmationTimeoutMinutes;

  /// Начало рабочего дня организации, формат "HH:mm".
  final String workDayStart;

  /// Конец рабочего дня организации, формат "HH:mm" (последняя ячейка будет за 30 мин до этого времени).
  final String workDayEnd;

  /// Если нет [bays], используется `bay_count` на бэкенде (1–20).
  final int bayCount;

  /// Именованные посты; если не пусто, ёмкость записи по времени = числу постов.
  final List<ServiceBay> bays;

  const SlotsSettings({
    this.slotDurationMinutes = 60,
    this.confirmationTimeoutMinutes = 120,
    this.workDayStart = '09:00',
    this.workDayEnd = '20:00',
    this.bayCount = 3,
    this.bays = const [],
  });

  bool get hasNamedBays => bays.isNotEmpty;

  SlotsSettings copyWith({
    int? slotDurationMinutes,
    int? confirmationTimeoutMinutes,
    String? workDayStart,
    String? workDayEnd,
    int? bayCount,
    List<ServiceBay>? bays,
  }) {
    return SlotsSettings(
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      confirmationTimeoutMinutes:
          confirmationTimeoutMinutes ?? this.confirmationTimeoutMinutes,
      workDayStart: workDayStart ?? this.workDayStart,
      workDayEnd: workDayEnd ?? this.workDayEnd,
      bayCount: bayCount ?? this.bayCount,
      bays: bays ?? this.bays,
    );
  }

  Map<String, dynamic> toJson() => {
    'slotDurationMinutes': slotDurationMinutes,
    'confirmationTimeoutMinutes': confirmationTimeoutMinutes,
    'workDayStart': workDayStart,
    'workDayEnd': workDayEnd,
    'bayCount': bayCount,
    'bays': bays.map((e) => e.toJson()).toList(),
  };

  /// Часы начала рабочего дня (0..23).
  int get startHour {
    final parts = workDayStart.split(':');
    if (parts.isEmpty) return 9;
    return int.tryParse(parts[0]) ?? 9;
  }

  /// Минуты начала (0 или 30).
  int get startMinute {
    final parts = workDayStart.split(':');
    if (parts.length < 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  /// Часы окончания рабочего дня (например 20 для "20:00", 22 для "22:00").
  int get endHour {
    final parts = workDayEnd.split(':');
    if (parts.isEmpty) return 20;
    return int.tryParse(parts[0]) ?? 20;
  }

  /// Минуты окончания.
  int get endMinute {
    final parts = workDayEnd.split(':');
    if (parts.length < 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  factory SlotsSettings.fromJson(Map<String, dynamic> j) {
    final baysRaw = j['bays'] as List<dynamic>?;
    final bays = baysRaw == null
        ? const <ServiceBay>[]
        : baysRaw
              .whereType<Map<String, dynamic>>()
              .map(ServiceBay.fromJson)
              .where((b) => b.id.isNotEmpty)
              .toList();
    final bc = j['bay_count'] as int? ?? j['bayCount'] as int?;
    return SlotsSettings(
      slotDurationMinutes:
          j['slot_duration_minutes'] as int? ??
          j['slotDurationMinutes'] as int? ??
          60,
      confirmationTimeoutMinutes:
          j['confirmation_timeout_minutes'] as int? ??
          j['confirmationTimeoutMinutes'] as int? ??
          120,
      workDayStart:
          j['work_day_start'] as String? ??
          j['workDayStart'] as String? ??
          '09:00',
      workDayEnd:
          j['work_day_end'] as String? ?? j['workDayEnd'] as String? ?? '20:00',
      bayCount: bc ?? 3,
      bays: bays,
    );
  }
}

/// Уведомления (включено/выключено по типам).
class NotificationSettings {
  final bool newOrder;
  final bool newMessage;
  final bool approvalResponse;
  final bool orderReminder;

  const NotificationSettings({
    this.newOrder = true,
    this.newMessage = true,
    this.approvalResponse = true,
    this.orderReminder = true,
  });

  NotificationSettings copyWith({
    bool? newOrder,
    bool? newMessage,
    bool? approvalResponse,
    bool? orderReminder,
  }) {
    return NotificationSettings(
      newOrder: newOrder ?? this.newOrder,
      newMessage: newMessage ?? this.newMessage,
      approvalResponse: approvalResponse ?? this.approvalResponse,
      orderReminder: orderReminder ?? this.orderReminder,
    );
  }

  Map<String, dynamic> toJson() => {
    'newOrder': newOrder,
    'newMessage': newMessage,
    'approvalResponse': approvalResponse,
    'orderReminder': orderReminder,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> j) {
    return NotificationSettings(
      newOrder: j['new_order'] as bool? ?? j['newOrder'] as bool? ?? true,
      newMessage: j['new_message'] as bool? ?? j['newMessage'] as bool? ?? true,
      approvalResponse:
          j['approval_response'] as bool? ??
          j['approvalResponse'] as bool? ??
          true,
      orderReminder:
          j['order_reminder'] as bool? ?? j['orderReminder'] as bool? ?? true,
    );
  }
}

/// Шаблон сообщения для чата.
class MessageTemplate {
  final String id;
  final String title;
  final String body;

  const MessageTemplate({
    required this.id,
    required this.title,
    required this.body,
  });

  MessageTemplate copyWith({String? id, String? title, String? body}) {
    return MessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};

  factory MessageTemplate.fromJson(Map<String, dynamic> j) {
    return MessageTemplate(
      id: j['id'] as String,
      title: j['title'] as String,
      body: j['body'] as String,
    );
  }
}

/// Состояние настроек организации (категории, услуги, слоты, шаблоны и т.д.).
class SettingsState {
  final List<ServiceCategory> categories;
  final List<ServiceItem> services;
  final List<ServicePackage> packages;
  final List<String> carBrands;
  /// Id из единого справочника [StoAmenityCatalog] (см. `sto_amenity_catalog.dart`).
  final List<String> amenityIds;
  /// Текст «О сервисе» для карточки в клиентском приложении.
  final String publicDescription;
  final SlotsSettings slotsSettings;
  final NotificationSettings notificationSettings;
  final List<MessageTemplate> messageTemplates;

  SettingsState({
    this.categories = const [],
    this.services = const [],
    this.packages = const [],
    this.carBrands = const [],
    this.amenityIds = const [],
    this.publicDescription = '',
    SlotsSettings? slotsSettings,
    NotificationSettings? notificationSettings,
    this.messageTemplates = const [],
  }) : slotsSettings = slotsSettings ?? const SlotsSettings(),
       notificationSettings =
           notificationSettings ?? const NotificationSettings();

  SettingsState copyWith({
    List<ServiceCategory>? categories,
    List<ServiceItem>? services,
    List<ServicePackage>? packages,
    List<String>? carBrands,
    List<String>? amenityIds,
    String? publicDescription,
    SlotsSettings? slotsSettings,
    NotificationSettings? notificationSettings,
    List<MessageTemplate>? messageTemplates,
  }) {
    return SettingsState(
      categories: categories ?? this.categories,
      services: services ?? this.services,
      packages: packages ?? this.packages,
      carBrands: carBrands ?? this.carBrands,
      amenityIds: amenityIds ?? this.amenityIds,
      publicDescription: publicDescription ?? this.publicDescription,
      slotsSettings: slotsSettings ?? this.slotsSettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      messageTemplates: messageTemplates ?? this.messageTemplates,
    );
  }
}
