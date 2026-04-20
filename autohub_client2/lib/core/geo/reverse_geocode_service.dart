import 'package:dio/dio.dart';

/// Обратный геокодинг через публичный Nominatim (OSM).
/// См. https://operations.osmfoundation.org/policies/nominatim/ — не чаще ~1 запроса/сек с клиента;
/// используем кэш по округлённым координатам.
abstract final class ReverseGeocodeService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'Accept': 'application/json',
        // Идентификация приложения обязательна для Nominatim
        'User-Agent': 'MP-Servis-Client/1.0 (Flutter; maintenance geocoding)',
      },
    ),
  );

  static final Map<String, String> _cache = {};

  static String _cacheKey(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';

  /// [display_name] на русском где возможно, иначе как вернёт сервер.
  static Future<String?> lookup(double lat, double lng) async {
    final k = _cacheKey(lat, lng);
    if (_cache.containsKey(k)) {
      final v = _cache[k]!;
      return v.isEmpty ? null : v;
    }
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: <String, dynamic>{
          'format': 'jsonv2',
          'lat': lat,
          'lon': lng,
          'accept-language': 'ru',
        },
      );
      final data = resp.data;
      final raw = data?['display_name'] as String?;
      if (raw == null || raw.trim().isEmpty) {
        _cache[k] = '';
        return null;
      }
      final trimmed = raw.trim();
      _cache[k] = trimmed;
      return trimmed;
    } catch (_) {
      _cache[k] = '';
      return null;
    }
  }
}
