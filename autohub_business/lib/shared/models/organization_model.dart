import 'organization_business_kind.dart';
import 'organization_hours_exception.dart';
import 'organization_subscription_usage.dart';
import 'organization_working_hours_week.dart';

/// Профиль организации (точка для клиента).
class OrganizationInfo {
  final String name;
  final String address;
  final String phone;
  final String workingHours;
  /// Пн–вс, с бэкенда `working_hours_week`; при сохранении пересчитывается [workingHours] на сервере.
  final OrganizationWorkingHoursWeek? workingHoursWeek;
  /// Разовые выходные или сокращённые дни (`working_hours_exceptions`).
  final List<OrganizationHoursException>? workingHoursExceptions;
  /// Вид бизнеса (sto, car_wash, …) — для подписей у клиентов, например в чате.
  final String businessKind;
  /// `staff_based` | `bay_based` — с бэкенда; для назначения постов в расписании нужен `bay_based`.
  final String schedulingMode;
  /// URL фотографий точки (отображаются в верхней части карточки у клиентов).
  final List<String> photoUrls;
  /// Координаты для отображения на карте у клиентов (широта).
  final double? latitude;
  /// Координаты для отображения на карте у клиентов (долгота).
  final double? longitude;
  /// Тариф и лимиты (если бэкенд вернул `subscription_usage`).
  final OrganizationSubscriptionUsage? subscriptionUsage;

  const OrganizationInfo({
    this.name = 'Мой автосервис',
    this.address = '',
    this.phone = '',
    this.workingHours = 'Пн–Пт 9:00–19:00, Сб 10:00–16:00',
    this.workingHoursWeek,
    this.workingHoursExceptions,
    this.businessKind = OrganizationBusinessKindCodes.sto,
    this.schedulingMode = 'staff_based',
    this.photoUrls = const [],
    this.latitude,
    this.longitude,
    this.subscriptionUsage,
  });

  OrganizationInfo copyWith({
    String? name,
    String? address,
    String? phone,
    String? workingHours,
    OrganizationWorkingHoursWeek? workingHoursWeek,
    List<OrganizationHoursException>? workingHoursExceptions,
    String? businessKind,
    String? schedulingMode,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
    OrganizationSubscriptionUsage? subscriptionUsage,
  }) {
    return OrganizationInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      workingHours: workingHours ?? this.workingHours,
      workingHoursWeek: workingHoursWeek ?? this.workingHoursWeek,
      workingHoursExceptions: workingHoursExceptions ?? this.workingHoursExceptions,
      businessKind: businessKind != null
          ? OrganizationBusinessKindCodes.normalize(businessKind)
          : this.businessKind,
      schedulingMode: schedulingMode != null && schedulingMode.trim().isNotEmpty
          ? schedulingMode.trim()
          : this.schedulingMode,
      photoUrls: photoUrls ?? this.photoUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      subscriptionUsage: subscriptionUsage ?? this.subscriptionUsage,
    );
  }

  static OrganizationInfo fromJson(Map<String, dynamic> j) {
    final photoUrlsRaw = j['photo_urls'] as List<dynamic>?;
    final photoUrls = photoUrlsRaw?.map((e) => e.toString()).where((s) => s.isNotEmpty).toList() ?? [];
    final lat = j['latitude'];
    final lng = j['longitude'];
    return OrganizationInfo(
      name: j['name'] as String? ?? 'Мой автосервис',
      address: j['address'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      workingHours: j['working_hours'] as String? ?? j['workingHours'] as String? ?? 'Пн–Пт 9:00–19:00, Сб 10:00–16:00',
      workingHoursWeek: OrganizationWorkingHoursWeek.tryParseJson(j['working_hours_week']),
      workingHoursExceptions:
          OrganizationHoursException.tryParseList(j['working_hours_exceptions']),
      businessKind: OrganizationBusinessKindCodes.normalize(
        j['business_kind']?.toString() ?? j['businessKind']?.toString(),
      ),
      schedulingMode: () {
        final s = j['scheduling_mode']?.toString() ?? j['schedulingMode']?.toString() ?? 'staff_based';
        if (s == 'bay_based' || s == 'staff_based') return s;
        return 'staff_based';
      }(),
      photoUrls: photoUrls,
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
      subscriptionUsage: OrganizationSubscriptionUsage.tryParse(j['subscription_usage']),
    );
  }
}
