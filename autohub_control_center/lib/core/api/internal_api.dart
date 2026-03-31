import 'package:dio/dio.dart';

/// API для разделов Control Center (все запросы с Bearer-токеном через переданный Dio).
class InternalApi {
  InternalApi(this._dio);

  final Dio _dio;

  void _throwIfNotOk(Response<dynamic> r) {
    final code = r.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    final data = r.data;
    String msg = 'HTTP $code';
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is List) {
        msg = m.map((e) => '$e').join(', ');
      } else {
        msg = '$m';
      }
    }
    throw Exception(msg);
  }

  Future<Map<String, dynamic>?> _get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(path, queryParameters: queryParameters);
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) return r.data;
      return null;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOrganizations() => _get('internal/organizations');

  Future<Map<String, dynamic>?> getOrganization(String id) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('internal/organizations/$id');
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) return r.data;
      return null;
    } on DioException {
      return null;
    }
  }

  Future<bool> updateOrganization(String id, Map<String, dynamic> data) async {
    try {
      final body = <String, dynamic>{};
      if (data.containsKey('name')) body['name'] = data['name'];
      if (data.containsKey('address')) body['address'] = data['address'];
      if (data.containsKey('phone')) body['phone'] = data['phone'];
      if (data.containsKey('working_hours')) body['working_hours'] = data['working_hours'];
      if (data.containsKey('timezone')) body['timezone'] = data['timezone'];
      if (data.containsKey('latitude')) body['latitude'] = data['latitude'];
      if (data.containsKey('longitude')) body['longitude'] = data['longitude'];
      final r = await _dio.patch<Map<String, dynamic>>('internal/organizations/$id', data: body);
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getOrganizationStaff(String organizationId) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('internal/organizations/$organizationId/staff');
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) return r.data;
      return null;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUsers() => _get('internal/users');
  Future<Map<String, dynamic>?> getOrders({int? limit, int? offset}) =>
      _get('internal/orders', queryParameters: {
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      });
  Future<Map<String, dynamic>?> getSubscriptions() => _get('internal/subscriptions');
  Future<List<dynamic>?> getCarBrands() async {
    try {
      final r = await _dio.get('internal/reference/car-brands');
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 && r.data is List) {
        return r.data as List<dynamic>;
      }
      return null;
    } on DioException {
      return null;
    }
  }

  Future<List<dynamic>?> getCarModels(int brandId) async {
    final r = await _dio.get('internal/reference/car-brands/$brandId/models');
    if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 && r.data is List) {
      return r.data as List<dynamic>;
    }
    return null;
  }

  Future<List<dynamic>?> getCarGenerations(int modelId) async {
    final r = await _dio.get('internal/reference/car-models/$modelId/generations');
    if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 && r.data is List) {
      return r.data as List<dynamic>;
    }
    return null;
  }

  Future<List<dynamic>?> getPendingCar() async {
    try {
      final r = await _dio.get('internal/reference/pending-car');
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 && r.data is List) {
        return r.data as List<dynamic>;
      }
      return null;
    } on DioException {
      return null;
    }
  }

  Future<bool> approvePendingCar(String id) async {
    try {
      final r = await _dio.post('internal/reference/pending-car/$id/approve');
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<bool> rejectPendingCar(String id) async {
    try {
      final r = await _dio.post('internal/reference/pending-car/$id/reject');
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<bool> suggestPendingCar(String id, {required int brandId, required int modelId, required int generationId}) async {
    try {
      final r = await _dio.post('internal/reference/pending-car/$id/suggest', data: {
        'brandId': brandId,
        'modelId': modelId,
        'generationId': generationId,
      });
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> createCarBrand(String name) async {
    try {
      final r = await _dio.post('internal/reference/car-brands', data: {'name': name});
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 ? r.data as Map<String, dynamic>? : null;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createCarModel(int brandId, String name) async {
    try {
      final r = await _dio.post('internal/reference/car-brands/$brandId/models', data: {'name': name});
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 ? r.data as Map<String, dynamic>? : null;
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createCarGeneration(int modelId, String name, {int? yearFrom, int? yearTo}) async {
    try {
      final r = await _dio.post('internal/reference/car-models/$modelId/generations', data: {
        'name': name,
        if (yearFrom != null) 'year_from': yearFrom,
        if (yearTo != null) 'year_to': yearTo,
      });
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 ? r.data as Map<String, dynamic>? : null;
    } on DioException {
      return null;
    }
  }

  Future<bool> deleteCarBrand(int id) async {
    try {
      final r = await _dio.delete('internal/reference/car-brands/$id');
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteCarModel(int id) async {
    try {
      final r = await _dio.delete('internal/reference/car-models/$id');
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteCarGeneration(int id) async {
    try {
      final r = await _dio.delete('internal/reference/car-generations/$id');
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<bool> updateSubscription(String organizationId, {required bool isActive, String? status}) async {
    try {
      final r = await _dio.patch('internal/subscriptions/$organizationId', data: {
        'is_active': isActive,
        if (status != null) 'status': status,
      });
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  /// PATCH подписки: тариф, активность, индивидуальные лимиты (`limits_override`: объект или `null` = сброс).
  /// Возвращает тело ответа при успехе (в т.ч. `subscription_usage`), иначе null.
  Future<Map<String, dynamic>?> patchOrganizationSubscription(
    String organizationId,
    Map<String, dynamic> body,
  ) async {
    try {
      final r = await _dio.patch<Map<String, dynamic>>('internal/subscriptions/$organizationId', data: body);
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) {
        return r.data;
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        final m = data['message'];
        if (m is List) {
          throw Exception(m.map((x) => '$x').join(', '));
        }
        throw Exception('$m');
      }
      rethrow;
    }
  }

  static Map<String, dynamic>? _unwrapCatalogJson(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    var map = Map<String, dynamic>.from(raw);
    final nested = map['data'];
    if (nested is Map && nested['categories'] is List) {
      map = Map<String, dynamic>.from(nested);
    }
    return map;
  }

  static int _serviceCatalogItemCount(Map<String, dynamic> map) {
    final cats = map['categories'];
    if (cats is! List) return 0;
    var n = 0;
    for (final e in cats) {
      if (e is Map) {
        final items = e['items'];
        if (items is List) n += items.length;
      }
    }
    return n;
  }

  /// Справочник услуг (internal). При сетевой ошибке или не-2xx — бросает [Exception], чтобы UI не показывал «пустой каталог».
  ///
  /// Сначала `internal/reference/service-catalog` — тот же контракт, что `GET /reference/service-catalog` в Business; затем запасной `internal/service-dictionaries`
  /// (на случай старого деплоя). Dio с [validateStatus] \< 500 не бросает на 404, поэтому статус проверяем вручную.
  Future<Map<String, dynamic>> fetchServiceDictionaries() async {
    String bodyPreview(dynamic data) {
      if (data == null) return '';
      final s = data.toString();
      return s.length > 240 ? '${s.substring(0, 240)}…' : s;
    }

    const primary = 'internal/reference/service-catalog';
    const legacy = 'internal/service-dictionaries';

    try {
      Map<String, dynamic>? best;
      var bestCount = 0;
      Map<String, dynamic>? lastOkShape;
      DioException? firstDio;

      for (final path in [primary, legacy]) {
        try {
          final r = await _dio.get<dynamic>(path);
          final code = r.statusCode ?? 0;
          if (code == 401 || code == 403) {
            throw Exception(
              'Доступ запрещён (HTTP $code). Выйдите и войдите снова в Control Center или проверьте internal JWT. ${bodyPreview(r.data)}',
            );
          }
          if (code < 200 || code >= 300) {
            continue;
          }
          final raw = r.data;
          if (raw == null || raw is String) {
            continue;
          }
          final map = _unwrapCatalogJson(raw);
          if (map == null) {
            continue;
          }
          lastOkShape = map;
          final cnt = _serviceCatalogItemCount(map);
          if (cnt > bestCount) {
            bestCount = cnt;
            best = map;
          }
        } on DioException catch (e) {
          firstDio ??= e;
          final st = e.response?.statusCode;
          if (st == 401 || st == 403) rethrow;
          continue;
        }
      }

      if (best != null) return best;
      if (lastOkShape != null) return lastOkShape;

      if (firstDio != null) throw firstDio;
      throw Exception(
        'Не удалось загрузить справочник: нет подходящего ответа от $primary и $legacy. Обновите бэкенд (npm run build) и перезапустите API.',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      String extra = '';
      if (data is Map && data['message'] != null) {
        extra = ' ${data['message']}';
      } else if (data != null) {
        extra = ' ${bodyPreview(data)}';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Нет связи с API (таймаут или хост недоступен). Проверьте AUTOHUB_API_HOST и что бэкенд запущен.',
        );
      }
      if (status == 401 || status == 403) {
        throw Exception(
          'Доступ запрещён (HTTP $status). Выйдите и войдите снова в Control Center или проверьте internal JWT.$extra',
        );
      }
      throw Exception(
        'Не удалось загрузить справочник${status != null ? ' (HTTP $status)' : ''}.$extra ${e.message ?? ''}'.trim(),
      );
    }
  }

  void _rethrowDio(DioException e) {
    final res = e.response;
    if (res != null) _throwIfNotOk(res);
    throw Exception(e.message ?? 'Нет связи с API');
  }

  Future<void> createServiceCatalogCategory({
    required String categoryKey,
    required String categoryName,
    String? firstServiceName,
  }) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/reference/service-catalog/categories',
        data: {
          'category_key': categoryKey,
          'category_name': categoryName,
          if (firstServiceName != null && firstServiceName.trim().isNotEmpty) 'first_service_name': firstServiceName.trim(),
        },
      );
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<void> patchServiceCatalogCategory({
    required String categoryKey,
    String? categoryName,
    String? newCategoryKey,
  }) async {
    try {
      final r = await _dio.patch<dynamic>(
        'internal/reference/service-catalog/categories',
        data: {
          'category_key': categoryKey,
          if (categoryName != null) 'category_name': categoryName,
          if (newCategoryKey != null && newCategoryKey.trim().isNotEmpty) 'new_category_key': newCategoryKey.trim(),
        },
      );
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<void> deleteServiceCatalogCategory(String categoryKey) async {
    try {
      final r = await _dio.delete<dynamic>(
        'internal/reference/service-catalog/categories',
        queryParameters: {'category_key': categoryKey},
      );
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<void> reorderServiceCatalogCategory({required String categoryKey, required int delta}) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/reference/service-catalog/categories/reorder',
        data: {'category_key': categoryKey, 'delta': delta},
      );
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<void> createServiceCatalogItem({
    required String categoryKey,
    required String categoryName,
    required String name,
    int? defaultDurationMinutes,
    String? requiredSkill,
  }) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/reference/service-catalog/items',
        data: {
          'category_key': categoryKey,
          'category_name': categoryName,
          'name': name,
          if (defaultDurationMinutes != null) 'default_duration_minutes': defaultDurationMinutes,
          if (requiredSkill != null && requiredSkill.trim().isNotEmpty) 'required_skill': requiredSkill.trim(),
        },
      );
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<void> patchServiceCatalogItem({
    required String id,
    String? name,
    int? defaultDurationMinutes,
    String? requiredSkill,
    int? sortOrder,
    String? categoryKey,
  }) async {
    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name,
        if (defaultDurationMinutes != null) 'default_duration_minutes': defaultDurationMinutes,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (categoryKey != null) 'category_key': categoryKey,
      };
      if (requiredSkill != null) {
        body['required_skill'] = requiredSkill.trim().isEmpty ? null : requiredSkill.trim();
      }
      final r = await _dio.patch<dynamic>('internal/reference/service-catalog/items/$id', data: body);
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<void> deleteServiceCatalogItem(String id) async {
    try {
      final r = await _dio.delete<dynamic>('internal/reference/service-catalog/items/$id');
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<void> reorderServiceCatalogItem({required String id, required int delta}) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/reference/service-catalog/items/$id/reorder',
        data: {'delta': delta},
      );
      _throwIfNotOk(r);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  Future<Map<String, dynamic>?> getAudit({int? limit, int? offset, String? from, String? to}) =>
      _get('internal/audit', queryParameters: {
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      });

  Future<Map<String, dynamic>?> getClientCars() => _get('internal/client-cars');

  Future<Map<String, dynamic>?> getClientCarHistory({required String clientPhone, required String carId}) =>
      _get('internal/client-cars/history', queryParameters: {
        'client_phone': clientPhone,
        'car_id': carId,
      });

  Future<Map<String, dynamic>?> getSupportChats() => _get('internal/support-chats');

  Future<Map<String, dynamic>?> getSupportChatMessages(String chatId) =>
      _get('internal/support-chats/$chatId/messages');

  Future<Map<String, dynamic>?> postSupportChatMessage(String chatId, String text) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        'internal/support-chats/$chatId/messages',
        data: {'text': text},
      );
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) return r.data;
      return null;
    } on DioException {
      return null;
    }
  }

  /// Помечает чат прочитанным для операторов (сброс счётчика непрочитанного в списке).
  Future<void> postSupportChatRead(String chatId) async {
    try {
      await _dio.post<void>('internal/support-chats/$chatId/read');
    } on DioException {
      // игнорируем — бейдж обновится при следующем опросе
    }
  }
}
