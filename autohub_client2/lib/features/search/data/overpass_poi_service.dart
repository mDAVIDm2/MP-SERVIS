import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/models/external_poi.dart';

/// Публичный Overpass API (OpenStreetMap). Бесплатно, без ключа.
const _overpassUrl = 'https://overpass-api.de/api/interpreter';

/// Сервис поиска организаций (автосервис, мойки, шиномонтаж) по видимой области через Overpass API (OSM).
/// Используется как бесплатный запасной вариант, когда Yandex API недоступен или без лицензии.
class OverpassPoiService {
  OverpassPoiService([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Южная, западная, северная, восточная границы (градусы).
  Future<List<ExternalPOI>> searchInBounds({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final south = minLat;
    final west = minLng;
    final north = maxLat;
    final east = maxLng;

    // См. https://wiki.openstreetmap.org/wiki/Overpass_API
    // Мойки: amenity=car_wash; автосервис: shop=car_repair; шиномонтаж: shop=tyres
    // bbox: (south, west, north, east)
    final bbox = '($south,$west,$north,$east)';
    final body = '''
[out:json][timeout:25];
(
  node["amenity"="car_wash"]$bbox;
  node["shop"="car_repair"]$bbox;
  node["shop"="tyres"]$bbox;
  way["amenity"="car_wash"]$bbox;
  way["shop"="car_repair"]$bbox;
  way["shop"="tyres"]$bbox;
);
out center;
''';

    try {
      final response = await _dio.post<String>(
        _overpassUrl,
        data: body,
        options: Options(
          contentType: 'text/plain; charset=utf-8',
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode != 200 || response.data == null) return [];
      final list = _parseResponse(response.data!);
      if (kDebugMode && list.isNotEmpty) {
        debugPrint('[Overpass POI] Найдено организаций в области: ${list.length}');
      }
      return list;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[Overpass POI] Ошибка: ${e.type} ${e.message}');
      }
      return [];
    }
  }

  List<ExternalPOI> _parseResponse(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>?;
      final elements = data?['elements'] as List<dynamic>?;
      if (elements == null) return [];

      final list = <ExternalPOI>[];
      for (final el in elements) {
        if (el is! Map<String, dynamic>) continue;

        double? lat;
        double? lon;
        if (el['lat'] != null && el['lon'] != null) {
          lat = (el['lat'] as num).toDouble();
          lon = (el['lon'] as num).toDouble();
        } else if (el['center'] != null) {
          final c = el['center'] as Map<String, dynamic>;
          lat = (c['lat'] as num?)?.toDouble();
          lon = (c['lon'] as num?)?.toDouble();
        }
        if (lat == null || lon == null) continue;

        final tags = el['tags'] as Map<String, dynamic>?;
        final name = (tags?['name'] as String?)?.trim() ?? 'Организация';
        final type = el['type'] as String? ?? '';
        final id = (el['id'] as Object?).toString();
        final osmId = '${type}_$id';

        final phone = (tags?['phone'] ?? tags?['contact:phone'])?.toString().trim();
        String? address;
        if (tags != null) {
          address = (tags['addr:full'] as String?)?.trim();
          if (address == null || address!.isEmpty) {
            final street = (tags['addr:street'] as String?)?.trim();
            final house = (tags['addr:housenumber'] as String?)?.trim();
            if (street != null && street.isNotEmpty) {
              address = house != null && house.isNotEmpty ? '$street, $house' : street;
            }
          }
        }

        final types = <String>[];
        if (tags != null) {
          if (tags['amenity'] == 'car_wash') types.add('Мойка');
          if (tags['shop'] == 'car_repair') types.add('Автосервис');
          if (tags['shop'] == 'tyres') types.add('Шиномонтаж');
        }
        if (types.isEmpty) types.add('Автосервис');

        list.add(ExternalPOI(
          id: osmId,
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
