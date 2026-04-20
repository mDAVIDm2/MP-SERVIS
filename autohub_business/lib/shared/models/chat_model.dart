import 'dart:typed_data';

/// Вложение к сообщению чата (изображение).
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

/// Изображения для POST …/messages/with-media.
class ChatOutgoingImage {
  final Uint8List bytes;
  final String filename;
  const ChatOutgoingImage({required this.bytes, required this.filename});
}

/// Чат с клиентом (один чат на клиента в рамках организации).
class ChatPreview {
  final String id;
  final String orderId;
  final String orderNumber;
  final String clientName;
  final String clientPhone;
  /// URL фото профиля клиента (с API `client_avatar_url`), для списка и ленты чата в приложении организации.
  final String? clientAvatarUrl;
  final String lastMessageText;
  final DateTime lastMessageAt;
  final int unreadCount;
  /// Чат поддержки (без привязки к организации).
  final bool isSupportChat;

  const ChatPreview({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.clientName,
    this.clientPhone = '',
    this.clientAvatarUrl,
    required this.lastMessageText,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isSupportChat = false,
  });

  static DateTime _parseAt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) {
      final d = DateTime.tryParse(v);
      return (d != null && d.isUtc ? d.toLocal() : d) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Чат поддержки: явный флаг API или пустой organization_id + телефон / название.
  static bool _inferSupportChat(Map<String, dynamic> j) {
    if (j['is_support_chat'] == true) return true;
    final org = '${j['organization_id'] ?? j['organizationId'] ?? ''}'.trim();
    final phoneDigits = '${j['client_phone'] ?? j['clientPhone'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
    final orgName = '${j['organization_name'] ?? j['organizationName'] ?? ''}'.toLowerCase();
    if (org.isEmpty && phoneDigits.length >= 10) return true;
    if (org.isEmpty && orgName.contains('поддержка')) return true;
    return false;
  }

  static ChatPreview fromJson(Map<String, dynamic> j) {
    return ChatPreview(
      id: j['id'] as String? ?? '',
      orderId: j['order_id'] as String? ?? '',
      orderNumber: j['order_number'] as String? ?? '',
      clientName: j['client_name'] as String? ?? '',
      clientPhone: j['client_phone'] as String? ?? '',
      clientAvatarUrl: () {
        final u = j['client_avatar_url']?.toString() ?? j['clientAvatarUrl']?.toString() ?? '';
        return u.trim().isEmpty ? null : u.trim();
      }(),
      lastMessageText: j['last_message_text'] as String? ?? '',
      lastMessageAt: _parseAt(j['last_message_at']),
      unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
      isSupportChat: _inferSupportChat(j),
    );
  }
}

/// Позиция в запросе согласования. [id] — стабильный id для new_items (клиент шлёт approved_item_ids по ним).
class ApprovalItem {
  final String name;
  final int priceKopecks;
  final int estimatedMinutes;
  final String? id;

  const ApprovalItem({
    required this.name,
    required this.priceKopecks,
    this.estimatedMinutes = 60,
    this.id,
  });
}

/// Скорректированная позиция заказа (есть id из БД, новые цена и время).
class EditedApprovalItem {
  final String id;
  final String name;
  final int priceKopecks;
  final int estimatedMinutes;

  const EditedApprovalItem({
    required this.id,
    required this.name,
    required this.priceKopecks,
    this.estimatedMinutes = 60,
  });
}

/// Статус ответа клиента на запрос согласования.
enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

/// Сообщение в чате: текст или карточка запроса согласования.
class ChatMessage {
  final String id;
  final String text;
  final bool isFromClient;
  final DateTime at;
  final bool isText;
  /// Устаревшее: один список (старые сообщения). Если не null — считаем как newApprovalItems.
  final List<ApprovalItem>? approvalItems;
  /// Скорректированные услуги заказа (id, новая цена, время). Новый формат.
  final List<EditedApprovalItem>? editedApprovalItems;
  /// Добавленные услуги. Новый формат или legacy (тогда approvalItems дублирует).
  final List<ApprovalItem>? newApprovalItems;
  final ApprovalStatus? approvalStatus;
  final DateTime? proposedDateTime;
  final String? orderId;
  final bool isSystem;
  /// Тип сообщения: 'booking_card' — заявка клиента (без кнопок), 'approval_request' — запрос согласования.
  final String? messageType;
  /// Снимок услуг для карточки «Заявка отправлена» (только при message_type == booking_card).
  final List<ApprovalItem>? orderItemsSnapshot;
  /// Исходный состав заказа (для сводки в approval-card). Из approval_items.original_items.
  final List<ApprovalItem>? originalApprovalItems;
  final int? totalsBeforePriceKopecks;
  final int? totalsBeforeMinutes;
  final int? totalsAfterPriceKopecks;
  final int? totalsAfterMinutes;
  /// ID машины, для которой запрос согласования (если пусто — «для всех машин»).
  final String? approvalCarId;
  /// Ответ оператора поддержки (чат поддержки).
  final bool isFromSupportOperator;
  /// Источник обращения: client | business (только чат поддержки).
  final String? supportChannel;
  final List<ChatAttachment> attachments;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isFromClient,
    required this.at,
    this.isText = true,
    this.approvalItems,
    this.editedApprovalItems,
    this.newApprovalItems,
    this.approvalStatus,
    this.proposedDateTime,
    this.orderId,
    this.isSystem = false,
    this.messageType,
    this.orderItemsSnapshot,
    this.originalApprovalItems,
    this.totalsBeforePriceKopecks,
    this.totalsBeforeMinutes,
    this.totalsAfterPriceKopecks,
    this.totalsAfterMinutes,
    this.approvalCarId,
    this.isFromSupportOperator = false,
    this.supportChannel,
    this.attachments = const [],
  });

  /// Карточка «Заявка отправлена» от клиента — не показывать как пустое текстовое сообщение.
  bool get isBookingCard => messageType == 'booking_card';
  bool get isApprovalCard =>
      (editedApprovalItems != null && editedApprovalItems!.isNotEmpty) ||
      (newApprovalItems != null && newApprovalItems!.isNotEmpty) ||
      (approvalItems != null && approvalItems!.isNotEmpty);
  int get approvalTotalKopecks =>
      (editedApprovalItems ?? []).fold<int>(0, (s, i) => s + i.priceKopecks) +
      (newApprovalItems ?? []).fold<int>(0, (s, i) => s + i.priceKopecks) +
      (approvalItems ?? []).fold<int>(0, (s, i) => s + i.priceKopecks);
  int get approvalTotalMinutes =>
      (editedApprovalItems ?? []).fold<int>(0, (s, i) => s + i.estimatedMinutes) +
      (newApprovalItems ?? []).fold<int>(0, (s, i) => s + i.estimatedMinutes) +
      (approvalItems ?? []).fold<int>(0, (s, i) => s + i.estimatedMinutes);

  static ApprovalStatus _approvalStatusFromString(String? s) {
    if (s == null) return ApprovalStatus.pending;
    switch (s.toLowerCase()) {
      case 'approved': return ApprovalStatus.approved;
      case 'rejected': return ApprovalStatus.rejected;
      default: return ApprovalStatus.pending;
    }
  }

  static DateTime _parseAt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) {
      final d = DateTime.tryParse(v);
      return (d != null && d.isUtc ? d.toLocal() : d) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<ApprovalItem> _parseApprovalList(List<dynamic>? list, {bool withId = false}) {
    if (list == null) return [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return ApprovalItem(
        name: m['name'] as String? ?? '',
        priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? (m['priceKopecks'] as num?)?.toInt() ?? 0,
        estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? (m['estimatedMinutes'] as num?)?.toInt() ?? 60,
        id: withId ? m['id']?.toString() : null,
      );
    }).toList();
  }

  static List<EditedApprovalItem> _parseEditedList(List<dynamic>? list) {
    if (list == null) return [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final id = m['id'];
      return EditedApprovalItem(
        id: id == null ? '' : id.toString(),
        name: m['name'] as String? ?? '',
        priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? (m['priceKopecks'] as num?)?.toInt() ?? 0,
        estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? (m['estimatedMinutes'] as num?)?.toInt() ?? 60,
      );
    }).toList();
  }

  static ChatMessage fromJson(Map<String, dynamic> j) {
    final approvalItemsRaw = j['approval_items'] ?? j['approvalItems'];
    List<ApprovalItem>? approvalItemsLegacy;
    List<EditedApprovalItem>? editedApprovalItems;
    List<ApprovalItem>? newApprovalItems;

    List<ApprovalItem>? originalApprovalItems;
    int? totalsBeforePriceKopecks, totalsBeforeMinutes, totalsAfterPriceKopecks, totalsAfterMinutes;
    if (approvalItemsRaw is List<dynamic>) {
      approvalItemsLegacy = _parseApprovalList(approvalItemsRaw);
    } else if (approvalItemsRaw is Map<String, dynamic>) {
      final editedRaw = approvalItemsRaw['edited_items'] ?? approvalItemsRaw['editedItems'];
      final newRaw = approvalItemsRaw['new_items'] ?? approvalItemsRaw['newItems'];
      editedApprovalItems = _parseEditedList(editedRaw as List<dynamic>?);
      newApprovalItems = _parseApprovalList(newRaw as List<dynamic>?, withId: true);
      final origRaw = approvalItemsRaw['original_items'] ?? approvalItemsRaw['originalItems'];
      if (origRaw is List<dynamic> && origRaw.isNotEmpty) {
        originalApprovalItems = _parseApprovalList(origRaw, withId: true);
      }
      final tb = approvalItemsRaw['totals_before'] ?? approvalItemsRaw['totalsBefore'];
      if (tb is Map) {
        final pk = tb['price_kopecks'] ?? tb['priceKopecks'];
        totalsBeforePriceKopecks = pk is num ? pk.toInt() : null;
        final em = tb['estimated_minutes'] ?? tb['estimatedMinutes'];
        totalsBeforeMinutes = em is num ? em.toInt() : null;
      }
      final ta = approvalItemsRaw['totals_after'] ?? approvalItemsRaw['totalsAfter'];
      if (ta is Map) {
        final pk = ta['price_kopecks'] ?? ta['priceKopecks'];
        totalsAfterPriceKopecks = pk is num ? pk.toInt() : null;
        final em = ta['estimated_minutes'] ?? ta['estimatedMinutes'];
        totalsAfterMinutes = em is num ? em.toInt() : null;
      }
    }

    final hasApproval = (approvalItemsLegacy != null && approvalItemsLegacy.isNotEmpty) ||
        (editedApprovalItems != null && editedApprovalItems.isNotEmpty) ||
        (newApprovalItems != null && newApprovalItems.isNotEmpty);
    final proposedDtRaw = (j['proposed_date_time'] ?? j['proposedDateTime']) != null
        ? DateTime.tryParse((j['proposed_date_time'] ?? j['proposedDateTime']).toString())
        : null;
    final proposedDt = proposedDtRaw != null && proposedDtRaw.isUtc
        ? proposedDtRaw.toLocal()
        : proposedDtRaw;
    final isSystem = j['is_system'] as bool? ?? j['isSystem'] as bool? ?? false;
    final orderId = j['order_id'] as String? ?? j['orderId'] as String?;
    final messageType = j['message_type'] as String? ?? j['messageType'] as String?;
    List<ApprovalItem>? orderItemsSnapshot;
    final snapshotRaw = j['order_items_snapshot'] ?? j['orderItemsSnapshot'];
    if (snapshotRaw is List<dynamic> && snapshotRaw.isNotEmpty) {
      orderItemsSnapshot = _parseApprovalList(snapshotRaw);
    }
    final atRaw = j['at'] ?? j['created_at'] ?? j['createdAt'];
    final approvalCarId = j['car_id'] as String? ?? j['carId'] as String?;
    final carIdStr = approvalCarId?.trim();
    final fromOp = j['is_from_support_operator'] == true ||
        j['isFromSupportOperator'] == true ||
        messageType == 'support_operator_reply';
    final ch = j['support_channel'] as String? ?? j['supportChannel'] as String?;
    final attRaw = j['attachments'];
    final attachments = <ChatAttachment>[];
    if (attRaw is List<dynamic>) {
      for (final e in attRaw) {
        final a = ChatAttachment.fromJson(e);
        if (a != null) attachments.add(a);
      }
    }
    return ChatMessage(
      id: j['id'] as String? ?? '',
      text: j['text'] as String? ?? '',
      isFromClient: j['is_from_client'] as bool? ?? j['isFromClient'] as bool? ?? false,
      at: _parseAt(atRaw),
      isText: (j['is_text'] as bool? ?? j['isText'] as bool?) ?? !hasApproval,
      approvalItems: approvalItemsLegacy,
      editedApprovalItems: editedApprovalItems?.isEmpty == true ? null : editedApprovalItems,
      newApprovalItems: newApprovalItems?.isEmpty == true ? null : newApprovalItems,
      approvalStatus: hasApproval ? _approvalStatusFromString((j['approval_status'] ?? j['approvalStatus']) as String?) : null,
      proposedDateTime: proposedDt,
      orderId: orderId,
      isSystem: isSystem,
      messageType: messageType,
      orderItemsSnapshot: orderItemsSnapshot,
      originalApprovalItems: originalApprovalItems?.isEmpty == true ? null : originalApprovalItems,
      totalsBeforePriceKopecks: totalsBeforePriceKopecks,
      totalsBeforeMinutes: totalsBeforeMinutes,
      totalsAfterPriceKopecks: totalsAfterPriceKopecks,
      totalsAfterMinutes: totalsAfterMinutes,
      approvalCarId: (carIdStr != null && carIdStr.isNotEmpty) ? carIdStr : null,
      isFromSupportOperator: fromOp,
      supportChannel: ch,
      attachments: attachments,
    );
  }
}
