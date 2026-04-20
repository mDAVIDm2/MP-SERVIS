import '../../../shared/models/chat_model.dart';
import '../../../shared/models/order_model.dart';
import '../../api/api_exceptions.dart';
import '../../constants/mock_data.dart';
import '../chat_repository.dart';

/// Мок-реализация ChatRepository
class MockChatRepository implements ChatRepository {
  @override
  Future<Result<Chat>> openOrganizationChat(String organizationId) async {
    await _delay();
    return Result.success(Chat(
      id: 'mock_org_$organizationId',
      stoId: organizationId,
      stoName: 'Сервис',
      orderId: '',
      orderNumber: '',
      carBrand: '—',
      carModel: '',
      orderStatus: OrderStatus.pendingConfirmation,
    ));
  }

  @override
  Future<Result<Chat>> openSupportChat() async {
    await _delay();
    return Result.success(const Chat(
      id: 'mock_support',
      stoId: '',
      stoName: 'Поддержка MP-Servis',
      orderId: '',
      orderNumber: '',
      carBrand: 'Поддержка',
      carModel: '',
      orderStatus: OrderStatus.pendingConfirmation,
    ));
  }

  @override
  Future<Result<List<Chat>>> getChats() async {
    await _delay();
    return Result.success(List.from(MockData.chats));
  }

  @override
  Future<Result<Chat>> getChatById(String id) async {
    await _delay();
    final chat = MockData.findChatById(id);
    if (chat == null) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.notFound,
        message: 'Чат не найден',
      ));
    }
    return Result.success(chat);
  }

  @override
  Future<Result<Chat?>> getChatByOrderId(String orderId) async {
    await _delay();
    final chat = MockData.findChatByOrderId(orderId);
    return Result.success(chat);
  }

  @override
  Future<Result<List<ChatMessage>>> getMessages(String chatId) async {
    await _delay();
    final messages = MockData.messagesForChat(chatId);
    return Result.success(messages);
  }

  @override
  Future<Result<ChatMessage>> sendMessage(String chatId, {
    required String text,
    MessageType type = MessageType.text,
  }) async {
    await _delay(200);

    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      isFromUser: true,
      content: text,
      type: type,
      timestamp: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
    );

    return Result.success(message);
  }

  @override
  Future<Result<ChatMessage>> sendMessageWithMedia(
    String chatId, {
    String text = '',
    List<ChatOutgoingImage> images = const [],
  }) async {
    await _delay(200);
    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      isFromUser: true,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      deliveryStatus: MessageDeliveryStatus.sent,
      attachments: [],
    );
    return Result.success(message);
  }

  @override
  Future<Result<void>> markAsRead(String chatId, String messageId) async {
    await _delay(100);
    return Result.success(null);
  }

  @override
  Future<Result<void>> markAllAsRead(String chatId) async {
    await _delay(100);
    return Result.success(null);
  }

  Future<void> _delay([int ms = 300]) async {
    await Future.delayed(Duration(milliseconds: ms));
  }
}
