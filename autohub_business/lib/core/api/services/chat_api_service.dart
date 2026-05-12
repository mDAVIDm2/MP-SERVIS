import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:http_parser/http_parser.dart';
import '../api_client.dart';
import '../api_endpoints.dart';
import '../api_exceptions.dart';
import '../../utils/chat_image_upload.dart';
import '../../../shared/models/chat_model.dart';

/// Извлекает список из ответа GET /chats/:id/messages. Поддержка: items, data, messages и обёртка { data: { items: [...] } }.
List<dynamic> parseMessageListFromResponse(Map<String, dynamic> data) {
  final raw = data['items'] ?? data['data'] ?? data['messages'];
  if (raw is List<dynamic>) return raw;
  if (raw is Map<String, dynamic>) {
    final inner = raw['items'] ?? raw['data'] ?? raw['messages'];
    if (inner is List<dynamic>) return inner;
  }
  return [];
}

/// Извлекает объект сообщения из ответа POST /chats/:id/messages. Поддержка: { data: {...} }, { message: {...} }, {...}.
Map<String, dynamic> unwrapPostMessageResponse(Map<String, dynamic> data) {
  final dataField = data['data'];
  if (dataField is Map<String, dynamic>) return dataField;
  final messageField = data['message'];
  if (messageField is Map<String, dynamic>) return messageField;
  return data;
}

/// API чатов и сообщений.
class ChatApiService {
  ChatApiService(this._client);

  final ApiClient _client;

  Future<Result<List<ChatPreview>>> getChats({CancelToken? cancelToken}) async {
    try {
      final res = await _client.get(ApiEndpoints.chats, cancelToken: cancelToken);
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат'));
      final list = data['items'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];
      final chats = list.map((e) => ChatPreview.fromJson(e as Map<String, dynamic>)).toList();
      return Result.success(chats);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<List<ChatMessage>>> getMessages(String chatId, {CancelToken? cancelToken}) async {
    try {
      final res = await _client.get(ApiEndpoints.chatMessages(chatId), cancelToken: cancelToken);
      final data = res.data;
      if (data is! Map<String, dynamic>) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат'));
      final list = parseMessageListFromResponse(data);
      if (kDebugMode) {
        debugPrint('[ChatApiService] GET messages keys: ${data.keys.toList()}, list.length: ${list.length}');
      }
      final messages = list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
      return Result.success(messages);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<void>> markChatRead(String chatId) async {
    try {
      await _client.post(ApiEndpoints.chatMarkRead(chatId));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<ChatMessage>> sendMessage(String chatId, String text) async {
    try {
      final res = await _client.post(ApiEndpoints.chatMessages(chatId), data: {'text': text});
      final data = res.data as Map<String, dynamic>?;
      if (data == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      final msgMap = unwrapPostMessageResponse(data);
      return Result.success(ChatMessage.fromJson(msgMap));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<ChatMessage>> sendMessageWithMedia(
    String chatId, {
    String text = '',
    List<ChatOutgoingImage> images = const [],
  }) async {
    if (text.trim().isEmpty && images.isEmpty) {
      return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет текста и файлов'));
    }
    try {
      final form = FormData();
      final t = text.trim();
      if (t.isNotEmpty) form.fields.add(MapEntry('text', t));
      for (var i = 0; i < images.length; i++) {
        final img = images[i];
        final prepared = await prepareChatImageBytesForUpload(img.bytes);
        final filename = kIsWeb
            ? (img.filename.isNotEmpty ? img.filename : 'photo.jpg')
            : 'photo_$i.jpg';
        final contentType = kIsWeb
            ? mediaTypeForChatImageFilename(filename)
            : MediaType('image', 'jpeg');
        form.files.add(MapEntry(
          'files',
          MultipartFile.fromBytes(
            prepared,
            filename: filename,
            contentType: contentType,
          ),
        ));
      }
      final res = await _client.upload<Map<String, dynamic>>(
        ApiEndpoints.chatMessagesWithMedia(chatId),
        formData: form,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      }
      final msgMap = unwrapPostMessageResponse(data);
      return Result.success(ChatMessage.fromJson(msgMap));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<ChatPreview>> openSupportChat() async {
    try {
      final res = await _client.post(ApiEndpoints.chatsSupportOpen);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат'));
      }
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.notFound, message: 'Чат поддержки не создан'));
      }
      return Result.success(ChatPreview.fromJson(items[0] as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// [editedItems] — скорректированные услуги (с id). [newItems] — добавленные.
  /// [originalItems] — снимок текущего состава заказа до изменений (для сводки в карточке).
  /// [totalsBefore] / [totalsAfter] — сумма и длительность до/после (для перерасчёта времени заказа и отображения).
  Future<Result<ChatMessage>> sendApprovalRequest(
    String chatId,
    String orderId, {
    String? carId,
    List<EditedApprovalItem>? editedItems,
    List<ApprovalItem>? newItems,
    List<ApprovalItem>? items,
    List<ApprovalItem>? originalItems,
    int? totalsBeforePriceKopecks,
    int? totalsBeforeMinutes,
    int? totalsAfterPriceKopecks,
    int? totalsAfterMinutes,
    DateTime? proposedDateTime,
  }) async {
    try {
      final Object approvalPayload;
      if ((editedItems != null && editedItems.isNotEmpty) || (newItems != null && newItems.isNotEmpty)) {
        final map = <String, dynamic>{
          'edited_items': (editedItems ?? []).map((i) => {
            'id': i.id,
            'name': i.name,
            'price_kopecks': i.priceKopecks,
            'estimated_minutes': i.estimatedMinutes,
          }).toList(),
          'new_items': (newItems ?? []).map((i) => {
            if (i.id != null && i.id!.isNotEmpty) 'id': i.id!,
            'name': i.name,
            'price_kopecks': i.priceKopecks,
            'estimated_minutes': i.estimatedMinutes,
          }).toList(),
        };
        if (originalItems != null && originalItems.isNotEmpty) {
          map['original_items'] = originalItems.map((i) => {
            if (i.id != null && i.id!.isNotEmpty) 'id': i.id!,
            'name': i.name,
            'price_kopecks': i.priceKopecks,
            'estimated_minutes': i.estimatedMinutes,
          }).toList();
        }
        if (totalsBeforePriceKopecks != null || totalsBeforeMinutes != null) {
          map['totals_before'] = {
            if (totalsBeforePriceKopecks != null) 'price_kopecks': totalsBeforePriceKopecks,
            if (totalsBeforeMinutes != null) 'estimated_minutes': totalsBeforeMinutes,
          };
        }
        if (totalsAfterPriceKopecks != null || totalsAfterMinutes != null) {
          map['totals_after'] = {
            if (totalsAfterPriceKopecks != null) 'price_kopecks': totalsAfterPriceKopecks,
            if (totalsAfterMinutes != null) 'estimated_minutes': totalsAfterMinutes,
          };
        }
        approvalPayload = map;
      } else {
        approvalPayload = (items ?? []).map((i) => {
          'name': i.name,
          'price_kopecks': i.priceKopecks,
          'estimated_minutes': i.estimatedMinutes,
        }).toList();
      }
      final body = {
        'order_id': orderId.isEmpty ? null : orderId,
        'approval_items': approvalPayload,
        if (proposedDateTime != null) 'proposed_date_time': proposedDateTime.toUtc().toIso8601String(),
        if (orderId.isEmpty && carId != null && carId!.isNotEmpty) 'car_id': carId,
      };
      final isEmpty = approvalPayload is List
          ? (approvalPayload as List).isEmpty
          : (approvalPayload is Map && (approvalPayload as Map)['edited_items'] is List && (approvalPayload as Map)['new_items'] is List
              && ((approvalPayload as Map)['edited_items'] as List).isEmpty
              && ((approvalPayload as Map)['new_items'] as List).isEmpty);
      if (isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет изменений для согласования'));
      }
      final res = await _client.post(ApiEndpoints.chatMessages(chatId), data: body);
      final data = res.data as Map<String, dynamic>?;
      if (data == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Пустой ответ'));
      final msgMap = unwrapPostMessageResponse(data);
      return Result.success(ChatMessage.fromJson(msgMap));
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
