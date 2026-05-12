/// Тип цели уведомления для навигации
enum NotificationTarget { order, chat, garage, profile, none }

/// Тип уведомления с бэкенда (pending_car_approved, pending_car_rejected, pending_car_suggested и др.)
enum NotificationType {
  pendingCarApproved,
  pendingCarRejected,
  pendingCarSuggested,
  order,
  chat,
  general,
  carTransferRequest,
  carTransferResult,
  unknown,
}

/// Модель уведомления
class NotificationItem {
  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final DateTime time;
  final bool isRead;
  final NotificationTarget targetType;
  final String? targetId;
  final String? carId;
  final NotificationType type;
  final Map<String, dynamic>? payload;

  const NotificationItem({
    required this.id,
    this.icon = '🔔',
    required this.title,
    required this.subtitle,
    required this.time,
    this.isRead = false,
    this.targetType = NotificationTarget.none,
    this.targetId,
    this.carId,
    this.type = NotificationType.unknown,
    this.payload,
  });
}

NotificationType notificationTypeFromString(String? v) {
  switch (v) {
    case 'pending_car_approved': return NotificationType.pendingCarApproved;
    case 'pending_car_rejected': return NotificationType.pendingCarRejected;
    case 'pending_car_suggested': return NotificationType.pendingCarSuggested;
    case 'order': return NotificationType.order;
    case 'chat': return NotificationType.chat;
    case 'car_transfer_request': return NotificationType.carTransferRequest;
    case 'car_transfer_result': return NotificationType.carTransferResult;
    default: return NotificationType.unknown;
  }
}
