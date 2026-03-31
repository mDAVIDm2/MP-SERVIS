import 'package:dio/dio.dart';
import '../../shared/models/chat_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

/// Чаты и сообщения (клиент видит чаты по своим заказам).
class ChatApiService {
  ChatApiService(this._client);
  final ApiClient _client;

  Future<Result<Map<String, dynamic>>> openSupportChat() async {
    try {
      final res = await _client.post(ApiEndpoints.chatsSupportOpen);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> getChats() async {
    try {
      final res = await _client.get(ApiEndpoints.chats);
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Один чат по id (GET /chats/:id). Нужен, чтобы открыть общий чат без stub, если его ещё нет в списке.
  Future<Result<Map<String, dynamic>>> getChat(String chatId) async {
    try {
      final res = await _client.get(ApiEndpoints.chat(chatId));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> getMessages(String chatId) async {
    try {
      final res = await _client.get(ApiEndpoints.chatMessages(chatId));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> sendMessage(String chatId, String text) async {
    try {
      final res = await _client.post(ApiEndpoints.chatMessages(chatId), data: {'text': text});
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Multipart: поле `text` (опционально) и файлы `files` (до лимита тарифа на бэкенде).
  Future<Result<Map<String, dynamic>>> sendMessageWithMedia(
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
      if (t.isNotEmpty) {
        form.fields.add(MapEntry('text', t));
      }
      for (final img in images) {
        form.files.add(MapEntry(
          'files',
          MultipartFile.fromBytes(img.bytes, filename: img.filename),
        ));
      }
      final res = await _client.upload<Map<String, dynamic>>(
        ApiEndpoints.chatMessagesWithMedia(chatId),
        formData: form,
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }

  /// Отметить чат прочитанным (POST /chats/:id/read). Бэкенд может обновить last_read_at и unreadCount.
  Future<Result<void>> markChatRead(String chatId) async {
    try {
      await _client.post(ApiEndpoints.chatRead(chatId));
      return Result.success(null);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
}
