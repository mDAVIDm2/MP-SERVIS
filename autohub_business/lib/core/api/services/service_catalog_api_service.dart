import 'dart:convert';

import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_exceptions.dart';
import '../../../shared/models/service_catalog_models.dart';

class ServiceCatalogApiService {
  ServiceCatalogApiService(this._client);
  final ApiClient _client;

  static Map<String, dynamic>? _asJsonMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return Map<String, dynamic>.from(raw);
      } catch (_) {}
    }
    return null;
  }

  Future<Result<ServiceCatalogData>> getCatalog() async {
    try {
      final res = await _client.get('/reference/service-catalog');
      dynamic root = res.data;
      if (root is String) {
        try {
          root = jsonDecode(root);
        } catch (_) {
          return Result.failure(const ApiException(
            code: ApiErrorCode.internal,
            message: 'Справочник: сервер вернул не JSON',
          ));
        }
      }
      final rootMap = _asJsonMap(root);
      if (rootMap == null) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'Справочник: ожидался объект JSON',
        ));
      }
      Map<String, dynamic>? map;
      final inner = rootMap['data'];
      final innerMap = _asJsonMap(inner);
      if (innerMap != null && innerMap['categories'] is List) {
        map = innerMap;
      } else if (rootMap['categories'] is List) {
        map = rootMap;
      }
      if (map == null) {
        return Result.failure(const ApiException(
          code: ApiErrorCode.internal,
          message: 'В ответе нет списка categories (ожидался { categories: [...] } или { data: { categories: [...] } })',
        ));
      }
      return Result.success(ServiceCatalogData.fromJson(map));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> submitSuggestion({
    required String requestedName,
    String? categoryHint,
    String? note,
  }) async {
    try {
      final res = await _client.post(
        '/reference/service-catalog/suggestions',
        data: {
          'requested_name': requestedName,
          if (categoryHint != null && categoryHint.trim().isNotEmpty) 'category_hint': categoryHint.trim(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      final raw = res.data;
      final m = _asJsonMap(raw);
      if (m != null) return Result.success(m);
      return Result.success(<String, dynamic>{});
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
