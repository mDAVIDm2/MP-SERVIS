import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/yandex_config.dart';
import '../../../shared/models/external_poi.dart';

const _baseUrl = 'https://search-maps.yandex.ru/v1/';
const _pageSize = 50;
/// Максимум страниц по одному запросу (50 × 20 = до 1000 точек). Лимит API: skip не более 1000.
const _maxPages = 20;
/// Несколько поисковых запросов — чтобы подтянуть ВСЕ организации из Яндекса (разные запросы возвращают разный набор).
const _searchQueries = [
  'автосервис',
  'авторемонт',
  'автомойка',
  'шиномонтаж',
  'детейлинг',
];

/// Соответствие категорий Яндекса нашим типам фильтра (регистронезависимо).
final _categoryToType = <String, String>{
  'мойк': 'Мойка',
  'автомойк': 'Мойка',
  'шиномонтаж': 'Шиномонтаж',
  'шиномонтажн': 'Шиномонтаж',
  'детейлинг': 'Детейлинг',
  'детейл': 'Детейлинг',
  'автосервис': 'Автосервис',
  'сто': 'Автосервис',
  'техобслуживание': 'Автосервис',
  'кузовн': 'Кузовной',
  'кузовной': 'Кузовной',
  'электрик': 'Электрика',
  'электро': 'Электрика',
  'диагностик': 'Диагностика',
};

List<String> _mapYandexCategoriesToTypes(List<dynamic>? categories) {
  if (categories == null || categories.isEmpty) return ['Автосервис'];
  final types = <String>{};
  for (final c in categories) {
    if (c is! Map<String, dynamic>) continue;
    final name = (c['name'] as String?)?.toLowerCase() ?? '';
    final cls = (c['class'] as String?)?.toLowerCase() ?? '';
    for (final e in _categoryToType.entries) {
      if (name.contains(e.key) || cls.contains(e.key)) types.add(e.value);
    }
  }
  return types.isEmpty ? ['Автосервис'] : types.toList();
}

/// Сервис поиска организаций в видимой области карты через Yandex Geosearch API.
class YandexGeosearchService {
  YandexGeosearchService([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  /// true, если последний запрос вернул 403 (ключ не подходит для этого API).
  bool get lastRequestWasInvalidKey => _lastRequestWas403;
  bool _lastRequestWas403 = false;

  /// Загрузка ВСЕХ организаций (автосервисы, мойки, шиномонтаж, детейлинг) в видимой области:
  /// несколько поисковых запросов + пагинация по 50, затем объединение и дедупликация.
  Future<List<ExternalPOI>> searchInBounds({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    if (!hasYandexMapsApiKey) return [];
    _lastRequestWas403 = false;

    final bbox = '$minLng,$minLat~$maxLng,$maxLat';
    if (kDebugMode) {
      debugPrint('[Yandex Geosearch] Запрос bbox=$bbox');
    }
    final seenIds = <String>{};
    final all = <ExternalPOI>[];

    for (final text in _searchQueries) {
      int skip = 0;
      for (var page = 0; page < _maxPages; page++) {
        final list = await _requestPage(
          bbox: bbox,
          text: text,
          skip: skip,
        );
        if (list.isEmpty) break;
        for (final poi in list) {
          if (seenIds.add(poi.id)) all.add(poi);
        }
        if (list.length < _pageSize) break;
        skip += _pageSize;
      }
    }

    if (kDebugMode) {
      debugPrint('[Yandex Geosearch] Всего организаций в области: ${all.length}');
    }
    return all;
  }

  Future<List<ExternalPOI>> _requestPage({
    required String bbox,
    required String text,
    required int skip,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'apikey': yandexMapsApiKey,
        'text': text,
        'lang': 'ru_RU',
        'type': 'biz',
        'bbox': bbox,
        'rspn': '1',
        'results': '$_pageSize',
        'skip': '$skip',
      },
    );
    try {
      final response = await _dio.get<String>(uri.toString());
      if (response.statusCode == 403) {
        _lastRequestWas403 = true;
        final body = (response.data?.toString() ?? '').replaceAll('\n', ' ');
        debugPrint(
          '[Yandex Geosearch] HTTP 403 Invalid api key. '
          'Нужен ключ «API Поиска по организациям» в developer.tech.yandex.ru',
        );
        if (body.isNotEmpty) debugPrint('[Yandex Geosearch] body: ${body.length > 300 ? body.substring(0, 300) : body}');
        return [];
      }
      if (response.statusCode != 200) {
        final body = (response.data?.toString() ?? '').replaceAll('\n', ' ');
        debugPrint('[Yandex Geosearch] HTTP ${response.statusCode} body: ${body.length > 400 ? body.substring(0, 400) : body}');
        return [];
      }
      if (response.data == null) return [];
      final list = _parseResponse(response.data!);
      if (skip == 0 && list.isNotEmpty) {
        debugPrint('[Yandex Geosearch] "$text" bbox=$bbox → ${list.length} организаций');
      }
      return list;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) _lastRequestWas403 = true;
      debugPrint(
        '[Yandex Geosearch] Ошибка: ${e.type} ${e.response?.statusCode} '
        '${e.response?.data?.toString() ?? e.message}',
      );
      return [];
    }
  }

  List<ExternalPOI> _parseResponse(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>?;
      final features = data?['features'] as List<dynamic>?;
      if (features == null) return [];

      final list = <ExternalPOI>[];
      for (final f in features) {
        if (f is! Map<String, dynamic>) continue;
        final props = f['properties'] as Map<String, dynamic>?;
        final geometry = f['geometry'] as Map<String, dynamic>?;
        final coords = geometry?['coordinates'] as List<dynamic>?;
        if (props == null || coords == null || coords.length < 2) continue;

        final lon = (coords[0] is num) ? (coords[0] as num).toDouble() : null;
        final lat = (coords[1] is num) ? (coords[1] as num).toDouble() : null;
        if (lon == null || lat == null) continue;

        final name = props['name'] as String? ?? '';
        if (name.isEmpty) continue;

        final company = props['CompanyMetaData'] as Map<String, dynamic>?;
        final id = company?['id']?.toString() ?? '${lat}_${lon}';
        final categories = company?['Categories'] as List<dynamic>?;
        final types = _mapYandexCategoriesToTypes(categories);

        final addrMap = company?['Address'] as Map<String, dynamic>?;
        String? address = (addrMap?['formatted'] as String?)?.trim();
        String? phone;
        final phones = company?['Phones'] as List<dynamic>?;
        if (phones != null && phones.isNotEmpty) {
          final first = phones.first;
          if (first is Map && first['formatted'] != null) {
            phone = first['formatted'].toString().trim();
          }
        }

        list.add(ExternalPOI(
          id: id,
          name: name,
          lat: lat,
          lng: lon,
          types: types,
          phone: phone?.isNotEmpty == true ? phone : null,
          address: address?.isNotEmpty == true ? address : null,
        ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}
