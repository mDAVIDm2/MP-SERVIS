import 'package:dio/dio.dart';

import 'partner_app_config.dart';

/// Ответ 4xx/5xx с телом JSON — без «простыни» Dio про validateStatus.
class PartnerOrdersHttpException implements Exception {
  PartnerOrdersHttpException(this.statusCode, this.body);

  final int statusCode;
  final Object? body;

  @override
  String toString() => 'PartnerOrdersHttpException($statusCode)';
}

/// Клиент партнёрского API (Bearer), без пересечения с [ApiClient] MP-Servis.
class PartnerOrdersApi {
  PartnerOrdersApi({String? baseUrl, String? token})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? PartnerAppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 25),
            sendTimeout: const Duration(seconds: 25),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if ((token ?? PartnerAppConfig.apiToken).trim().isNotEmpty)
                'Authorization': 'Bearer ${(token ?? PartnerAppConfig.apiToken).trim()}',
            },
          ),
        );

  final Dio _dio;

  /// Схема формы по продуктам (JSONForms).
  Future<Map<String, dynamic>> fetchApplicationSchema(List<int> productIds) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/applications',
      data: {'products': productIds},
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  /// Создание заявки: продукты + поля по схеме партнёра.
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    final r = await _dio.post<dynamic>(
      '/orders',
      data: body,
      options: Options(
        validateStatus: (s) => s != null && s < 600,
      ),
    );
    final code = r.statusCode ?? 0;
    if (code >= 400) {
      throw PartnerOrdersHttpException(code, r.data);
    }
    return _normalizeOrderResponse(r.data);
  }

  /// Партнёрский API может вернуть объект, массив или обёртку — безопасно приводим к карте.
  static Map<String, dynamic> _normalizeOrderResponse(Object? raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) return <String, dynamic>{'data': raw};
    return <String, dynamic>{'data': raw};
  }

  static String _formatErrorBody(Object? data) {
    if (data == null) return '';
    if (data is String) {
      final t = data.trim();
      if (t.length > 800) return '${t.substring(0, 800)}…';
      return t;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final msg = map['message'] ?? map['error'] ?? map['detail'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
      final errs = map['errors'];
      if (errs is Map) {
        final parts = <String>[];
        for (final e in errs.entries) {
          final v = e.value;
          if (v is List) {
            for (final x in v) {
              parts.add('${e.key}: $x');
            }
          } else if (v != null) {
            parts.add('${e.key}: $v');
          }
        }
        if (parts.isNotEmpty) {
          return parts.length > 6 ? '${parts.take(6).join('; ')}…' : parts.join('; ');
        }
      }
      return map.toString();
    }
    return data.toString();
  }

  String describeError(Object e) {
    if (e is PartnerOrdersHttpException) {
      final s = _formatErrorBody(e.body);
      if (s.isNotEmpty) {
        return e.statusCode == 422
            ? 'Проверьте данные: $s'
            : 'Ошибка ${e.statusCode}: $s';
      }
      return 'Ошибка сервиса (${e.statusCode}).';
    }
    if (e is DioException) {
      final data = e.response?.data;
      final parsed = _formatErrorBody(data);
      if (parsed.isNotEmpty) return parsed;
      return e.message ?? e.toString();
    }
    return e.toString();
  }
}
