import 'package:dio/dio.dart';

import 'partner_app_config.dart';

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
    final r = await _dio.post<Map<String, dynamic>>(
      '/orders',
      data: body,
    );
    return Map<String, dynamic>.from(r.data ?? {});
  }

  String describeError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'] ?? data['detail'];
        if (msg != null) return msg.toString();
        return data.toString();
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }
}
