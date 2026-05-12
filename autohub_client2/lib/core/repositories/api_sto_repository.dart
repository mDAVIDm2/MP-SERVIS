import '../../shared/models/sto_model.dart';
import '../../shared/sto_amenity_catalog.dart';
import '../api/api_exceptions.dart';
import '../api/catalog_api_service.dart';
import '../config/app_config.dart';
import 'sto_repository.dart';

/// Репозиторий каталога точек через API (организации с бэкенда).
class ApiSTORepository implements STORepository {
  ApiSTORepository(this._catalog);
  final CatalogApiService _catalog;

  static List<StoDaySchedule>? _parseWorkingHoursWeek(dynamic raw) {
    if (raw is! List || raw.length != 7) return null;
    final out = <StoDaySchedule>[];
    for (final e in raw) {
      if (e is! Map) return null;
      final m = Map<String, dynamic>.from(e);
      var closed = m['closed'] == true;
      final open = m['open'] as String? ?? '09:00';
      final close = m['close'] as String? ?? '19:00';
      if (!closed && open == '00:00' && close == '00:00') {
        closed = true;
      }
      out.add(StoDaySchedule(open: open, close: close, closed: closed));
    }
    return out;
  }

  static List<String> _parseAmenityIds(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString())
        .where((id) => StoAmenityCatalog.byId.containsKey(id))
        .toList();
  }

  static String? _catalogItemIdFromJson(Map<String, dynamic> m) {
    final a = m['catalog_item_id']?.toString().trim();
    if (a != null && a.isNotEmpty) return a;
    final b = m['catalogItemId']?.toString().trim();
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  static STO _itemToSTO(Map<String, dynamic> o, {bool isFavorite = false}) {
    final carBrands =
        (o['car_brands'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final photoUrlsRaw = o['photo_urls'] as List<dynamic>?;
    final photoUrls =
        photoUrlsRaw
            ?.map((e) => AppConfig.resolveOrganizationPhotoUrl(e.toString()))
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final lat = o['latitude'] != null
        ? (o['latitude'] as num).toDouble()
        : null;
    final lng = o['longitude'] != null
        ? (o['longitude'] as num).toDouble()
        : null;
    final serviceIds =
        (o['service_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final servicesRaw = o['services'] as List<dynamic>? ?? [];
    final services = servicesRaw
        .map((e) {
          final m = e as Map<String, dynamic>;
          return STOService(
            id: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            category: '',
            priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? 0,
            durationMinutes: (m['duration_minutes'] as num?)?.toInt() ?? 60,
            catalogItemId: _catalogItemIdFromJson(m),
            useBodyTypePricing: m['use_body_type_pricing'] == true,
            bodyTypePricing:
                ((m['body_type_pricing'] as List<dynamic>?) ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .map(
                      (p) => STOServiceBodyPricing(
                        bodyType: p['body_type']?.toString() ?? '',
                        priceKopecks:
                            (p['price_kopecks'] as num?)?.toInt() ?? 0,
                        durationMinutes:
                            (p['duration_minutes'] as num?)?.toInt() ?? 60,
                      ),
                    )
                    .toList(),
          );
        })
        .where((s) => s.id.isNotEmpty)
        .toList();
    final bk = o['business_kind']?.toString() ?? 'sto';
    final bkl = o['business_kind_label']?.toString() ?? 'Автосервис';
    final sm = o['scheduling_mode']?.toString() ?? 'staff_based';
    final hoursLive = StoHoursLive.tryParse(o['hours_live']);
    final isOpenComputed = hoursLive?.isPositiveNow ??
        true; // старый API без hours_live — как раньше по умолчанию «открыто»
    return STO(
      id: o['id'] as String? ?? '',
      name: o['name'] as String? ?? 'Сервис',
      address: o['address'] as String? ?? '',
      phone: o['phone'] as String?,
      rating: 0,
      reviewCount: 0,
      isOpen: isOpenComputed,
      workingHours: o['working_hours'] as String?,
      workingHoursWeek: _parseWorkingHoursWeek(o['working_hours_week']),
      timezone: o['timezone']?.toString().trim().isNotEmpty == true
          ? o['timezone'].toString().trim()
          : 'Europe/Moscow',
      workingHoursExceptions:
          StoWorkingHoursException.tryParseList(o['working_hours_exceptions']),
      hoursLive: hoursLive,
      amenityIds: _parseAmenityIds(o['amenity_ids']),
      publicDescription: o['public_description'] as String?,
      businessKindCode: bk,
      businessKindLabel: bkl,
      schedulingMode: sm == 'bay_based' ? 'bay_based' : 'staff_based',
      types: [bkl],
      specializations: carBrands,
      isFavorite: isFavorite,
      latitude: lat,
      longitude: lng,
      logoUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
      photoUrls: photoUrls,
      serviceIds: serviceIds,
      services: services,
      packages: const [],
    );
  }

  @override
  Future<Result<List<STO>>> searchSTOs({
    String? query,
    String? businessKind,
    String? category,
    double? lat,
    double? lng,
    double? radius,
    String? sortBy,
  }) async {
    final result = await _catalog.search(
      query: query,
      businessKind: businessKind,
    );
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final list = (data['items'] as List<dynamic>?) ?? [];
    final stos = list
        .map((e) => _itemToSTO(e as Map<String, dynamic>))
        .where((s) => s.id.isNotEmpty)
        .toList();
    return Result.success(stos);
  }

  @override
  Future<Result<STO>> getSTOById(String id) async {
    final result = await _catalog.getOrganization(id);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    return Result.success(_itemToSTO(data));
  }

  @override
  Future<Result<List<STO>>> getFavorites() async {
    return Result.success([]);
  }

  @override
  Future<Result<void>> toggleFavorite(String stoId) async {
    return Result.success(null);
  }

  @override
  Future<Result<List<STOService>>> getServices(String stoId) async {
    final result = await _catalog.getOrganizationServices(stoId);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final categories = (data['categories'] as List<dynamic>?) ?? [];
    final catMap = <String, String>{};
    for (final c in categories) {
      final m = c as Map<String, dynamic>;
      catMap[m['id'] as String? ?? ''] = m['name'] as String? ?? '';
    }
    final items = (data['items'] as List<dynamic>?) ?? [];
    final list = items
        .map((e) {
          final m = e as Map<String, dynamic>;
          final cid = m['category_id'] as String? ?? '';
          return STOService(
            id: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            category: catMap[cid] ?? '',
            priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? 0,
            durationMinutes: (m['duration_minutes'] as num?)?.toInt() ?? 60,
            catalogItemId: _catalogItemIdFromJson(m),
            requiredSkill: m['required_skill'] as String?,
            useBodyTypePricing: m['use_body_type_pricing'] == true,
            bodyTypePricing:
                ((m['body_type_pricing'] as List<dynamic>?) ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .map(
                      (p) => STOServiceBodyPricing(
                        bodyType: p['body_type']?.toString() ?? '',
                        priceKopecks:
                            (p['price_kopecks'] as num?)?.toInt() ?? 0,
                        durationMinutes:
                            (p['duration_minutes'] as num?)?.toInt() ?? 60,
                      ),
                    )
                    .toList(),
          );
        })
        .where((s) => s.id.isNotEmpty)
        .toList();
    return Result.success(list);
  }

  @override
  Future<Result<List<STOService>>> getAllServices() async {
    final result = await _catalog.getCatalogServices();
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    return Result.success(_parseGroupedCatalogToServices(data));
  }

  /// Разбор ответа `GET /catalog/services` (формат getCatalogGrouped) в плоский список услуг.
  static List<STOService> _parseGroupedCatalogToServices(
    Map<String, dynamic> data,
  ) {
    final categoriesRaw = data['categories'] as List<dynamic>? ?? [];
    final list = <STOService>[];
    for (final c in categoriesRaw) {
      final m = c as Map<String, dynamic>;
      final catKey = m['category_key']?.toString() ?? m['id']?.toString() ?? '';
      final catName =
          m['category_name']?.toString() ?? m['name']?.toString() ?? '';
      final label = catName.isNotEmpty ? catName : catKey;
      final inner = m['items'] as List<dynamic>? ?? [];
      for (final s in inner) {
        final sm = s as Map<String, dynamic>;
        final id = sm['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        list.add(
          STOService(
            id: id,
            name: sm['name']?.toString() ?? '',
            category: label,
            priceKopecks: 0,
            durationMinutes:
                (sm['default_duration_minutes'] as num?)?.toInt() ?? 60,
            requiredSkill: sm['required_skill']?.toString(),
            catalogItemId: id,
          ),
        );
      }
    }
    if (list.isEmpty) {
      final flatItems = data['items'] as List<dynamic>? ?? [];
      for (final s in flatItems) {
        final sm = s as Map<String, dynamic>;
        final id = sm['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        list.add(
          STOService(
            id: id,
            name: sm['name']?.toString() ?? '',
            category: sm['category_id']?.toString() ?? '',
            priceKopecks: (sm['price_kopecks'] as num?)?.toInt() ?? 0,
            durationMinutes: (sm['duration_minutes'] as num?)?.toInt() ?? 60,
            requiredSkill: sm['required_skill']?.toString(),
            catalogItemId: id,
          ),
        );
      }
    }
    return list;
  }

  @override
  Future<Result<AvailableSlotsResult>> getAvailableSlots(
    String stoId,
    DateTime date,
    List<String> serviceIds, {
    List<SlotAvailabilityItem>? items,
  }) async {
    final itemPayload = items
        ?.map((e) {
          final m = <String, dynamic>{'estimated_minutes': e.estimatedMinutes};
          final sid = e.serviceId?.trim();
          if (sid != null && sid.isNotEmpty) m['service_id'] = sid;
          final sk = e.requiredSkill?.trim();
          if (sk != null && sk.isNotEmpty) m['required_skill'] = sk;
          return m;
        })
        .toList();
    final result = await _catalog.getAvailableSlots(
      organizationId: stoId,
      date: date,
      serviceIds: serviceIds,
      items: itemPayload,
    );
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final slotsRaw = data['slots'] as List<dynamic>? ?? [];
    final schedulingMode = data['scheduling_mode']?.toString() ?? 'staff_based';
    final bayCount = (data['bay_count'] as num?)?.toInt();
    final requiredSkills =
        (data['required_skills'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final totalMinutes = (data['total_minutes'] as num?)?.toInt() ?? 0;
    final slotDurationMinutes =
        (data['slot_duration_minutes'] as num?)?.toInt() ?? 30;
    int hm(String? s, int fallback) {
      if (s == null || s.isEmpty) return fallback;
      final p = s.split(':');
      final h = int.tryParse(p[0].trim()) ?? 0;
      final m = p.length > 1 ? (int.tryParse(p[1].trim()) ?? 0) : 0;
      return (h * 60 + m).clamp(0, 24 * 60);
    }

    final workStartMinutes = hm(data['work_day_start'] as String?, 9 * 60);
    final workEndMinutes = hm(data['work_day_end'] as String?, 18 * 60);
    final startTimes = <String>{};
    final choices = <BookingSlotChoice>[];
    final seenBayTimes = <String>{};
    for (final s in slotsRaw) {
      final m = s as Map<String, dynamic>;
      final start = m['start']?.toString();
      if (start != null && start.isNotEmpty) {
        final dt = DateTime.tryParse(start);
        if (dt != null) {
          final local = dt.toLocal();
          final hhmm =
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
          final modeRow = m['scheduling_mode']?.toString() ?? schedulingMode;
          if (modeRow == 'bay_based') {
            if (seenBayTimes.contains(hhmm)) continue;
            seenBayTimes.add(hhmm);
          }
          startTimes.add(hhmm);
          final mid = m['master_id']?.toString();
          choices.add(
            BookingSlotChoice(
              startIsoUtc: start,
              timeLocalHHmm: hhmm,
              masterId: (mid != null && mid.isNotEmpty) ? mid : null,
              masterName: m['master_name']?.toString() ?? '',
              schedulingMode: modeRow,
            ),
          );
        }
      }
    }
    return Result.success(
      AvailableSlotsResult(
        startTimes: startTimes.toList()..sort(),
        slotChoices: choices,
        schedulingMode: schedulingMode,
        bayCount: bayCount,
        requiredSkills: requiredSkills,
        totalMinutes: totalMinutes,
        slotDurationMinutes: slotDurationMinutes.clamp(15, 240),
        workStartMinutes: workStartMinutes,
        workEndMinutes: workEndMinutes < workStartMinutes
            ? workStartMinutes + 60
            : workEndMinutes,
      ),
    );
  }

  @override
  Future<Result<List<STOReview>>> getReviews(String stoId) async {
    return Result.success([]);
  }
}
