import '../../shared/models/notification_model.dart';
import '../api/api_exceptions.dart';
import '../api/notification_api_service.dart';
import '../utils/pending_car_notification_payload.dart';
import 'notification_repository.dart';

/// Уведомления через API (общий бэкенд). Данные привязаны к авторизованному пользователю.
class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);
  final NotificationApiService _api;

  static NotificationItem _itemFromJson(Map<String, dynamic> j) {
    final atStr = j['createdAt'] ?? j['created_at'];
    final at = atStr != null ? DateTime.tryParse(atStr.toString()) ?? DateTime.now() : DateTime.now();
    final typeStr = j['type']?.toString();
    final type = notificationTypeFromString(typeStr);
    final body = j['body']?.toString();
    final payload = PendingCarNotificationPayload.asStringKeyedMap(j['payload']);
    var targetId = j['target_id']?.toString();
    if (targetId == null || targetId.isEmpty) {
      if (payload != null) {
        targetId = payload['target_id']?.toString() ??
            payload['order_id']?.toString() ??
            payload['chat_id']?.toString();
      }
    }
    final targetType = _targetFromString(
      j['target_type']?.toString() ?? payload?['target_type']?.toString(),
      typeStr,
    );
    return NotificationItem(
      id: j['id']?.toString() ?? '',
      icon: j['icon']?.toString() ?? '🔔',
      title: j['title']?.toString() ?? '',
      subtitle: body ?? j['subtitle']?.toString() ?? '',
      time: at,
      isRead: j['isRead'] == true || j['is_read'] == true,
      targetType: targetType,
      targetId: targetId,
      carId: j['carId']?.toString() ?? j['car_id']?.toString(),
      type: type,
      payload: payload,
    );
  }

  static NotificationTarget _targetFromString(String? v, String? typeStr) {
    if (v != null) {
      switch (v.toLowerCase()) {
        case 'order': return NotificationTarget.order;
        case 'chat': return NotificationTarget.chat;
        case 'garage': return NotificationTarget.garage;
        case 'profile': return NotificationTarget.profile;
      }
    }
    if (typeStr != null && (typeStr.contains('pending_car') || typeStr.contains('order') || typeStr.contains('chat'))) {
      if (typeStr.contains('order')) return NotificationTarget.order;
      if (typeStr.contains('chat')) return NotificationTarget.chat;
      return NotificationTarget.garage;
    }
    return NotificationTarget.none;
  }

  @override
  Future<Result<List<NotificationItem>>> getNotifications({String? carId}) async {
    final result = await _api.getNotifications(carId: carId);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final list = (data['items'] as List<dynamic>?) ?? [];
    final items = list
        .map((e) => _itemFromJson(e as Map<String, dynamic>))
        .where((n) => n.id.isNotEmpty)
        .toList();
    return Result.success(items);
  }

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    final result = await _api.markAsRead(notificationId);
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(null);
  }

  @override
  Future<Result<void>> markAllAsRead({String? carId}) async {
    final result = await _api.markAllAsRead(carId: carId);
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(null);
  }

  @override
  Future<Result<void>> markReadByOrderId(String orderId) async {
    final result = await _api.markReadByOrderId(orderId);
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(null);
  }

  @override
  Future<Result<void>> markReadByChatId(String chatId) async {
    final result = await _api.markReadByChatId(chatId);
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(null);
  }

  @override
  Future<Result<void>> deleteNotification(String id) async {
    final result = await _api.deleteNotification(id);
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(null);
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    final result = await _api.getUnreadCount();
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(result.dataOrNull ?? 0);
  }

  @override
  Future<Result<Map<String, int>>> getUnreadByCar() async {
    final result = await _api.getUnreadByCar();
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(result.dataOrNull ?? {});
  }

  @override
  Future<Result<void>> registerPushToken(String token, {String platform = 'android'}) async {
    final result = await _api.registerPushToken(token, platform: platform);
    return result.errorOrNull != null ? Result.failure(result.errorOrNull!) : Result.success(null);
  }
}
