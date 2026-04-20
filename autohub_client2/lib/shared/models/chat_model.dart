import 'dart:typed_data';

import 'order_model.dart';
import 'organization_chat_subtitle.dart';

/// Вложение к сообщению чата (изображение), URL с бэкенда — с JWT в GET.
class ChatAttachment {
  final String id;
  final String url;
  final String mimeType;
  final int? width;
  final int? height;
  final int sizeBytes;

  const ChatAttachment({
    required this.id,
    required this.url,
    required this.mimeType,
    this.width,
    this.height,
    this.sizeBytes = 0,
  });

  static ChatAttachment? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id']?.toString() ?? '';
    final url = raw['url']?.toString() ?? '';
    if (id.isEmpty || url.isEmpty) return null;
    return ChatAttachment(
      id: id,
      url: url,
      mimeType: raw['mime_type']?.toString() ?? raw['mimeType']?.toString() ?? 'image/webp',
      width: (raw['width'] as num?)?.toInt(),
      height: (raw['height'] as num?)?.toInt(),
      sizeBytes: (raw['size_bytes'] as num?)?.toInt() ?? (raw['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Изображение для отправки в чат (байты + имя файла для multipart).
class ChatOutgoingImage {
  final Uint8List bytes;
  final String filename;

  const ChatOutgoingImage({required this.bytes, required this.filename});
}

/// Позиция в запросе согласования от сервиса. [id] — стабильный id для сопоставления с approved_item_ids.
class ApprovalMessageItem {
  final String name;
  final int priceKopecks;
  final int estimatedMinutes;
  final String? id;

  const ApprovalMessageItem({
    required this.name,
    required this.priceKopecks,
    this.estimatedMinutes = 60,
    this.id,
  });
}

class ChatMessage {
  final String id;
  final String chatId;
  final String? senderId;
  final bool isFromUser;
  final bool isSystem;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final MessageDeliveryStatus deliveryStatus;
  /// Позиции из запроса согласования (подтверждение/корректировка от сервиса). Legacy: один список.
  final List<ApprovalMessageItem>? approvalItems;
  /// Скорректированные услуги (новый формат: объект с edited_items).
  final List<ApprovalMessageItem>? editedApprovalItems;
  /// Добавленные услуги (новый формат: объект с new_items).
  final List<ApprovalMessageItem>? newApprovalItems;
  /// Предложенное сервисом время приёма.
  final DateTime? proposedDateTime;
  /// Заказ, к которому относится сообщение (карточка согласования).
  final String? orderId;
  /// Снимок услуг для карточки «Заявка отправлена» (message_type = booking_card). Не approval.
  final List<ApprovalMessageItem>? orderItemsSnapshot;
  /// Исходный состав заказа (approval payload: original_items).
  final List<ApprovalMessageItem>? originalApprovalItems;
  final int? totalsBeforePriceKopecks;
  final int? totalsBeforeMinutes;
  final int? totalsAfterPriceKopecks;
  final int? totalsAfterMinutes;
  /// ID машины, для которой запрос (пусто = «для всех машин»).
  final String? approvalCarId;
  /// Изображения, прикреплённые к сообщению (GET списка / отправка with-media).
  final List<ChatAttachment> attachments;

  const ChatMessage({
    required this.id,
    required this.chatId,
    this.senderId,
    required this.isFromUser,
    this.isSystem = false,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.deliveryStatus = MessageDeliveryStatus.read,
    this.approvalItems,
    this.editedApprovalItems,
    this.newApprovalItems,
    this.proposedDateTime,
    this.orderId,
    this.orderItemsSnapshot,
    this.originalApprovalItems,
    this.totalsBeforePriceKopecks,
    this.totalsBeforeMinutes,
    this.totalsAfterPriceKopecks,
    this.totalsAfterMinutes,
    this.approvalCarId,
    this.attachments = const [],
  });

  /// Карточка первичной заявки (без кнопок согласования). Не считать approval.
  bool get isBookingCard => type == MessageType.bookingCard;

  int get approvalTotalKopecks =>
      (editedApprovalItems ?? <ApprovalMessageItem>[]).fold<int>(0, (s, i) => s + i.priceKopecks) +
      (newApprovalItems ?? <ApprovalMessageItem>[]).fold<int>(0, (s, i) => s + i.priceKopecks) +
      (approvalItems ?? <ApprovalMessageItem>[]).fold<int>(0, (s, i) => s + i.priceKopecks);
  int get approvalTotalMinutes =>
      (editedApprovalItems ?? <ApprovalMessageItem>[]).fold<int>(0, (s, i) => s + i.estimatedMinutes) +
      (newApprovalItems ?? <ApprovalMessageItem>[]).fold<int>(0, (s, i) => s + i.estimatedMinutes) +
      (approvalItems ?? <ApprovalMessageItem>[]).fold<int>(0, (s, i) => s + i.estimatedMinutes);
}

enum MessageType { text, photo, voice, system, approval, bookingCard }

enum MessageDeliveryStatus { pending, sent, delivered, read, error }

class Chat {
  final String id;
  final String stoId;
  final String stoName;
  /// Код вида бизнеса организации (`organization_kind` в API). Для подписи «Чат с …».
  final String? organizationKind;
  final String? stoLogoUrl;
  /// Телефон организации (с API `organization_phone`).
  final String? stoPhone;
  final String orderId;
  final String orderNumber;
  final String carBrand;
  final String carModel;
  final OrderStatus orderStatus;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool lastMessageFromUser;
  final MessageDeliveryStatus lastMessageStatus;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  /// Машина заказа превью в списке чатов (с API `car_id`).
  final String? previewCarId;
  /// Заказ, к которому относится последнее сообщение (`last_message_order_id`).
  final String? lastMessageOrderId;

  const Chat({
    required this.id,
    required this.stoId,
    required this.stoName,
    this.organizationKind,
    this.stoLogoUrl,
    this.stoPhone,
    required this.orderId,
    required this.orderNumber,
    required this.carBrand,
    required this.carModel,
    required this.orderStatus,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageFromUser = false,
    this.lastMessageStatus = MessageDeliveryStatus.read,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.previewCarId,
    this.lastMessageOrderId,
  });

  bool get needsAction => orderStatus == OrderStatus.pendingApproval;

  /// Чат поддержки (нет organization_id на бэкенде).
  bool get isSupportChat => stoId.isEmpty;

  /// Вторая строка в шапке чата / списка (не для поддержки).
  String get chatWithOrganizationSubtitle =>
      isSupportChat ? 'Поддержка' : chatSubtitleForOrganizationKind(organizationKind);
}

/// Машина для отображения непрочитанного: сначала заказ последнего сообщения, иначе превью.
String? attributedCarIdForChatUnread(Chat chat, List<Order> orders) {
  final mid = chat.lastMessageOrderId?.trim();
  if (mid != null && mid.isNotEmpty) {
    for (final o in orders) {
      if (o.id == mid) {
        final cid = o.carId.trim();
        if (cid.isNotEmpty) return cid;
      }
    }
  }
  final pc = chat.previewCarId?.trim();
  if (pc != null && pc.isNotEmpty) return pc;
  return null;
}

/// Непрочитанное с учётом выбранной машины (чат поддержки — всегда полный счётчик).
int effectiveUnreadForSelectedCar(
  Chat chat, {
  required bool filterByCar,
  String? selectedCarId,
  required List<Order> orders,
}) {
  if (chat.stoId.isEmpty) {
    return chat.unreadCount;
  }
  if (!filterByCar || selectedCarId == null || selectedCarId.isEmpty) {
    return chat.unreadCount;
  }
  final attributed = attributedCarIdForChatUnread(chat, orders);
  if (attributed != null && attributed.isNotEmpty) {
    return attributed == selectedCarId ? chat.unreadCount : 0;
  }
  final inSto = orders.where((o) => o.stoId == chat.stoId).toList();
  if (inSto.isEmpty) {
    return chat.unreadCount;
  }
  final carIds = inSto.map((o) => o.carId).where((id) => id.isNotEmpty).toSet();
  if (carIds.length <= 1) {
    final only = carIds.isEmpty ? null : carIds.single;
    if (only == null) return chat.unreadCount;
    return only == selectedCarId ? chat.unreadCount : 0;
  }
  return 0;
}

/// Пока заказы не подгружены при включённом фильтре по машине — показываем полный счётчик (список ещё не сужен).
int chatUnreadForChatsScreen(
  Chat chat, {
  required bool filterByCar,
  String? selectedCarId,
  required bool ordersReady,
  required List<Order> orders,
}) {
  if (!ordersReady || !filterByCar || selectedCarId == null || selectedCarId.isEmpty) {
    return chat.unreadCount;
  }
  return effectiveUnreadForSelectedCar(
    chat,
    filterByCar: true,
    selectedCarId: selectedCarId,
    orders: orders,
  );
}
