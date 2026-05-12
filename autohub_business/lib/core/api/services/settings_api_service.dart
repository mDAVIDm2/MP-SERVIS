import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';
import '../../../shared/models/settings_models.dart';
import '../../../shared/models/sto_amenity_catalog.dart';

/// API настроек организации (услуги, слоты, шаблоны и т.д.).
class SettingsApiService {
  SettingsApiService(this._client);

  final ApiClient _client;

  Future<Result<SettingsState>> get(String orgId) async {
    try {
      final res = await _client.get(ApiEndpoints.organizationSettings(orgId));
      final raw = res.data;
      if (raw is! Map<String, dynamic>) {
        return Result.failure(
          const ApiException(
            code: ApiErrorCode.internal,
            message: 'Неверный формат',
          ),
        );
      }
      final data = raw['data'] as Map<String, dynamic>? ?? raw;
      final state = _parseState(data);
      return Result.success(state);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  SettingsState _parseState(Map<String, dynamic> data) {
    final categories =
        (data['categories'] as List<dynamic>?)
            ?.map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final services =
        (data['services'] as List<dynamic>?)
            ?.map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final packages =
        (data['service_packages'] as List<dynamic>?)
            ?.map((e) => ServicePackage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final carBrands =
        (data['car_brands'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        (data['carBrands'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    final rawAmenities = data['amenity_ids'] as List<dynamic>? ?? data['amenityIds'] as List<dynamic>?;
    final amenityIds = rawAmenities == null
        ? <String>[]
        : rawAmenities
            .map((e) => e.toString())
            .where((id) => StoAmenityCatalog.ids.contains(id))
            .toList();
    final publicDescription =
        (data['public_description'] as String? ?? data['publicDescription'] as String? ?? '').trim();
    final slotsRaw =
        data['slots'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final slots = SlotsSettings.fromJson(slotsRaw);
    final notifRaw =
        data['notifications'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final notifications = NotificationSettings.fromJson(notifRaw);
    final messageTemplates =
        (data['message_templates'] as List<dynamic>?)
            ?.map((e) => MessageTemplate.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return SettingsState(
      categories: categories,
      services: services,
      packages: packages,
      carBrands: carBrands,
      amenityIds: amenityIds,
      publicDescription: publicDescription,
      slotsSettings: slots,
      notificationSettings: notifications,
      messageTemplates: messageTemplates,
    );
  }

  /// PATCH настроек. Тело в snake_case для бэкенда.
  Future<Result<SettingsState>> update(
    String orgId,
    SettingsState state,
  ) async {
    try {
      final body = {
        'categories': state.categories.map((e) => e.toJson()).toList(),
        'services': state.services
            .map(
              (e) => {
                'id': e.id,
                'category_id': e.categoryId,
                'name': e.name,
                'price_kopecks': e.priceKopecks,
                'duration_minutes': e.durationMinutes,
                if (e.requiredSkill != null) 'required_skill': e.requiredSkill,
                if (e.catalogItemId != null && e.catalogItemId!.isNotEmpty)
                  'catalog_item_id': e.catalogItemId,
                'use_body_type_pricing': e.useBodyTypePricing,
                if (e.bodyTypePricing.isNotEmpty)
                  'body_type_pricing': e.bodyTypePricing
                      .map(
                        (p) => {
                          'body_type': p.bodyType,
                          'price_kopecks': p.priceKopecks,
                          'duration_minutes': p.durationMinutes,
                        },
                      )
                      .toList(),
              },
            )
            .toList(),
        'service_packages': state.packages
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'category_id': p.categoryId,
                'package_price_kopecks': p.packagePriceKopecks,
                'included_service_ids': p.includedServiceIds,
                'package_duration_minutes': p.packageDurationMinutes,
                'addons': p.addons
                    .map(
                      (a) => {
                        'service_id': a.serviceId,
                        'extra_price_kopecks': a.extraPriceKopecks,
                        if (a.extraDurationMinutes > 0)
                          'extra_duration_minutes': a.extraDurationMinutes,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
        'car_brands': state.carBrands,
        'amenity_ids': state.amenityIds,
        'public_description': state.publicDescription,
        'slots': {
          'slot_duration_minutes': state.slotsSettings.slotDurationMinutes,
          'confirmation_timeout_minutes':
              state.slotsSettings.confirmationTimeoutMinutes,
          'work_day_start': state.slotsSettings.workDayStart,
          'work_day_end': state.slotsSettings.workDayEnd,
          'bay_count': state.slotsSettings.bayCount,
          'bays': state.slotsSettings.bays
              .map((e) => {'id': e.id, 'name': e.name})
              .toList(),
        },
        'notifications': {
          'new_order': state.notificationSettings.newOrder,
          'new_message': state.notificationSettings.newMessage,
          'approval_response': state.notificationSettings.approvalResponse,
          'order_reminder': state.notificationSettings.orderReminder,
        },
        'message_templates': state.messageTemplates
            .map((e) => e.toJson())
            .toList(),
      };
      final res = await _client.patch(
        ApiEndpoints.organizationSettings(orgId),
        data: body,
      );
      final raw = res.data as Map<String, dynamic>?;
      if (raw == null) {
        return Result.success(state);
      }
      final data = raw['data'] as Map<String, dynamic>? ?? raw;
      return Result.success(_parseState(data));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
