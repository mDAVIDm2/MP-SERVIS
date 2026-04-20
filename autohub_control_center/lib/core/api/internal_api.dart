import 'package:dio/dio.dart';

/// API для разделов Control Center (все запросы с Bearer-токеном через переданный Dio).
class InternalApi {
  InternalApi(this._dio);

  final Dio _dio;

  /// Ответ может быть массивом или обёрткой `{ items | data | results }` (прокси/старый контракт).
  static List<dynamic>? _coerceJsonList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final k in ['items', 'data', 'results']) {
        final v = data[k];
        if (v is List) return v;
      }
    }
    return null;
  }

  static Map<String, dynamic> _normalizeCarGenerationMap(Map<String, dynamic> m) {
    final o = Map<String, dynamic>.from(m);
    if (!o.containsKey('year_from') && m['yearFrom'] != null) o['year_from'] = m['yearFrom'];
    if (!o.containsKey('year_to') && m['yearTo'] != null) o['year_to'] = m['yearTo'];
    return o;
  }

  void _throwIfNotOk(Response<dynamic> r) {
    final code = r.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    throw Exception(_messageFromResponseData(r.data, code));
  }

  static String _messageFromResponseData(dynamic data, int code) {
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is List) return m.map((e) => '$e').join(', ');
      return '$m';
    }
    return code > 0 ? 'HTTP $code' : 'Ошибка запроса';
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
  /// Список марок (только 2xx). При 401/403 — исключение (чтобы не путать с «пустой БД»).
  Future<List<dynamic>> getCarBrands() async {
    try {
      final r = await _dio.get<dynamic>('internal/reference/car-brands');
      final code = r.statusCode ?? 0;
      if (code == 401 || code == 403) {
        throw Exception(
          'Доступ к internal API запрещён (HTTP $code). Выйдите и войдите снова в Control Center.',
        );
      }
      if (code < 200 || code >= 300) {
        throw Exception('Не удалось загрузить марки (HTTP $code).');
      }
      return _coerceJsonList(r.data) ?? [];
    } on DioException catch (e) {
      final sc = e.response?.statusCode;
      if (sc == 401 || sc == 403) {
        throw Exception(
          'Доступ к internal API запрещён (HTTP $sc). Выйдите и войдите снова в Control Center.',
        );
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Нет связи с API при загрузке марок.');
      }
      rethrow;
    }
  }

  Future<List<dynamic>?> getCarModels(int brandId) async {
    try {
      final r = await _dio.get('internal/reference/car-brands/$brandId/models');
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) {
        return _coerceJsonList(r.data);
      }
      return null;
    } on DioException {
      return null;
    }
  }

  Future<List<dynamic>?> getCarGenerations(int modelId) async {
    try {
      final r = await _dio.get('internal/reference/car-models/$modelId/generations');
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) {
        final list = _coerceJsonList(r.data);
        if (list == null) return null;
        return list.map((e) {
          if (e is Map<String, dynamic>) return _normalizeCarGenerationMap(e);
          if (e is Map) return _normalizeCarGenerationMap(Map<String, dynamic>.from(e));
          return e;
        }).toList();
      }
      return null;
    } on DioException {
      return null;
    }
  }

  Future<List<dynamic>?> getPendingCar() async {
    try {
      final r = await _dio.get('internal/reference/pending-car');
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) {
        return _coerceJsonList(r.data);
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
          'Нет связи с API (таймаут или хост недоступен). Проверьте MP_SERVIS_API_HOST и что бэкенд запущен.',
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

  Future<Map<String, dynamic>?> getUserDetail(String id) => _get('internal/users/$id');

  Future<Map<String, dynamic>?> patchUser(String id, {String? name, bool clearAvatar = false}) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (clearAvatar) body['clear_avatar'] = true;
      final r = await _dio.patch<Map<String, dynamic>>('internal/users/$id', data: body);
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) return r.data;
      return null;
    } on DioException {
      return null;
    }
  }

  /// `all: true` — удалить все фото СТО; иначе укажите полный [url] из списка `photo_urls`.
  Future<bool> deleteOrganizationPhotos(String orgId, {bool all = false, String? url}) async {
    if (!all && (url == null || url.isEmpty)) return false;
    try {
      final r = await _dio.delete<void>(
        'internal/organizations/$orgId/photos',
        queryParameters: all ? {'all': '1'} : {'url': url},
      );
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  Future<bool> moderateClearClientCar(
    String clientPhone,
    String carId, {
    bool vin = false,
    bool licensePlate = false,
    bool carInfo = false,
    bool carPhotoUrl = false,
  }) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/client-cars/moderate-clear',
        data: {
          'client_phone': clientPhone,
          'car_id': carId,
          if (vin) 'vin': true,
          if (licensePlate) 'license_plate': true,
          if (carInfo) 'car_info': true,
          if (carPhotoUrl) 'car_photo_url': true,
        },
      );
      return r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;
    } on DioException {
      return false;
    }
  }

  /// Скрыть авто у клиента (остаётся в БД, не отображается в приложении).
  Future<({bool ok, String? error})> hideClientCarFromUser(String clientPhone, String carId) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/client-cars/hide-from-client',
        data: {'client_phone': clientPhone, 'car_id': carId},
      );
      final code = r.statusCode ?? 0;
      if (code >= 200 && code < 300) return (ok: true, error: null);
      return (ok: false, error: _messageFromResponseData(r.data, code));
    } on DioException catch (e) {
      final resp = e.response;
      if (resp != null) {
        final code = resp.statusCode ?? 0;
        return (ok: false, error: _messageFromResponseData(resp.data, code));
      }
      return (ok: false, error: e.message ?? 'Ошибка сети');
    }
  }

  Future<({bool ok, String? error})> restoreClientCarForUser(String clientPhone, String carId) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/client-cars/restore-for-client',
        data: {'client_phone': clientPhone, 'car_id': carId},
      );
      final code = r.statusCode ?? 0;
      if (code >= 200 && code < 300) return (ok: true, error: null);
      return (ok: false, error: _messageFromResponseData(r.data, code));
    } on DioException catch (e) {
      final resp = e.response;
      if (resp != null) {
        final code = resp.statusCode ?? 0;
        return (ok: false, error: _messageFromResponseData(resp.data, code));
      }
      return (ok: false, error: e.message ?? 'Ошибка сети');
    }
  }

  /// Полное удаление заказов с car_id и записи гаража. [confirm] должен быть `DELETE`.
  Future<({bool ok, String? error})> hardDeleteClientCar(
    String clientPhone,
    String carId, {
    required String confirm,
  }) async {
    try {
      final r = await _dio.post<dynamic>(
        'internal/client-cars/hard-delete',
        data: {'client_phone': clientPhone, 'car_id': carId, 'confirm': confirm},
      );
      final code = r.statusCode ?? 0;
      if (code >= 200 && code < 300) return (ok: true, error: null);
      return (ok: false, error: _messageFromResponseData(r.data, code));
    } on DioException catch (e) {
      final resp = e.response;
      if (resp != null) {
        final code = resp.statusCode ?? 0;
        return (ok: false, error: _messageFromResponseData(resp.data, code));
      }
      return (ok: false, error: e.message ?? 'Ошибка сети');
    }
  }
}
