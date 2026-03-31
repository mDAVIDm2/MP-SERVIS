import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

/// Уведомления клиента (список, отметка прочитано, регистрация push).
class NotificationApiService {
  NotificationApiService(this._client);
  final ApiClient _client;

  Future<Result<Map<String, dynamic>>> getNotifications({String? carId}) async {
    try {
      final query = carId != null && carId.isNotEmpty ? '?car_id=$carId' : '';
      final res = await _client.get('${ApiEndpoints.notifications}$query');
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> markAsRead(String id) async {
    try {
      await _client.post(ApiEndpoints.notificationRead(id));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> markAllAsRead({String? carId}) async {
    try {
      await _client.post('${ApiEndpoints.notifications}/mark-all-read', data: carId != null ? {'car_id': carId} : {});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> markReadByOrderId(String orderId) async {
    try {
      await _client.post('${ApiEndpoints.notifications}/mark-read-by-order', data: {'order_id': orderId});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> markReadByChatId(String chatId) async {
    try {
      await _client.post('${ApiEndpoints.notifications}/mark-read-by-chat', data: {'chat_id': chatId});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> deleteNotification(String id) async {
    try {
      await _client.delete('${ApiEndpoints.notifications}/$id');
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<int>> getUnreadCount() async {
    try {
      final res = await _client.get('${ApiEndpoints.notifications}/unread-count');
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.success(0);
      final c = data['count'];
      final count = c is int ? c : (c is num ? c.toInt() : 0);
      return Result.success(count);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, int>>> getUnreadByCar() async {
    try {
      final res = await _client.get('${ApiEndpoints.notifications}/unread-by-car');
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.success({});
      final map = <String, int>{};
      for (final e in data.entries) {
        final v = e.value;
        if (v is int) {
          map[e.key.toString()] = v;
        } else if (v is num) {
          map[e.key.toString()] = v.toInt();
        }
      }
      return Result.success(map);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> registerPushToken(String token, {String platform = 'android'}) async {
    try {
      await _client.post(ApiEndpoints.registerPushToken, data: {'device_token': token, 'platform': platform});
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Настройки уведомлений (синхронизируются с сервером для push и фильтра ленты).
  Future<Result<Map<String, dynamic>>> getNotificationPreferences() async {
    try {
      final res = await _client.get(ApiEndpoints.profileNotificationPreferences);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> patchNotificationPreferences(Map<String, dynamic> body) async {
    try {
      final res = await _client.patch(ApiEndpoints.profileNotificationPreferences, data: body);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
