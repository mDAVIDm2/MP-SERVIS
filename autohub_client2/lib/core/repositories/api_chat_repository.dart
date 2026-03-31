import 'package:flutter/foundation.dart';

import '../../shared/models/chat_model.dart';
import '../../shared/models/order_model.dart';
import '../api/api_exceptions.dart';
import '../api/chat_api_service.dart';
import 'chat_repository.dart';

/// Извлекает список сообщений из ответа GET /chats/:id/messages. Поддержка: items, data, messages и обёртка { data: { items: [...] } }.
List<dynamic> _parseMessageListFromResponse(Map<String, dynamic> data) {
  final raw = data['items'] ?? data['data'] ?? data['messages'];
  if (raw is List<dynamic>) return raw;
  if (raw is Map<String, dynamic>) {
    final inner = raw['items'] ?? raw['data'] ?? raw['messages'];
    if (inner is List<dynamic>) return inner;
  }
  return [];
}

/// Извлекает объект сообщения из ответа POST /chats/:id/messages. Поддержка: { data: {...} }, { message: {...} }, {...}.
Map<String, dynamic> _unwrapPostMessageResponse(Map<String, dynamic> data) {
  final dataField = data['data'];
  if (dataField is Map<String, dynamic>) return dataField;
  final messageField = data['message'];
  if (messageField is Map<String, dynamic>) return messageField;
  return data;
}

/// Репозиторий чатов через API (общий бэкенд с Business).
class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._api);
  final ChatApiService _api;

  static Chat _chatFromJson(Map<String, dynamic> j) {
    final lastAt = j['last_message_at'] != null
        ? DateTime.tryParse(j['last_message_at'].toString())
        : null;
    final carInfo = j['car_info']?.toString() ?? '';
    final carParts = carInfo.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final carBrand = carParts.isNotEmpty ? carParts.first : '—';
    final carModel = carParts.length > 1 ? carParts.sublist(1).join(' ') : (carParts.length == 1 ? '' : '—');
    final previewCarRaw = j['car_id']?.toString().trim();
    final lastMsgOrdRaw = j['last_message_order_id']?.toString().trim();
    final kindRaw = j['business_kind']?.toString() ??
        j['businessKind']?.toString() ??
        j['organization_kind']?.toString() ??
        j['organizationKind']?.toString();
    return Chat(
      id: j['id']?.toString() ?? '',
      stoId: j['organization_id']?.toString() ?? '',
      stoName: j['organization_name']?.toString() ?? 'Сервис',
      organizationKind: (kindRaw != null && kindRaw.isNotEmpty) ? kindRaw : null,
      orderId: j['order_id']?.toString() ?? '',
      orderNumber: j['order_number']?.toString() ?? '',
      carBrand: carBrand,
      carModel: carModel.isEmpty ? '—' : carModel,
      orderStatus: OrderStatus.fromApi(j['order_status']?.toString()),
      lastMessage: j['last_message_text']?.toString(),
      lastMessageTime: lastAt,
      lastMessageFromUser: j['last_message_from_client'] == true,
      unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
      previewCarId: (previewCarRaw == null || previewCarRaw.isEmpty) ? null : previewCarRaw,
      lastMessageOrderId: (lastMsgOrdRaw == null || lastMsgOrdRaw.isEmpty) ? null : lastMsgOrdRaw,
    );
  }

  static ChatMessage _messageFromJson(String chatId, Map<String, dynamic> j) {
    final atRaw = j['at'] ?? j['created_at'] ?? j['createdAt'];
    DateTime at = DateTime.now();
    if (atRaw != null) {
      final d = DateTime.tryParse(atRaw.toString());
      at = d != null ? (d.isUtc ? d.toLocal() : d) : DateTime.now();
    }
    final isFromClient = j['is_from_client'] == true || j['isFromClient'] == true;
    final approvalRaw = j['approval_items'] ?? j['approvalItems'];
    List<ApprovalMessageItem>? approvalItems;
    List<ApprovalMessageItem>? editedApprovalItems;
    List<ApprovalMessageItem>? newApprovalItems;
    if (approvalRaw is List<dynamic> && approvalRaw.isNotEmpty) {
      approvalItems = approvalRaw.map((e) {
        final m = e as Map<String, dynamic>;
        return ApprovalMessageItem(
          name: m['name']?.toString() ?? '',
          priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? (m['priceKopecks'] as num?)?.toInt() ?? 0,
          estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? (m['estimatedMinutes'] as num?)?.toInt() ?? 60,
          id: m['id']?.toString(),
        );
      }).toList();
    }
    List<ApprovalMessageItem>? originalApprovalItems;
    int? totalsBeforePriceKopecks, totalsBeforeMinutes, totalsAfterPriceKopecks, totalsAfterMinutes;
    if (approvalRaw is Map<String, dynamic>) {
      final edited = approvalRaw['edited_items'] ?? approvalRaw['editedItems'];
      final newList = approvalRaw['new_items'] ?? approvalRaw['newItems'];
      final editedList = edited is List<dynamic> ? edited : null;
      final newListTyped = newList is List<dynamic> ? newList : null;
      editedApprovalItems = editedList != null && editedList.isNotEmpty
          ? editedList.map((e) {
              final m = e as Map<String, dynamic>;
              return ApprovalMessageItem(
                name: m['name']?.toString() ?? '',
                priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? (m['priceKopecks'] as num?)?.toInt() ?? 0,
                estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? (m['estimatedMinutes'] as num?)?.toInt() ?? 60,
                id: m['id']?.toString(),
              );
            }).toList()
          : null;
      newApprovalItems = newListTyped != null && newListTyped.isNotEmpty
          ? newListTyped.map((e) {
              final m = e as Map<String, dynamic>;
              return ApprovalMessageItem(
                name: m['name']?.toString() ?? '',
                priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? (m['priceKopecks'] as num?)?.toInt() ?? 0,
                estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? (m['estimatedMinutes'] as num?)?.toInt() ?? 60,
                id: m['id']?.toString(),
              );
            }).toList()
          : null;
      final origRaw = approvalRaw['original_items'] ?? approvalRaw['originalItems'];
      if (origRaw is List<dynamic> && origRaw.isNotEmpty) {
        originalApprovalItems = origRaw.map((e) {
          final m = e as Map<String, dynamic>;
          return ApprovalMessageItem(
            name: m['name']?.toString() ?? '',
            priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? (m['priceKopecks'] as num?)?.toInt() ?? 0,
            estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? (m['estimatedMinutes'] as num?)?.toInt() ?? 60,
            id: m['id']?.toString(),
          );
        }).toList();
      }
      final tb = approvalRaw['totals_before'] ?? approvalRaw['totalsBefore'];
      if (tb is Map) {
        totalsBeforePriceKopecks = (tb['price_kopecks'] ?? tb['priceKopecks']) is num ? ((tb['price_kopecks'] ?? tb['priceKopecks']) as num).toInt() : null;
        totalsBeforeMinutes = (tb['estimated_minutes'] ?? tb['estimatedMinutes']) is num ? ((tb['estimated_minutes'] ?? tb['estimatedMinutes']) as num).toInt() : null;
      }
      final ta = approvalRaw['totals_after'] ?? approvalRaw['totalsAfter'];
      if (ta is Map) {
        totalsAfterPriceKopecks = (ta['price_kopecks'] ?? ta['priceKopecks']) is num ? ((ta['price_kopecks'] ?? ta['priceKopecks']) as num).toInt() : null;
        totalsAfterMinutes = (ta['estimated_minutes'] ?? ta['estimatedMinutes']) is num ? ((ta['estimated_minutes'] ?? ta['estimatedMinutes']) as num).toInt() : null;
      }
    }
    final hasApproval = (approvalItems != null && approvalItems.isNotEmpty) ||
        (editedApprovalItems != null && editedApprovalItems.isNotEmpty) ||
        (newApprovalItems != null && newApprovalItems.isNotEmpty);
    final messageType = j['message_type']?.toString() ?? j['messageType']?.toString();
    final fromSupportOperator = j['is_from_support_operator'] == true ||
        j['isFromSupportOperator'] == true ||
        messageType == 'support_operator_reply';
    final orderItemsSnapshotRaw = j['order_items_snapshot'] ?? j['orderItemsSnapshot'];
    List<ApprovalMessageItem>? orderItemsSnapshot;
    if (orderItemsSnapshotRaw is List<dynamic> && orderItemsSnapshotRaw.isNotEmpty) {
      orderItemsSnapshot = orderItemsSnapshotRaw.map((e) {
        final m = e as Map<String, dynamic>;
        return ApprovalMessageItem(
          name: m['name']?.toString() ?? '',
          priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? (m['priceKopecks'] as num?)?.toInt() ?? 0,
          estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? (m['estimatedMinutes'] as num?)?.toInt() ?? 60,
          id: m['id']?.toString(),
        );
      }).toList();
    }
    final proposedDtRaw = j['proposed_date_time'] ?? j['proposedDateTime'];
    final proposedDt = proposedDtRaw != null ? DateTime.tryParse(proposedDtRaw.toString()) : null;
    final isSystem = j['is_system'] == true || j['isSystem'] == true;
    final orderId = j['order_id']?.toString() ?? j['orderId']?.toString();
    final approvalCarIdRaw = j['car_id'] ?? j['carId'];
    final approvalCarId = approvalCarIdRaw != null && approvalCarIdRaw.toString().trim().isNotEmpty
        ? approvalCarIdRaw.toString().trim()
        : null;
    final content = j['text']?.toString() ?? j['content']?.toString() ?? '';
    final attRaw = j['attachments'] ?? j['attachment'];
    List<ChatAttachment> attachments = [];
    if (attRaw is List<dynamic>) {
      for (final e in attRaw) {
        final a = ChatAttachment.fromJson(e);
        if (a != null) attachments.add(a);
      }
    }
    MessageType type;
    if (isSystem) {
      type = MessageType.system;
    } else if (messageType == 'booking_card') {
      type = MessageType.bookingCard;
    } else if (messageType == 'approval_request' || (hasApproval && messageType != 'booking_card')) {
      type = MessageType.approval;
    } else {
      type = hasApproval ? MessageType.approval : MessageType.text;
    }
    return ChatMessage(
      id: j['id']?.toString() ?? '',
      chatId: chatId,
      isFromUser: fromSupportOperator ? false : isFromClient,
      isSystem: isSystem,
      content: content,
      type: type,
      timestamp: at,
      deliveryStatus: MessageDeliveryStatus.read,
      approvalItems: approvalItems,
      editedApprovalItems: editedApprovalItems,
      newApprovalItems: newApprovalItems,
      proposedDateTime: proposedDt,
      orderId: orderId,
      orderItemsSnapshot: orderItemsSnapshot,
      originalApprovalItems: originalApprovalItems,
      totalsBeforePriceKopecks: totalsBeforePriceKopecks,
      totalsBeforeMinutes: totalsBeforeMinutes,
      totalsAfterPriceKopecks: totalsAfterPriceKopecks,
      totalsAfterMinutes: totalsAfterMinutes,
      approvalCarId: approvalCarId,
      attachments: attachments,
    );
  }

  @override
  Future<Result<Chat>> openSupportChat() async {
    final result = await _api.openSupportChat();
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.notFound, message: 'Не удалось открыть чат поддержки'));
    }
    return Result.success(_chatFromJson(items[0] as Map<String, dynamic>));
  }

  @override
  Future<Result<List<Chat>>> getChats() async {
    final result = await _api.getChats();
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final list = (data['items'] as List<dynamic>?) ?? [];
    final chats = list.map((e) => _chatFromJson(e as Map<String, dynamic>)).toList();
    return Result.success(chats);
  }

  @override
  Future<Result<Chat>> getChatById(String id) async {
    final listResult = await getChats();
    final list = listResult.dataOrNull;
    if (list == null) return Result.failure(listResult.errorOrNull!);
    for (final c in list) {
      if (c.id == id) return Result.success(c);
    }
    // Чат не в списке (например только что создан общий чат) — запросить GET /chats/:id (без stub).
    final oneResult = await _api.getChat(id);
    final data = oneResult.dataOrNull;
    if (data == null) return Result.failure(oneResult.errorOrNull!);
    final items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.notFound, message: 'Чат не найден'));
    }
    final chat = _chatFromJson(items[0] as Map<String, dynamic>);
    return Result.success(chat);
  }

  @override
  Future<Result<Chat?>> getChatByOrderId(String orderId) async {
    final listResult = await getChats();
    final list = listResult.dataOrNull;
    if (list == null) return Result.failure(listResult.errorOrNull!);
    for (final c in list) {
      if (c.orderId == orderId) return Result.success(c);
    }
    return Result.success(null);
  }

  @override
  Future<Result<List<ChatMessage>>> getMessages(String chatId) async {
    final result = await _api.getMessages(chatId);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final list = _parseMessageListFromResponse(data);
    if (kDebugMode) {
      debugPrint('[ApiChatRepository] GET messages keys: ${data.keys.toList()}, list.length: ${list.length}');
    }
    final messages = list.map((e) => _messageFromJson(chatId, e as Map<String, dynamic>)).toList();
    return Result.success(messages);
  }

  @override
  Future<Result<ChatMessage>> sendMessage(String chatId, {required String text, MessageType type = MessageType.text}) async {
    final result = await _api.sendMessage(chatId, text);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final msgMap = _unwrapPostMessageResponse(data);
    final msg = _messageFromJson(chatId, msgMap);
    return Result.success(msg);
  }

  @override
  Future<Result<ChatMessage>> sendMessageWithMedia(
    String chatId, {
    String text = '',
    List<ChatOutgoingImage> images = const [],
  }) async {
    final result = await _api.sendMessageWithMedia(chatId, text: text, images: images);
    final data = result.dataOrNull;
    if (data == null) return Result.failure(result.errorOrNull!);
    final msgMap = _unwrapPostMessageResponse(data);
    final msg = _messageFromJson(chatId, msgMap);
    return Result.success(msg);
  }

  @override
  Future<Result<void>> markAsRead(String chatId, String messageId) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> markAllAsRead(String chatId) async {
    final result = await _api.markChatRead(chatId);
    return result.when(
      success: (_) => Result.success(null),
      failure: (e) => Result.failure(e),
    );
  }
}
