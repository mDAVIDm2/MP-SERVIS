import '../../shared/models/notification_model.dart';
import '../api/api_exceptions.dart';

/// Абстрактный репозиторий уведомлений
abstract class NotificationRepository {
  /// Уведомления (опционально по carId)
  Future<Result<List<NotificationItem>>> getNotifications({String? carId});

  /// Отметить прочитанным
  Future<Result<void>> markAsRead(String notificationId);

  /// Отметить все прочитанными (опционально по carId)
  Future<Result<void>> markAllAsRead({String? carId});

  /// Непрочитанные с payload.order_id (после согласования / действий по заказу в чате).
  Future<Result<void>> markReadByOrderId(String orderId);

  /// Непрочитанные с payload.chat_id (после открытия диалога с сервисом).
  Future<Result<void>> markReadByChatId(String chatId);

  /// Удалить уведомление
  Future<Result<void>> deleteNotification(String id);

  /// Кол-во непрочитанных
  Future<Result<int>> getUnreadCount();

  /// Непрочитанные по машинам: carId -> count
  Future<Result<Map<String, int>>> getUnreadByCar();

  /// Зарегистрировать push-токен
  Future<Result<void>> registerPushToken(String token, {String platform = 'android'});
}
