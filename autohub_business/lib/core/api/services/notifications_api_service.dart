import 'package:dio/dio.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';

/// API уведомлений: регистрация устройства для push, список уведомлений.
class NotificationsApiService {
  NotificationsApiService(this._client);

  final ApiClient _client;

  /// Зарегистрировать устройство для push-уведомлений.
  /// [fcmApp] — `business` для приложения Business (отдельный Firebase), иначе `client`.
  Future<Result<void>> registerDevice(
    String token,
    String platform, {
    String fcmApp = 'client',
  }) async {
    try {
      await _client.post(ApiEndpoints.registerPushToken, data: {
        'device_token': token,
        'platform': platform,
        'fcm_app': fcmApp,
      });
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Список уведомлений пользователя (опционально).
  Future<Result<List<Map<String, dynamic>>>> getNotifications() async {
    try {
      final res = await _client.get(ApiEndpoints.notifications);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат'));
      }
      final list = data['items'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];
      final items = list.map((e) => e as Map<String, dynamic>).toList();
      return Result.success(items);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
