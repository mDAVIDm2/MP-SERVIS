import '../../core/utils/formatters.dart';

/// Подходит ли точка под марку авто по полю «марки в работе» ([STO.specializations] / `car_brands` с сервера).
/// Пустой список = принимают все марки. Сравнение без учёта регистра и крайних пробелов.
bool stoMatchesCarBrand(List<String> specializations, String carBrand) {
  if (specializations.isEmpty) return true;
  final b = carBrand.trim().toLowerCase();
  if (b.isEmpty) return true;
  for (final s in specializations) {
    if (s.trim().toLowerCase() == b) return true;
  }
  return false;
}

class STOService {
  final String id;
  final String name;
  final String category;
  final int priceKopecks;
  final int durationMinutes;

  /// Требуемый навык мастера (MAINTENANCE, ENGINE, ELECTRICAL, DIAGNOSTICS, SUSPENSION, TIRES, BODY).
  final String? requiredSkill;
  final bool useBodyTypePricing;
  final List<STOServiceBodyPricing> bodyTypePricing;

  const STOService({
    required this.id,
    required this.name,
    required this.category,
    required this.priceKopecks,
    this.durationMinutes = 60,
    this.requiredSkill,
    this.useBodyTypePricing = false,
    this.bodyTypePricing = const [],
  });

  /// Форматированное время: "20 мин", "1:15 ч", "2 дн" …
  String get durationLabel => Formatters.durationMinutes(durationMinutes);

  STOServiceBodyPricing? pricingForBodyType(String? bodyType) {
    if (!useBodyTypePricing || bodyType == null || bodyType.trim().isEmpty)
      return null;
    final normalized = bodyType.trim().toLowerCase();
    for (final p in bodyTypePricing) {
      if (p.bodyType.trim().toLowerCase() == normalized) return p;
    }
    return null;
  }

  int effectivePriceKopecks(String? bodyType) =>
      pricingForBodyType(bodyType)?.priceKopecks ?? priceKopecks;

  int effectiveDurationMinutes(String? bodyType) =>
      pricingForBodyType(bodyType)?.durationMinutes ?? durationMinutes;
}

class STOServiceBodyPricing {
  final String bodyType;
  final int priceKopecks;
  final int durationMinutes;

  const STOServiceBodyPricing({
    required this.bodyType,
    required this.priceKopecks,
    required this.durationMinutes,
  });
}

class STOPackageAddon {
  final String serviceId;
  final int extraPriceKopecks;

  const STOPackageAddon({required this.serviceId, this.extraPriceKopecks = 0});
}

class STOPackage {
  final String id;
  final String name;
  final String categoryId;
  final int packagePriceKopecks;
  final List<String> includedServiceIds;
  final List<STOPackageAddon> addons;

  const STOPackage({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.packagePriceKopecks,
    this.includedServiceIds = const [],
    this.addons = const [],
  });
}

class STO {
  final String id;
  final String name;
  final String address;
  final String? phone;

  /// Несколько номеров для выбора перед звонком (если null — используется [phone])
  final List<String>? phones;
  final double rating;
  final int reviewCount;
  final double? distanceKm;
  final bool isOpen;
  final String? workingHours;
  final List<String> specializations;
  final String? logoUrl;
  final List<String> photoUrls;
  final bool isFavorite;
  final String? minPrice;

  /// Координаты для отображения на карте (опционально)
  final double? latitude;
  final double? longitude;

  /// Код типа организации с API (`business_kind`): sto, car_wash, …
  final String businessKindCode;

  /// Подпись для UI (например «Мойка»).
  final String businessKindLabel;

  /// Режим записи с API (`scheduling_mode`): staff_based | bay_based.
  final String schedulingMode;

  /// Типы сервиса для фильтра в поиске (чипы, совместимость).
  final List<String> types;

  /// ID услуг, которые оказывает точка (из каталога). Для фильтра по услугам.
  final List<String> serviceIds;

  /// Услуги точки с ценами и временем (для расчёта суммы по выбранным).
  final List<STOService> services;
  final List<STOPackage> packages;

  /// Итоговая сумма по выбранным в фильтре услугам (копейки). Заполняется при активном фильтре.
  final int? totalSelectedPriceKopecks;

  /// Суммарное время по выбранным услугам (минуты). Заполняется при активном фильтре.
  final int? totalSelectedDurationMinutes;

  const STO({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.phones,
    required this.rating,
    required this.reviewCount,
    this.distanceKm,
    required this.isOpen,
    this.workingHours,
    this.specializations = const [],
    this.logoUrl,
    this.photoUrls = const [],
    this.isFavorite = false,
    this.minPrice,
    this.latitude,
    this.longitude,
    this.businessKindCode = 'sto',
    this.businessKindLabel = 'Автосервис',
    this.schedulingMode = 'staff_based',
    this.types = const [],
    this.serviceIds = const [],
    this.services = const [],
    this.packages = const [],
    this.totalSelectedPriceKopecks,
    this.totalSelectedDurationMinutes,
  });

  /// Все номера для звонка: [phones] или один [phone]
  List<String> get displayPhones => phones ?? (phone != null ? [phone!] : []);

  STO copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    List<String>? phones,
    double? rating,
    int? reviewCount,
    double? distanceKm,
    bool? isOpen,
    String? workingHours,
    List<String>? specializations,
    String? logoUrl,
    List<String>? photoUrls,
    bool? isFavorite,
    String? minPrice,
    double? latitude,
    double? longitude,
    String? businessKindCode,
    String? businessKindLabel,
    String? schedulingMode,
    List<String>? types,
    List<String>? serviceIds,
    List<STOService>? services,
    List<STOPackage>? packages,
    int? totalSelectedPriceKopecks,
    int? totalSelectedDurationMinutes,
  }) {
    return STO(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      phones: phones ?? this.phones,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distanceKm: distanceKm ?? this.distanceKm,
      isOpen: isOpen ?? this.isOpen,
      workingHours: workingHours ?? this.workingHours,
      specializations: specializations ?? this.specializations,
      logoUrl: logoUrl ?? this.logoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      isFavorite: isFavorite ?? this.isFavorite,
      minPrice: minPrice ?? this.minPrice,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      businessKindCode: businessKindCode ?? this.businessKindCode,
      businessKindLabel: businessKindLabel ?? this.businessKindLabel,
      schedulingMode: schedulingMode ?? this.schedulingMode,
      types: types ?? this.types,
      serviceIds: serviceIds ?? this.serviceIds,
      services: services ?? this.services,
      packages: packages ?? this.packages,
      totalSelectedPriceKopecks:
          totalSelectedPriceKopecks ?? this.totalSelectedPriceKopecks,
      totalSelectedDurationMinutes:
          totalSelectedDurationMinutes ?? this.totalSelectedDurationMinutes,
    );
  }
}
