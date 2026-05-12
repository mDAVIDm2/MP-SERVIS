import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

/// API каталога организаций (поиск точек для клиента).
class CatalogApiService {
  CatalogApiService(this._client);
  final ApiClient _client;

  /// Общий каталог услуг (категории + услуги) для фильтра поиска.
  /// [businessKind] — опционально сузить позиции по `allowed_business_kinds` (как у организаций этого типа).
  Future<Result<Map<String, dynamic>>> getCatalogServices({String? businessKind}) async {
    try {
      final qp = <String, dynamic>{};
      if (businessKind != null && businessKind.isNotEmpty && businessKind != 'all') {
        qp['business_kind'] = businessKind;
      }
      final res = await _client.get(
        ApiEndpoints.catalogServices,
        queryParameters: qp.isEmpty ? null : qp,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Поиск организаций. [query] — опциональная строка поиска.
  Future<Result<Map<String, dynamic>>> search({String? query, String? businessKind}) async {
    try {
      final qp = <String, dynamic>{};
      if (query != null && query.isNotEmpty) qp['q'] = query;
      if (businessKind != null && businessKind.isNotEmpty && businessKind != 'all') {
        qp['business_kind'] = businessKind;
      }
      final res = await _client.get(
        ApiEndpoints.catalogSearch,
        queryParameters: qp.isEmpty ? null : qp,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Организация по ID.
  Future<Result<Map<String, dynamic>>> getOrganization(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.catalogOrganization(id));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Услуги организации (категории + позиции с ценами).
  Future<Result<Map<String, dynamic>>> getOrganizationServices(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.catalogOrgServices(id));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Доступные слоты для записи (умное расписание: мастера, навыки, занятость).
  /// Требует авторизации. [date] — день в локальной зоне.
  /// Либо [serviceIds] (длительность из прайса), либо [items] с фактическими `estimated_minutes` (как в заказе).
  Future<Result<Map<String, dynamic>>> getAvailableSlots({
    required String organizationId,
    required DateTime date,
    List<String> serviceIds = const [],
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final data = <String, dynamic>{
        'organization_id': organizationId,
        'date': dateStr,
      };
      if (items != null && items.isNotEmpty) {
        data['items'] = items;
      } else {
        data['service_ids'] = serviceIds;
      }
      final res = await _client.post(
        ApiEndpoints.bookingAvailableSlots,
        data: data,
      );
      final map = res.data;
      if (map is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(map);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Ближайшие слоты для списка организаций при фильтре по услугам (батч).
  Future<Result<Map<String, dynamic>>> nearestSlotsBatch({
    required List<String> organizationIds,
    required List<String> serviceIds,
  }) async {
    try {
      final res = await _client.post(
        ApiEndpoints.bookingNearestSlotsBatch,
        data: {
          'organization_ids': organizationIds,
          'service_ids': serviceIds,
        },
      );
      final map = res.data;
      if (map is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(map);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
