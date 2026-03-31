import '../../../shared/models/notification_model.dart';
import '../../api/api_exceptions.dart';
import '../../constants/mock_data.dart';
import '../notification_repository.dart';

/// Мок-реализация NotificationRepository
class MockNotificationRepository implements NotificationRepository {
  @override
  Future<Result<List<NotificationItem>>> getNotifications({String? carId}) async {
    await _delay();
    var list = List<NotificationItem>.from(MockData.notifications);
    if (carId != null && carId.isNotEmpty) {
      list = list.where((n) => n.carId == carId || n.carId == null || n.carId!.isEmpty).toList();
    }
    return Result.success(list);
  }

  @override
  Future<Result<void>> markAsRead(String notificationId) async {
    await _delay(100);
    final index = MockData.notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final n = MockData.notifications[index];
      MockData.notifications[index] = NotificationItem(
        id: n.id,
        icon: n.icon,
        title: n.title,
        subtitle: n.subtitle,
        time: n.time,
        isRead: true,
        targetType: n.targetType,
        targetId: n.targetId,
        carId: n.carId,
        type: n.type,
        payload: n.payload,
      );
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> markReadByOrderId(String orderId) async {
    await _delay(80);
    for (int i = 0; i < MockData.notifications.length; i++) {
      final n = MockData.notifications[i];
      if (n.isRead) continue;
      if (n.targetId == orderId || n.payload?['order_id']?.toString() == orderId) {
        MockData.notifications[i] = NotificationItem(
          id: n.id,
          icon: n.icon,
          title: n.title,
          subtitle: n.subtitle,
          time: n.time,
          isRead: true,
          targetType: n.targetType,
          targetId: n.targetId,
          carId: n.carId,
          type: n.type,
          payload: n.payload,
        );
      }
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> markReadByChatId(String chatId) async {
    await _delay(80);
    for (int i = 0; i < MockData.notifications.length; i++) {
      final n = MockData.notifications[i];
      if (n.isRead) continue;
      if (n.payload?['chat_id']?.toString() == chatId) {
        MockData.notifications[i] = NotificationItem(
          id: n.id,
          icon: n.icon,
          title: n.title,
          subtitle: n.subtitle,
          time: n.time,
          isRead: true,
          targetType: n.targetType,
          targetId: n.targetId,
          carId: n.carId,
          type: n.type,
          payload: n.payload,
        );
      }
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> markAllAsRead({String? carId}) async {
    await _delay(200);
    for (int i = 0; i < MockData.notifications.length; i++) {
      final n = MockData.notifications[i];
      if (carId != null && n.carId != null && n.carId != carId) continue;
      MockData.notifications[i] = NotificationItem(
        id: n.id,
        icon: n.icon,
        title: n.title,
        subtitle: n.subtitle,
        time: n.time,
        isRead: true,
        targetType: n.targetType,
        targetId: n.targetId,
        carId: n.carId,
        type: n.type,
        payload: n.payload,
      );
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteNotification(String id) async {
    await _delay(100);
    MockData.notifications.removeWhere((n) => n.id == id);
    return Result.success(null);
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    await _delay(100);
    final count = MockData.notifications.where((n) => !n.isRead).length;
    return Result.success(count);
  }

  @override
  Future<Result<Map<String, int>>> getUnreadByCar() async {
    await _delay(100);
    final map = <String, int>{};
    for (final n in MockData.notifications.where((n) => !n.isRead)) {
      final key = n.carId ?? '';
      map[key] = (map[key] ?? 0) + 1;
    }
    return Result.success(map);
  }

  @override
  Future<Result<void>> registerPushToken(String token, {String platform = 'android'}) async {
    await _delay();
    return Result.success(null);
  }

  Future<void> _delay([int ms = 300]) async {
    await Future.delayed(Duration(milliseconds: ms));
  }
}
