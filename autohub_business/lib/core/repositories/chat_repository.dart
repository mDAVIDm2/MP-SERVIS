import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/chat_model.dart';
import '../api/api_exceptions.dart';
import '../api/services/api_services_providers.dart';
import '../api/services/chat_api_service.dart';
import '../config/app_config.dart';
import '../ws/ws_client.dart';
import '../ws/ws_provider.dart';
import 'order_repository.dart';

class ChatRepository extends StateNotifier<ChatRepositoryState> {
  ChatRepository(this._api, this._ws, this._orderRepo)
      : super(ChatRepositoryState(chats: [], messages: {}, loadError: null)) {
    if (AppConfig.enableWs) {
      _wsSub = _ws.events.where((e) =>
        e.type == 'chat_message' || e.type == 'message' || e.type == 'new_message').listen(_onWsMessage);
      _orderWsSub = _ws.events.where((e) =>
        e.type == 'order_created' || e.type == 'order_updated').listen(_onOrderWsEvent);
    }
  }

  final ChatApiService _api;
  final WsClient _ws;
  final OrderRepository? _orderRepo;
  StreamSubscription<WsEvent>? _wsSub;
  StreamSubscription<WsEvent>? _orderWsSub;
  CancelToken? _loadChatsToken;
  CancelToken? _loadMessagesToken;
  Future<void>? _loadChatsInFlight;

  void _onWsMessage(WsEvent e) {
    final payload = e.payload;
    final chatId = payload['chat_id'] as String? ?? payload['chatId'] as String?;
    final msgMap = payload['message'] as Map<String, dynamic>? ?? payload;
    if (chatId == null || chatId.isEmpty) return;
    try {
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(msgMap as Map));
      _appendMessage(chatId, msg, previewText: msg.text);
    } catch (err, st) {
      if (kDebugMode) {
        debugPrint('[ChatRepository] WS message parse error: $err');
        debugPrint('[ChatRepository] payload keys: ${payload.keys.toList()}');
        debugPrint('[ChatRepository] msgMap: $msgMap');
        debugPrint(st.toString());
      }
    }
  }

  void _onOrderWsEvent(WsEvent e) {
    loadFromApi();
  }

  List<ChatPreview> get chats => state.chats;

  List<ChatMessage> messagesFor(String chatId) {
    final list = state.messages[chatId] ?? [];
    return List.from(list)..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Очистить список чатов и сообщений локально (после очистки заказов в БД — в диалогах ничего не остаётся).
  void clearAllChats() {
    state = ChatRepositoryState(chats: [], messages: {}, loadError: null);
  }

  /// Загрузить список чатов с API. При ошибке демо не подставляем — оставляем список и выставляем loadError.
  /// Предыдущий запрос отменяется при новом вызове.
  /// Параллельные вызовы сливаются в один Future (меньше дублирующих запросов при быстрых тапах / WS).
  Future<void> loadFromApi() async {
    if (_loadChatsInFlight != null) return _loadChatsInFlight!;
    final run = _loadChatsFromApi();
    _loadChatsInFlight = run;
    try {
      await run;
    } finally {
      _loadChatsInFlight = null;
    }
  }

  Future<void> _loadChatsFromApi() async {
    if (kDebugMode) debugPrint('[ChatOrderDebug] ChatRepository.loadFromApi | START');
    _loadChatsToken?.cancel();
    _loadChatsToken = CancelToken();
    final result = await _api.getChats(cancelToken: _loadChatsToken);
    if (result.dataOrNull != null) {
      state = ChatRepositoryState(chats: result.dataOrNull!, messages: state.messages, loadError: null);
      if (kDebugMode) debugPrint('[ChatOrderDebug] ChatRepository.loadFromApi | state updated | chatsCount=${state.chats.length}');
      return;
    }
    state = ChatRepositoryState(
      chats: state.chats,
      messages: state.messages,
      loadError: result.errorOrNull?.message ?? 'Не удалось загрузить чаты',
    );
    if (kDebugMode) debugPrint('[ChatOrderDebug] ChatRepository.loadFromApi | error | loadError=${state.loadError}');
  }

  /// Загрузить сообщения чата с API (при открытии экрана чата). При ошибке состояние не меняется.
  /// Предыдущий запрос сообщений отменяется при новом вызове.
  Future<void> loadMessagesFor(String chatId) async {
    if (kDebugMode) {
      debugPrint('[ChatOrderDebug] loadMessagesFor | START | chatId=$chatId');
    }
    _loadMessagesToken?.cancel();
    _loadMessagesToken = CancelToken();
    final result = await _api.getMessages(chatId, cancelToken: _loadMessagesToken);
    if (result.dataOrNull == null) return;
    final fromApi = result.dataOrNull!;
    final orderIdsInApi = fromApi.map((m) => m.orderId?.trim()).whereType<String>().where((s) => s.isNotEmpty).toSet();
    if (kDebugMode) {
      debugPrint('[ChatOrderDebug] loadMessagesFor | fromApi | chatId=$chatId messagesCount=${fromApi.length} uniqueOrderIds=${orderIdsInApi.length} orderIds=${orderIdsInApi.take(3).join(';')}');
    }
    final updated = Map<String, List<ChatMessage>>.from(state.messages);
    final existing = state.messages[chatId];
    if (existing != null && existing.isNotEmpty) {
      // Merge по id: все existing, поверх — fromApi (обновление). Сообщения не пропадают после refetch.
      final byId = <String, ChatMessage>{};
      for (final m in existing) {
        byId[m.id] = m;
      }
      for (final m in fromApi) {
        byId[m.id] = m;
      }
      final merged = byId.values.toList()..sort((a, b) => a.at.compareTo(b.at));
      updated[chatId] = merged;
    } else {
      updated[chatId] = fromApi;
    }
    state = ChatRepositoryState(chats: state.chats, messages: updated);
    if (kDebugMode) {
      debugPrint('[ChatOrderDebug] loadMessagesFor | state updated | chatId=$chatId finalMessagesCount=${updated[chatId]?.length ?? 0}');
    }
  }

  /// Отправляет сообщение: оптимистичное обновление, при успехе — подмена на ответ API.
  /// Возвращает true при успехе, false при ошибке (для показа SnackBar в UI).
  Future<bool> sendMessage(String chatId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final chatMeta = state.chats.where((c) => c.id == chatId).firstOrNull;
    final isSupport = chatMeta?.isSupportChat ?? false;
    final tempMsg = ChatMessage(
      id: tempId,
      text: trimmed,
      isFromClient: isSupport,
      at: DateTime.now(),
      isText: true,
      isFromSupportOperator: false,
      supportChannel: isSupport ? 'business' : null,
    );
    _appendMessage(chatId, tempMsg, previewText: trimmed);
    final result = await _api.sendMessage(chatId, trimmed);
    final msg = result.dataOrNull;
    if (msg != null) {
      _replaceMessage(chatId, tempId, msg);
      _updateChatPreview(chatId, msg.text, msg.at);
      return true;
    }
    _removeMessage(chatId, tempId);
    return false;
  }

  /// Текст и/или фото (лимит по тарифу на бэкенде).
  Future<bool> sendMessageWithMedia(
    String chatId, {
    String text = '',
    List<ChatOutgoingImage> images = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && images.isEmpty) return false;
    final result = await _api.sendMessageWithMedia(chatId, text: trimmed, images: images);
    final msg = result.dataOrNull;
    if (msg == null) return false;
    _appendMessage(chatId, msg, previewText: trimmed.isNotEmpty ? trimmed : 'Фото');
    _updateChatPreview(chatId, trimmed.isNotEmpty ? trimmed : 'Фото', msg.at);
    return true;
  }

  /// Отправляет запрос согласования: оптимистичное обновление.
  /// [editedItems] — скорректированные услуги заказа (с id). [newItems] — добавленные.
  /// Либо [items] — один список (legacy / только новые).
  Future<String?> sendApprovalRequest(
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
    bool isInitialConfirm = false,
  }) async {
    final hasEdited = editedItems != null && editedItems.isNotEmpty;
    final hasNew = newItems != null && newItems.isNotEmpty;
    final hasLegacy = items != null && items.isNotEmpty;
    if (!hasEdited && !hasNew && !hasLegacy) return null;
    final totalK = (editedItems ?? []).fold<int>(0, (s, i) => s + i.priceKopecks) +
        (newItems ?? []).fold<int>(0, (s, i) => s + i.priceKopecks) +
        (items ?? []).fold<int>(0, (s, i) => s + i.priceKopecks);
    final count = (editedItems?.length ?? 0) + (newItems?.length ?? 0) + (items?.length ?? 0);
    final previewText = 'Запрос согласования • $count поз. • ${totalK ~/ 100} ₽';
    final tempId = 'temp_approval_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatMessage(
      id: tempId,
      text: '',
      isFromClient: false,
      at: DateTime.now(),
      isText: false,
      approvalItems: items,
      editedApprovalItems: editedItems,
      newApprovalItems: newItems,
      approvalStatus: ApprovalStatus.pending,
      proposedDateTime: proposedDateTime,
    );
    _appendMessage(chatId, tempMsg, previewText: previewText);
    final result = await _api.sendApprovalRequest(
      chatId,
      orderId,
      carId: carId,
      editedItems: editedItems,
      newItems: newItems,
      items: items,
      originalItems: originalItems,
      totalsBeforePriceKopecks: totalsBeforePriceKopecks,
      totalsBeforeMinutes: totalsBeforeMinutes,
      totalsAfterPriceKopecks: totalsAfterPriceKopecks,
      totalsAfterMinutes: totalsAfterMinutes,
      proposedDateTime: proposedDateTime,
    );
    final msg = result.dataOrNull;
    if (msg != null) {
      _replaceMessage(chatId, tempId, msg);
      _updateChatPreview(chatId, previewText, msg.at);
      final effectiveOrderId = msg.orderId ?? orderId;
      // Статус pending_approval бэкенд выставляет при создании сообщения согласования; дублировать не нужно.
      return effectiveOrderId.isEmpty ? null : effectiveOrderId;
    }
    _removeMessage(chatId, tempId);
    return null;
  }

  void setApprovalResponse(String chatId, String messageId, bool approved) {
    final list = state.messages[chatId];
    if (list == null) return;
    final status = approved ? ApprovalStatus.approved : ApprovalStatus.rejected;
    final updated = list.map((m) {
      if (m.id != messageId || !m.isApprovalCard) return m;
      return ChatMessage(
        id: m.id,
        text: m.text,
        isFromClient: m.isFromClient,
        at: m.at,
        isText: false,
        approvalItems: m.approvalItems,
        editedApprovalItems: m.editedApprovalItems,
        newApprovalItems: m.newApprovalItems,
        approvalStatus: status,
        proposedDateTime: m.proposedDateTime,
        orderId: m.orderId,
        isSystem: m.isSystem,
        messageType: m.messageType,
        orderItemsSnapshot: m.orderItemsSnapshot,
        originalApprovalItems: m.originalApprovalItems,
        totalsBeforePriceKopecks: m.totalsBeforePriceKopecks,
        totalsBeforeMinutes: m.totalsBeforeMinutes,
        totalsAfterPriceKopecks: m.totalsAfterPriceKopecks,
        totalsAfterMinutes: m.totalsAfterMinutes,
        approvalCarId: m.approvalCarId,
        isFromSupportOperator: m.isFromSupportOperator,
        supportChannel: m.supportChannel,
        attachments: m.attachments,
      );
    }).toList();
    final updatedMessages = Map<String, List<ChatMessage>>.from(state.messages);
    updatedMessages[chatId] = updated;
    state = ChatRepositoryState(chats: state.chats, messages: updatedMessages);
  }

  void _appendMessage(String chatId, ChatMessage msg, {required String previewText}) {
    final updated = Map<String, List<ChatMessage>>.from(state.messages);
    final list = updated[chatId] ?? [];
    if (list.any((m) => m.id == msg.id)) return;
    updated[chatId] = [...list, msg];
    final chatList = state.chats.map((c) {
      if (c.id != chatId) return c;
      final bump = msg.isFromClient ? 1 : 0;
      return ChatPreview(
        id: c.id,
        orderId: c.orderId,
        orderNumber: c.orderNumber,
        clientName: c.clientName,
        clientPhone: c.clientPhone,
        clientAvatarUrl: c.clientAvatarUrl,
        isSupportChat: c.isSupportChat,
        lastMessageText: previewText,
        lastMessageAt: msg.at,
        unreadCount: c.unreadCount + bump,
      );
    }).toList();
    state = ChatRepositoryState(chats: chatList, messages: updated);
  }

  void _replaceMessage(String chatId, String oldId, ChatMessage newMsg) {
    final list = state.messages[chatId];
    if (list == null) return;
    final updated = list.map((m) => m.id == oldId ? newMsg : m).toList();
    final updatedMessages = Map<String, List<ChatMessage>>.from(state.messages);
    updatedMessages[chatId] = updated;
    state = ChatRepositoryState(chats: state.chats, messages: updatedMessages);
  }

  void _removeMessage(String chatId, String messageId) {
    final list = state.messages[chatId];
    if (list == null) return;
    final updated = list.where((m) => m.id != messageId).toList();
    final updatedMessages = Map<String, List<ChatMessage>>.from(state.messages);
    updatedMessages[chatId] = updated;
    state = ChatRepositoryState(chats: state.chats, messages: updatedMessages);
  }

  void _updateChatPreview(String chatId, String previewText, DateTime at) {
    state = ChatRepositoryState(
      chats: state.chats.map((c) {
        if (c.id != chatId) return c;
        return ChatPreview(
          id: c.id,
          orderId: c.orderId,
          orderNumber: c.orderNumber,
          clientName: c.clientName,
          clientPhone: c.clientPhone,
          clientAvatarUrl: c.clientAvatarUrl,
          isSupportChat: c.isSupportChat,
          lastMessageText: previewText,
          lastMessageAt: at,
          unreadCount: c.unreadCount,
        );
      }).toList(),
      messages: state.messages,
    );
  }

  /// Чат с поддержкой (тот же номер, что в аккаунте сотрудника).
  Future<Result<ChatPreview>> openSupportChat() async {
    final result = await _api.openSupportChat();
    final preview = result.dataOrNull;
    if (preview != null) {
      await loadFromApi();
      return Result.success(preview);
    }
    return Result.failure(result.errorOrNull!);
  }

  /// Синхронизация с сервером: POST /chats/:id/read и перезагрузка списка (актуальный unread_count).
  Future<void> markChatRead(String chatId) async {
    await _api.markChatRead(chatId);
    await loadFromApi();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsSub = null;
    _orderWsSub?.cancel();
    _orderWsSub = null;
    super.dispose();
  }
}

class ChatRepositoryState {
  final List<ChatPreview> chats;
  final Map<String, List<ChatMessage>> messages;
  /// Сообщение об ошибке загрузки списка чатов (при ошибке API демо не подставляем).
  final String? loadError;

  ChatRepositoryState({required this.chats, required this.messages, this.loadError});
}

final chatRepositoryProvider = StateNotifierProvider<ChatRepository, ChatRepositoryState>((ref) {
  final api = ref.watch(chatApiServiceProvider);
  final ws = ref.watch(wsClientProvider);
  final orderRepo = ref.watch(orderRepositoryProvider.notifier);
  final repo = ChatRepository(api, ws, orderRepo);
  ref.onDispose(() => repo.dispose());
  Future.microtask(() => repo.loadFromApi());
  return repo;
});
