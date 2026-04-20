import '../../shared/models/chat_model.dart';
import '../api/api_exceptions.dart';

/// Абстрактный репозиторий чатов
abstract class ChatRepository {
  /// Открыть чат с поддержкой (создаёт при первом обращении).
  Future<Result<Chat>> openSupportChat();

  /// Открыть или создать общий чат с организацией (карточка СТО).
  Future<Result<Chat>> openOrganizationChat(String organizationId);

  /// Все чаты пользователя
  Future<Result<List<Chat>>> getChats();

  /// Чат по ID
  Future<Result<Chat>> getChatById(String id);

  /// Чат по заказу
  Future<Result<Chat?>> getChatByOrderId(String orderId);

  /// Получить сообщения чата
  Future<Result<List<ChatMessage>>> getMessages(String chatId);

  /// Отправить сообщение
  Future<Result<ChatMessage>> sendMessage(String chatId, {
    required String text,
    MessageType type,
  });

  /// Текст и/или изображения (multipart).
  Future<Result<ChatMessage>> sendMessageWithMedia(
    String chatId, {
    String text = '',
    List<ChatOutgoingImage> images = const [],
  });

  /// Отметить сообщение прочитанным
  Future<Result<void>> markAsRead(String chatId, String messageId);

  /// Отметить все как прочитанные
  Future<Result<void>> markAllAsRead(String chatId);
}
