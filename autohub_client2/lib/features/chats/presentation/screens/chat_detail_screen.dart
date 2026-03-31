import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/order_model.dart';
import 'approval_slot_picker_screen.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';
import '../widgets/authenticated_chat_image.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final Chat chat;
  /// При открытии из карточки заказа («Перейти в чат») — показываем только карточки этого заказа.
  final String? currentOrderId;

  const ChatDetailScreen({super.key, required this.chat, this.currentOrderId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  bool _hasText = false;
  Timer? _refreshTimer;
  /// После отклонения предложения сервиса карточка закрывается (не требует действия).
  final Set<String> _rejectedProposalOrderIds = {};

  @override
  void initState() {
    super.initState();
    _messages = [];
    WidgetsBinding.instance.addObserver(this);
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Сначала обновляем заказы, чтобы статус pending_approval и список синхронизировались до отображения карточки.
      await ref.read(ordersProvider.notifier).loadOrders();
      if (!mounted) return;
      await _loadMessages();
      if (!mounted) return;
      await ref.read(chatsProvider.notifier).markChatAsRead(widget.chat.id);
      if (!mounted) return;
      await ref.read(notificationsProvider.notifier).markReadByChatId(widget.chat.id);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(unreadByCarProvider);
      if (!mounted) return;
      // Скролл к новым сообщениям после построения списка (два кадра: setState → build → scroll).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        _loadMessages();
        ref.read(ordersProvider.notifier).loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadMessages();
      ref.read(ordersProvider.notifier).loadOrders();
    }
  }

  Future<void> _loadMessages() async {
    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.getMessages(widget.chat.id);
    if (!mounted) return;
    if (result.dataOrNull == null) return;
    final fromApi = result.dataOrNull!;
    if (_messages.isEmpty) {
      setState(() => _messages = fromApi);
      ref.read(ordersProvider.notifier).loadOrders();
      return;
    }
    // Merge по id: все existing, поверх — fromApi (обновление). Строки/ссылки не пропадают после refetch.
    final byId = <String, ChatMessage>{};
    for (final m in _messages) {
      byId[m.id] = m;
    }
    for (final m in fromApi) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    setState(() => _messages = merged);
    ref.read(ordersProvider.notifier).loadOrders();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final tempId = 'm_new_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add(ChatMessage(
        id: tempId,
        chatId: widget.chat.id,
        isFromUser: true,
        content: text,
        timestamp: DateTime.now(),
        deliveryStatus: MessageDeliveryStatus.sent,
      ));
      _textController.clear();
    });
    HapticFeedback.lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final ok = await ref.read(chatsProvider.notifier).sendMessage(widget.chat.id, text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _messages.removeWhere((m) => m.id == tempId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось отправить сообщение. Проверьте сеть.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _messages.removeWhere((m) => m.id == tempId));
    await _loadMessages();
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// Обработка согласования/отклонения: всегда вызываем API при отказе, чтобы бэкенд откатил статус и отправил системное сообщение.
  /// orderId только из approval-message (message.orderId), не из chat — иначе approve уйдёт не в тот заказ.
  Future<void> _handleApproval({
    required bool approved,
    required Set<String> checkedItemIds,
    String? orderId,
    String? approvalCarId,
    String? approvalMessageId,
  }) async {
    final id = orderId?.trim() ?? '';
    if (id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось определить заказ. Обновите чат.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    final orders = ref.read(ordersProvider).valueOrNull ?? [];
    final orderIdx = orders.indexWhere((o) => o.id == id);
    Order? order;
    if (orderIdx >= 0) order = orders[orderIdx];

    final additionalItems = order?.items.where((i) => i.isAdditional).toList() ?? [];
    final hasAdditional = additionalItems.isNotEmpty;

    List<String> approvedIds;
    List<String> rejectedIds;
    if (!approved) {
      approvedIds = [];
      rejectedIds = [];
    } else {
      final fromOrder = hasAdditional
          ? order!.items.where((i) => i.isAdditional && checkedItemIds.contains(i.id)).map((i) => i.id).toList()
          : <String>[];
      final fromMessage = checkedItemIds.where((id) => !hasAdditional || !order!.items.any((i) => i.id == id)).toList();
      approvedIds = [...fromOrder, ...fromMessage];
      rejectedIds = hasAdditional
          ? order!.items.where((i) => i.isAdditional && !checkedItemIds.contains(i.id)).map((i) => i.id).toList()
          : [];
    }

    final isForAllCars = approvalCarId == null || approvalCarId.trim().isEmpty;
    final carIdToSend = approved && isForAllCars ? ref.read(selectedCarIdProvider) : null;

    final safeMsgId = approvalMessageId != null && approvalMessageId.isNotEmpty && !approvalMessageId.startsWith('temp_')
        ? approvalMessageId
        : null;
    final result = await ref.read(ordersProvider.notifier).approveItems(
      id,
      approvedItemIds: approvedIds,
      rejectedItemIds: rejectedIds,
      carId: carIdToSend,
      approvalMessageId: safeMsgId,
    );

    if (!mounted) return;
    final orderAfter = result.dataOrNull;
    if (orderAfter == null) {
      final msg = result.errorOrNull?.message ?? 'Не удалось отправить согласование. Проверьте сеть.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    ref.invalidate(orderByIdProvider(id));
    // Не invalidate orders/chats — новый провайдер стартует с loading и лента теряет карточки заказов до ответа API.
    await ref.read(ordersProvider.notifier).loadOrders();
    await ref.read(chatsProvider.notifier).loadChats();
    await ref.refresh(orderByIdProvider(id));
    if (mounted) setState(() {});
    await _loadMessages();
    await ref.read(notificationsProvider.notifier).markReadByOrderId(id);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(unreadByCarProvider);

    if (!approved) setState(() => _rejectedProposalOrderIds.add(id));

    List<String> approvedNames = [];
    List<String> rejectedNames = [];
    if (order != null) {
      approvedNames = order.items
          .where((i) => i.isAdditional && checkedItemIds.contains(i.id))
          .map((i) => i.name)
          .toList();
      rejectedNames = order.items
          .where((i) => i.isAdditional && !checkedItemIds.contains(i.id))
          .map((i) => i.name)
          .toList();
    }

    // Сообщение «Изменения применены» приходит с бэкенда и уже есть в _messages после _loadMessages().
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approved && (approvedNames.isNotEmpty || approvedIds.isNotEmpty)
          ? '✅ Работы согласованы'
          : '❌ Дополнительные работы отклонены'),
      backgroundColor: approved && (approvedNames.isNotEmpty || approvedIds.isNotEmpty)
          ? AppColors.success : AppColors.error,
      duration: const Duration(seconds: 2),
    ));
  }

  List<Order> _ordersForChat(WidgetRef ref) {
    final orders = ref.read(ordersProvider).valueOrNull ?? [];
    var list = orders.where((o) => o.stoId == widget.chat.stoId).toList();
    final filterByCar = ref.read(filterByCarSettingProvider);
    final selectedCarId = ref.read(selectedCarIdProvider);
    if (filterByCar && selectedCarId != null) {
      // Заказы с привязкой к авто показываем только по этому авто; заказы без carId показываем для всех.
      list = list.where((o) => o.carId.isEmpty || o.carId == selectedCarId).toList();
    }
    return list;
  }

  /// В общем чате показываем все заказы и все карточки (один чат клиент ↔ сервис).
  bool _isOrderRelevantForContext(String? orderId) {
    if (orderId == null || orderId.isEmpty) return true;
    return true;
  }

  /// Системные сообщения вида «клиент создал заявку, требуется подтверждение» — для сервиса; у клиента показываем по статусу заказа.
  static bool _isSystemMessageForStoOnly(String content) {
    final lower = content.toLowerCase();
    return lower.contains('требует подтвержден') ||
        lower.contains('требуется подтвержден') ||
        lower.contains('клиент создал заявку') ||
        lower.contains('требует подтверждения');
  }

  /// Текст системного сообщения для клиента: по статусу заказа (подтверждена / отклонена / откорректирована / ожидание).
  static String _clientFriendlySystemMessage(String content, ChatMessage message, List<Order> chatOrders) {
    if (!_isSystemMessageForStoOnly(content)) return content;
    final orderId = message.orderId?.trim();
    if (orderId == null || orderId.isEmpty) return 'Заявка отправлена. Ожидайте подтверждения.';
    final order = chatOrders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return 'Заявка отправлена. Ожидайте подтверждения.';
    switch (order.status) {
      case OrderStatus.cancelled:
        return 'Заявка отклонена.';
      case OrderStatus.pendingApproval:
        return 'Заявка откорректирована. Требуется подтверждение изменений.';
      case OrderStatus.confirmed:
      case OrderStatus.inProgress:
      case OrderStatus.completed:
      case OrderStatus.done:
        return 'Заявка подтверждена.';
      case OrderStatus.pendingConfirmation:
      default:
        return 'Заявка отправлена. Ожидайте подтверждения.';
    }
  }

  /// Карточку «Заявка отправлена» показываем только для заказов выбранной машины и пока заказ не подтверждён.
  /// Системные сообщения показываем только если они не привязаны к заказу или заказ относится к выбранной машине (есть в chatOrders).
  bool _shouldShowSystemMessage(ChatMessage message, List<Order> chatOrders) {
    final orderId = message.orderId?.trim();
    if (orderId == null || orderId.isEmpty) return true;
    return chatOrders.any((o) => o.id == orderId);
  }

  bool _shouldShowBookingCard(ChatMessage message, List<Order> chatOrders) {
    final orderId = message.orderId ?? widget.chat.orderId;
    if (orderId.isEmpty) return false;
    final order = chatOrders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return false;
    return order.status == OrderStatus.pendingConfirmation ||
        order.status == OrderStatus.pendingApproval;
  }

  /// Показывать карточку согласования только если: по текущему заказу (currentOrderId), заказ ещё ждёт ответа, и это последнее approval-сообщение по этому orderId (историю скрываем).
  /// Карточку согласования показываем, если в сообщении есть approval_items (независимо от статуса заказа).
  /// Кнопки «Подтвердить/Отклонить» внутри карточки активны только при pendingApproval/pendingConfirmation.
  bool _shouldShowApprovalCard(WidgetRef ref, ChatMessage message, List<Order> chatOrders) {
    if (message.type != MessageType.approval) return false;
    final orderId = message.orderId ?? widget.chat.orderId;
    if (orderId.isEmpty) return false;
    final order = chatOrders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return false;
    if (order.status != OrderStatus.pendingApproval &&
        order.status != OrderStatus.pendingConfirmation) {
      return false;
    }
    final hasApprovalContent = (message.approvalItems != null && message.approvalItems!.isNotEmpty) ||
        (message.newApprovalItems != null && message.newApprovalItems!.isNotEmpty) ||
        (message.editedApprovalItems != null && message.editedApprovalItems!.isNotEmpty);
    if (!hasApprovalContent) return false;
    if (!_isOrderRelevantForContext(orderId)) return false;
    // Только последнее по времени approval-сообщение по этому orderId.
    final approvalsForOrder = _messages
        .where((m) => m.type == MessageType.approval && (m.orderId ?? '') == orderId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (approvalsForOrder.isEmpty) return false;
    return approvalsForOrder.first.id == message.id;
  }

  /// Есть ли в ленте сообщение типа «согласование» по этому заказу (тогда показываем полную карточку согласования, а не только кнопку).
  bool _hasApprovalMessageForOrder(List<_TimelineItem> timeline, String orderId) {
    return timeline.any((t) =>
        t.message != null &&
        t.message!.type == MessageType.approval &&
        (t.message!.orderId ?? '') == orderId);
  }

  static List<_TimelineItem> _buildTimeline(List<Order> chatOrders, List<ChatMessage> messages) {
    final items = <_TimelineItem>[
      ...chatOrders.map((o) => _TimelineItem.order(o)),
      ...messages.map((m) => _TimelineItem.message(m)),
    ];
    items.sort((a, b) => a.sortAt.compareTo(b.sortAt));
    return items;
  }

  void _navigateToOrder([Order? order]) {
    if (order != null) {
      pushCupertino(context, OrderDetailScreen(order: order));
      return;
    }
    final orders = _ordersForChat(ref)..sort((a, b) => b.timelineSortAt.compareTo(a.timelineSortAt));
    if (orders.isNotEmpty) pushCupertino(context, OrderDetailScreen(order: orders.first));
  }

  Future<void> _navigateToStoCard() async {
    final sto = await ref.read(stoByIdProvider(widget.chat.stoId).future);
    if (!mounted) return;
    if (sto != null) {
      pushCupertino(context, STODetailScreen(sto: sto));
    } else {
      _showOrdersSheet(context);
    }
  }

  void _showOrdersSheet(BuildContext context) {
    final orders = _ordersForChat(ref)..sort((a, b) => b.timelineSortAt.compareTo(a.timelineSortAt));
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Заказы в ${widget.chat.stoName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: orders.length,
                itemBuilder: (_, i) {
                  final order = orders[i];
                  return ListTile(
                    title: Text(
                      '#${order.orderNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${order.displayStatus.label} · ${Formatters.dateShortRu(order.dateTime)} ${Formatters.time(order.dateTime)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.displayStatus.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.displayStatus.shortLabel,
                        style: TextStyle(fontSize: 12, color: order.displayStatus.color),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      pushCupertino(context, OrderDetailScreen(order: order));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        titleSpacing: 0,
        title: widget.chat.isSupportChat
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.stoName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.chat.chatWithOrganizationSubtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              )
            : GestureDetector(
                onTap: _navigateToStoCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat.stoName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.chat.chatWithOrganizationSubtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.phone_rounded, size: 22)),
          IconButton(
            onPressed: () => _showOrdersSheet(context),
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            tooltip: widget.chat.isSupportChat ? 'Справка' : 'Заказы в этом чате',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final chatOrders = _ordersForChat(ref);
                final timeline = _buildTimeline(chatOrders, _messages);
                return ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: timeline.length,
                  itemBuilder: (_, i) {
                    final item = timeline[i];
                    final prevAt = i > 0 ? timeline[i - 1].sortAt : null;
                    final showDate = prevAt == null ||
                        item.sortAt.day != prevAt.day ||
                        item.sortAt.month != prevAt.month ||
                        item.sortAt.year != prevAt.year;
                    return Column(
                      children: [
                        if (showDate) _DateSeparator(date: item.sortAt),
                        if (item.isOrder) ...[
                          if (_isOrderRelevantForContext(item.order!.id)) ...[
                            _OrderTimelineCard(
                              order: item.order!,
                              onTap: () => _navigateToOrder(item.order),
                            ),
                            if (item.order!.status == OrderStatus.pendingConfirmation &&
                                !_messages.any((m) => m.type == MessageType.approval && (m.orderId ?? '') == item.order!.id) &&
                                !_messages.any((m) => m.type == MessageType.bookingCard && (m.orderId ?? '') == item.order!.id))
                              _ClientOrderCreatedCard(order: item.order!),
                          ],
                        ]
                        else if (item.message!.type == MessageType.system) ...[
                          if (_shouldShowSystemMessage(item.message!, chatOrders))
                            _SystemMessage(text: _clientFriendlySystemMessage(item.message!.content, item.message!, chatOrders)),
                        ]
                        else if (item.message!.type == MessageType.bookingCard) ...[
                          if (_shouldShowBookingCard(item.message!, chatOrders)) ...[
                            _BookingCard(
                              message: item.message!,
                              orderNumber: chatOrders
                                  .where((o) => o.id == (item.message!.orderId ?? widget.chat.orderId))
                                  .firstOrNull
                                  ?.orderNumber,
                              sentAt: item.message!.timestamp,
                            ),
                          ],
                        ]
                        else if (item.message!.type == MessageType.approval) ...[
                          if (_isOrderRelevantForContext(item.message!.orderId) && _shouldShowApprovalCard(ref, item.message!, chatOrders))
                            _ApprovalCard(
                              key: ValueKey('approval_${item.message!.id}'),
                              chat: widget.chat,
                              approvalMessage: item.message,
                              rejectedOrderIds: _rejectedProposalOrderIds,
                              onApproval: _handleApproval,
                              onConfirmSuccess: () async {
                                await ref.read(ordersProvider.notifier).loadOrders();
                                final oid = item.message!.orderId ?? widget.chat.orderId ?? '';
                                if (oid.isNotEmpty) ref.invalidate(orderByIdProvider(oid));
                                if (mounted) await _loadMessages();
                              },
                              onConfirmWithTime: (DateTime dt) async {
                                final oid = item.message!.orderId ?? widget.chat.orderId ?? '';
                                if (oid.isNotEmpty) ref.invalidate(orderByIdProvider(oid));
                                await ref.read(ordersProvider.notifier).loadOrders();
                                if (mounted) await _loadMessages();
                              },
                            ),
                        ]
                        else
                            _MessageBubble(message: item.message!),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => _showAttachSheet(),
            child: Container(
              width: 40, height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.attach_file_rounded, size: 22, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.nestedBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 5,
                minLines: 1,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Сообщение...',
                  hintStyle: TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _hasText ? _sendMessage : null,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _hasText ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasText ? Icons.send_rounded : Icons.mic_rounded,
                size: 20,
                color: _hasText ? const Color(0xFF0D0D0D) : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendImagesFromPicker(List<XFile> files) async {
    if (files.isEmpty) return;
    final outgoing = <ChatOutgoingImage>[];
    for (final x in files) {
      final b = await x.readAsBytes();
      final name = x.name.isNotEmpty ? x.name : 'image.jpg';
      outgoing.add(ChatOutgoingImage(bytes: b, filename: name));
    }
    final text = _textController.text.trim();
    final ok = await ref.read(chatsProvider.notifier).sendMessageWithMedia(
          widget.chat.id,
          text: text,
          images: outgoing,
        );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось отправить фото. Проверьте сеть и тариф.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    _textController.clear();
    setState(() => _hasText = false);
    await _loadMessages();
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Камера',
                  color: AppColors.primary,
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (x == null || !mounted) return;
                    await _sendImagesFromPicker([x]);
                  },
                ),
                _AttachOption(
                  icon: Icons.photo_rounded,
                  label: 'Галерея',
                  color: AppColors.info,
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final imgs = await ImagePicker().pickMultiImage(imageQuality: 85);
                    if (!mounted) return;
                    await _sendImagesFromPicker(imgs);
                  },
                ),
                _AttachOption(
                  icon: Icons.description_rounded,
                  label: 'Документ',
                  color: AppColors.success,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Документы в чате пока не поддерживаются — только фото.')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ВИДЖЕТЫ СООБЩЕНИЙ
// ═══════════════════════════════════════════════

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isFromUser;
    final hasText = message.content.trim().isNotEmpty;
    final atts = message.attachments;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4, bottom: 4,
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.nestedBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (atts.isNotEmpty) ...[
              ...atts.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: AuthenticatedChatImage(attachment: a, maxHeight: 140),
                  ),
                ),
              ),
            ],
            if (hasText)
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? const Color(0xFF0D0D0D) : AppColors.textPrimary,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatters.time(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: isUser
                        ? const Color(0xFF0D0D0D).withValues(alpha: 0.6)
                        : AppColors.textTertiary,
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  _DeliveryIcon(status: message.deliveryStatus),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.status});
  final MessageDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryStatus.pending:
        return Icon(Icons.access_time, size: 13,
          color: const Color(0xFF0D0D0D).withValues(alpha: 0.5));
      case MessageDeliveryStatus.sent:
        return Icon(Icons.check, size: 13,
          color: const Color(0xFF0D0D0D).withValues(alpha: 0.6));
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all, size: 13,
          color: const Color(0xFF0D0D0D).withValues(alpha: 0.6));
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all, size: 13, color: AppColors.info);
      case MessageDeliveryStatus.error:
        return const Icon(Icons.error_outline, size: 13, color: AppColors.error);
    }
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text, style: const TextStyle(
            fontSize: 12, color: AppColors.textSecondary,
          ), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// Элемент ленты чата: заказ или сообщение (сортировка по времени создания/обновления).
class _TimelineItem {
  final DateTime sortAt;
  final Order? order;
  final ChatMessage? message;

  _TimelineItem._({required this.sortAt, this.order, this.message});
  factory _TimelineItem.order(Order o) => _TimelineItem._(sortAt: o.timelineSortAt, order: o);
  factory _TimelineItem.message(ChatMessage m) => _TimelineItem._(sortAt: m.timestamp, message: m);
  bool get isOrder => order != null;
}

class _OrderTimelineCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderTimelineCard({required this.order, required this.onTap});

  static String _bookingTimeRange(Order order) {
    final start = order.plannedStartTime ?? order.dateTime;
    final end = order.plannedEndTime;
    final durationMin = order.items.fold<int>(0, (s, i) => s + i.estimatedMinutes);
    final endComputed = end ?? start.add(Duration(minutes: durationMin > 0 ? durationMin : 60));
    return '${Formatters.time(start)}–${Formatters.time(endComputed)}';
  }

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    final ds = order.displayStatus;
    final range = _bookingTimeRange(order);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: order.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: order.status.color.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ds.color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ds.color.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        ds.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ds.color),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              '#${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            range,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ds.color,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка «Заявка отправлена» по сообщению с message_type=booking_card. Без кнопок согласования — только информирование.
class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.message,
    this.orderNumber,
    required this.sentAt,
  });
  final ChatMessage message;
  final String? orderNumber;
  final DateTime sentAt;

  @override
  Widget build(BuildContext context) {
    final items = message.orderItemsSnapshot ?? message.approvalItems ?? <ApprovalMessageItem>[];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.statusPending.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.statusPending),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Заявка отправлена',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (orderNumber != null && orderNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        orderNumber!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ожидайте подтверждения. Мы свяжемся с вами.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (items.isNotEmpty) ...[
            const Divider(color: AppColors.border, height: 24),
            const Text('Выбранные услуги:', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
            )),
            const SizedBox(height: 6),
            ...items.map((item) => _WorkRow(
                  name: item.name,
                  price: Formatters.money(item.priceKopecks),
                  duration: item.estimatedMinutes > 0 ? '${item.estimatedMinutes} мин' : '',
                )),
          ],
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                Formatters.time(sentAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка для клиента: заявка создана, ожидание подтверждения сервисом. Без кнопки «Подтвердить» — подтверждает только организация.
class _ClientOrderCreatedCard extends StatelessWidget {
  const _ClientOrderCreatedCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final displayItems = order.items.where((i) => i.isApproved && !i.isRejected).toList();
    final totalKopecks = order.totalKopecks;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.statusPending.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.statusPending),
              const SizedBox(width: 8),
              const Text(
                'Заявка отправлена',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ожидайте подтверждения. Мы свяжемся с вами.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => pushCupertino(context, OrderDetailScreen(order: order)),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary.withValues(alpha: 0.9)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Номер заказа',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                              letterSpacing: 0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          if (order.plannedStartTime != null || order.plannedEndTime != null) ...[
            const SizedBox(height: 8),
            Text(
              order.plannedStartTime != null && order.plannedEndTime != null
                  ? '${Formatters.dateShortRu(order.plannedStartTime!)} ${Formatters.time(order.plannedStartTime!)} – ${Formatters.time(order.plannedEndTime!)}'
                  : order.plannedEndTime != null
                      ? 'Ориентировочное окончание: ${Formatters.time(order.plannedEndTime!)} ${Formatters.dateShortRu(order.plannedEndTime!)}'
                      : '${Formatters.dateShortRu(order.dateTime)} ${Formatters.time(order.dateTime)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '${Formatters.dateShortRu(order.dateTime)} ${Formatters.time(order.dateTime)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          const Divider(color: AppColors.border, height: 24),
          const Text('Перечень работ:', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
          )),
          const SizedBox(height: 6),
          ...displayItems.map((item) => _WorkRow(
                name: item.name,
                price: Formatters.money(item.priceKopecks),
                duration: item.durationLabel,
              )),
          const Divider(color: AppColors.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого:', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
              )),
              Text(
                Formatters.money(totalKopecks),
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.primary, fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          Formatters.dateFullRu(date),
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// КАРТОЧКА СОГЛАСОВАНИЯ
// ═══════════════════════════════════════════════

class _ApprovalCard extends ConsumerStatefulWidget {
  final Chat chat;
  final ChatMessage? approvalMessage;
  /// Заказы, по которым клиент отклонил предложение — карточка показывается как закрытая.
  final Set<String> rejectedOrderIds;
  final Future<void> Function({
    required bool approved,
    required Set<String> checkedItemIds,
    String? orderId,
    String? approvalCarId,
    String? approvalMessageId,
  }) onApproval;
  final Future<void> Function()? onConfirmSuccess;
  /// Вызывается после подтверждения записи с выбранным временем (отправка системного сообщения в чат).
  final Future<void> Function(DateTime dateTime)? onConfirmWithTime;
  const _ApprovalCard({
    super.key,
    required this.chat,
    this.approvalMessage,
    this.rejectedOrderIds = const {},
    required this.onApproval,
    this.onConfirmSuccess,
    this.onConfirmWithTime,
  });

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  late Set<String> _checked;
  bool _isActioned = false;
  String? _actionLabel;
  bool _isConfirming = false;
  bool _isSubmittingApproval = false;
  /// Черновик времени: выбор слота без API; применяется по кнопке «Подтвердить».
  DateTime? _draftSelectedTime;

  /// Строго orderId из сообщения согласования (не из chat).
  String get _effectiveOrderId => widget.approvalMessage?.orderId?.trim() ?? '';

  /// Id новых/предложенных позиций из карточки (msg_0 / proposed_0 / явный id) — для второго круга согласования при уже существующих доп. работах.
  Set<String> _idsFromApprovalNewList() {
    final msg = widget.approvalMessage;
    final newList = msg?.newApprovalItems ?? msg?.approvalItems;
    if (newList == null || newList.isEmpty) return {};
    return newList.asMap().entries.map((e) => e.value.id ?? 'msg_${e.key}').toSet();
  }

  @override
  void initState() {
    super.initState();
    final orderId = _effectiveOrderId;
    if (orderId.isEmpty) {
      _checked = {'i10'};
      return;
    }
    Order? order; try { order = (ref.read(ordersProvider).valueOrNull ?? []).firstWhere((o) => o.id == orderId); } catch (_) {}
    final fromOrder = order?.items.where((i) => i.isAdditional && !i.isRejected).map((i) => i.id).toSet() ?? {};
    final fromMessage = _idsFromApprovalNewList();
    // Важно: объединять заказ + сообщение. Иначе при 2-м запросе от сервиса (уже есть доп. в БД) в _checked не попадут new_items,
    // approve уйдёт только с uuid старых доп., бэкенд не вставит новые строки — «согласование» пустое по составу.
    _checked = {...fromOrder, ...fromMessage};
    if (_checked.isEmpty) _checked = {'i10'};
    final rejectedByUser = widget.rejectedOrderIds.contains(orderId);
    if (rejectedByUser) {
      _isActioned = true;
      _actionLabel = 'Отклонено';
    } else if (order != null && order.status != OrderStatus.pendingApproval && order.status != OrderStatus.pendingConfirmation) {
      _isActioned = true;
      // После подтверждения клиентом статус confirmed/in_progress/completed/done — показываем «Одобрено»
      final isAcceptedStatus = order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.inProgress ||
          order.status == OrderStatus.completed ||
          order.status == OrderStatus.done;
      _actionLabel = isAcceptedStatus ? 'Одобрено' : (order.items.any((i) => i.isAdditional && i.isApproved) ? 'Одобрено' : 'Отклонено');
    }
  }

  @override
  void didUpdateWidget(covariant _ApprovalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final orderId = _effectiveOrderId;
    if (orderId.isNotEmpty && widget.rejectedOrderIds.contains(orderId) && !_isActioned) {
      setState(() {
        _isActioned = true;
        _actionLabel = 'Отклонено';
      });
    }
  }

  /// Первичное согласование (перечень + время): сервис отправил предложение, ждём ответ клиента.
  bool _showInitialTimeAgreement(Order order) {
    if (order.status == OrderStatus.pendingConfirmation) return true;
    if (order.status == OrderStatus.pendingApproval &&
        order.items.every((i) => !i.isAdditional)) return true;
    return false;
  }

  Future<void> _confirmOrderWithTime(DateTime? dateTime, {bool acceptProposed = true}) async {
    final orderId = _effectiveOrderId;
    if (orderId.isEmpty) return;
    setState(() => _isConfirming = true);
    Order? order;
    try {
      order = ref.read(ordersProvider).valueOrNull?.firstWhere((o) => o.id == orderId);
    } catch (_) {
      order = null;
    }
    final hasPendingApproval = order?.status == OrderStatus.pendingApproval ?? false;
    final am = widget.approvalMessage;
    final safeMsgId =
        am != null && am.id.isNotEmpty && !am.id.startsWith('temp_') ? am.id : null;
    if (hasPendingApproval) {
      final approvalResult = await ref.read(ordersProvider.notifier).approveItems(
        orderId,
        approvedItemIds: const ['0'],
        rejectedItemIds: [],
        approvalMessageId: safeMsgId,
      );
      if (approvalResult.dataOrNull == null) {
        if (mounted) {
          setState(() => _isConfirming = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approvalResult.errorOrNull?.message ?? 'Не удалось согласовать. Откройте чат и обновите.'),
            backgroundColor: AppColors.error,
          ));
        }
        return;
      }
    }
    final confirmResult = await ref.read(ordersProvider.notifier).confirmOrder(
      orderId,
      dateTime: dateTime,
      acceptProposed: acceptProposed,
      approvalMessageId: safeMsgId,
    );
    if (!mounted) return;
    final ok = confirmResult.errorOrNull == null;
    setState(() {
      _isConfirming = false;
      if (ok) {
        _isActioned = true;
        _actionLabel = 'Запись подтверждена';
        _draftSelectedTime = null;
      }
    });
    if (ok && mounted) {
      ref.invalidate(orderByIdProvider(orderId));
      await ref.read(ordersProvider.notifier).loadOrders();
      await ref.read(chatsProvider.notifier).loadChats();
      await ref.refresh(orderByIdProvider(orderId));
      if (mounted) setState(() {});
      await widget.onConfirmSuccess?.call();
      if (dateTime != null) await widget.onConfirmWithTime?.call(dateTime);
      if (mounted) {
        await ref.read(notificationsProvider.notifier).markReadByOrderId(orderId);
        ref.invalidate(unreadNotificationCountProvider);
        ref.invalidate(unreadByCarProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись подтверждена'), backgroundColor: AppColors.success),
        );
      }
    } else if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(confirmResult.errorOrNull?.message ?? 'Не удалось подтвердить заказ'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _pickNewTime() async {
    final orderId = _effectiveOrderId;
    if (orderId.isEmpty) return;
    Order? order;
    try {
      order = (ref.read(ordersProvider).valueOrNull ?? []).firstWhere((o) => o.id == orderId);
    } catch (_) {
      order = ref.read(orderByIdProvider(orderId)).valueOrNull;
    }
    final initial = order != null ? order.dateTime : (widget.approvalMessage?.proposedDateTime ?? DateTime.now().add(const Duration(days: 1)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _confirmOrderWithTime(chosen, acceptProposed: false);
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _effectiveOrderId;
    if (orderId.isEmpty) return const SizedBox.shrink();

    Order? orderFromList;
    try {
      orderFromList = (ref.watch(ordersProvider).valueOrNull ?? []).firstWhere((o) => o.id == orderId);
    } catch (_) {}
    final orderAsync = ref.watch(orderByIdProvider(orderId));
    final order = orderFromList ?? orderAsync.valueOrNull;

    if (order == null) {
      if (orderAsync.isLoading) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('Загрузка заказа...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
        );
      }
      final hasError = orderAsync.hasError;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasError ? 'Не удалось загрузить заказ' : 'Заказ не найден',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (hasError) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ref.invalidate(orderByIdProvider(orderId)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Синхронизируем _checked при первой загрузке заказа: доп. из БД + id из карточки (новые позиции), не затирая msg_*.
    final orderAdditionalIds = order.items.where((i) => i.isAdditional && !i.isRejected).map((i) => i.id).toSet();
    final fromMsg = _idsFromApprovalNewList();
    if (_checked == {'i10'} && (orderAdditionalIds.isNotEmpty || fromMsg.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _checked = {...orderAdditionalIds, ...fromMsg});
      });
    }
    if (order.status != OrderStatus.pendingApproval && order.status != OrderStatus.pendingConfirmation && !_isActioned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isActioned = true;
          final isAcceptedStatus = order.status == OrderStatus.confirmed ||
              order.status == OrderStatus.inProgress ||
              order.status == OrderStatus.completed ||
              order.status == OrderStatus.done;
          _actionLabel = isAcceptedStatus ? 'Одобрено' : (order.items.any((i) => i.isAdditional && i.isApproved) ? 'Одобрено' : 'Отклонено');
        });
      });
    }

    // Контент карточки: из заказа (оригинал) и из сообщения (скорректированные / добавленные).
    final originalItems = order.items.where((i) => !i.isAdditional).toList();
    final orderAdditionalItems = order.items.where((i) => i.isAdditional && !i.isRejected).toList();
    final rawEditedItems = widget.approvalMessage?.editedApprovalItems ?? [];
    // Скорректированные — только те, у которых реально изменились цена или время относительно оригинала
    final editedItems = rawEditedItems.where((e) {
      OrderItem? orig;
      try {
        orig = originalItems.firstWhere((o) => o.id == e.id);
      } catch (_) {
        orig = null;
      }
      if (orig == null) return true;
      return (orig.priceKopecks) != e.priceKopecks || orig.estimatedMinutes != e.estimatedMinutes;
    }).toList();
    final newItems = widget.approvalMessage?.newApprovalItems ?? [];
    final legacyMessageItems = widget.approvalMessage?.approvalItems ?? [];
    final messageItems = newItems.isNotEmpty ? newItems : legacyMessageItems;
    // При повторном согласовании показываем позиции из текущего сообщения, а не из заказа (где уже старые доп.работы).
    final useMessageForAdditional = messageItems.isNotEmpty;
    final additionalItemsForDisplay = useMessageForAdditional
        ? messageItems
        : orderAdditionalItems;

    final originalTotal = originalItems.fold(0, (sum, i) => sum + (i.priceKopecks ?? 0));
    final editedTotal = editedItems.fold(0, (s, i) => s + i.priceKopecks);
    int additionalTotal;
    int additionalTime;
    if (useMessageForAdditional) {
      String itemKey(ApprovalMessageItem item, int index) => item.id ?? 'msg_$index';
      final checkedCount = messageItems.asMap().entries.where((e) => _checked.contains(itemKey(e.value, e.key))).length;
      additionalTotal = checkedCount == messageItems.length
          ? messageItems.fold(0, (s, i) => s + i.priceKopecks)
          : messageItems.asMap().entries.where((e) => _checked.contains(itemKey(e.value, e.key))).fold(0, (s, e) => s + e.value.priceKopecks);
      additionalTime = messageItems.asMap().entries.where((e) => _checked.contains(itemKey(e.value, e.key))).fold(0, (s, e) => s + e.value.estimatedMinutes);
    } else {
      additionalTotal = orderAdditionalItems.where((i) => _checked.contains(i.id)).fold(0, (sum, i) => sum + (i.priceKopecks ?? 0));
      additionalTime = orderAdditionalItems.where((i) => _checked.contains(i.id)).fold(0, (sum, i) => sum + i.estimatedMinutes);
    }
    final grandTotal = originalTotal + editedTotal + additionalTotal;
    // Для единообразия 1-го и 2-го согласования используем итоги из сообщения, если есть.
    final displayWasTotal = widget.approvalMessage?.totalsBeforePriceKopecks ?? originalTotal;
    final displayTotalTotal = widget.approvalMessage?.totalsAfterPriceKopecks ?? grandTotal;
    final displayAddedTotal = displayTotalTotal - displayWasTotal;
    final isNewOrderFromSto = originalItems.isEmpty &&
        (widget.approvalMessage?.originalApprovalItems == null || widget.approvalMessage!.originalApprovalItems!.isEmpty) &&
        (messageItems.isNotEmpty || newItems.isNotEmpty || editedItems.isEmpty);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isActioned
            ? (_actionLabel == 'Одобрено' ? AppColors.success : AppColors.error).withValues(alpha: 0.4)
            : AppColors.statusApproval.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(_isActioned ? (_actionLabel == 'Одобрено' ? '✅' : '❌') : '⚠️',
                style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isActioned ? _actionLabel! : 'Требуется согласование',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: _isActioned
                        ? (_actionLabel == 'Одобрено' ? AppColors.success : AppColors.error)
                        : AppColors.statusApproval,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Material(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => pushCupertino(context, OrderDetailScreen(order: order)),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.primary.withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Номер заказа',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                              letterSpacing: 0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          if (widget.approvalMessage?.approvalCarId?.trim().isEmpty ?? true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.directions_car_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('Для всех машин', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          const Divider(color: AppColors.border, height: 24),

          // Новый заказ от сервиса (нет исходных позиций) — только список «Услуги». Иначе — исходный состав + изменения.
          if (isNewOrderFromSto && messageItems.isNotEmpty) ...[
            const Text('Услуги:', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
            )),
            const SizedBox(height: 6),
            ...messageItems.asMap().entries.map((e) => _CheckableWorkRow(
              name: e.value.name,
              price: Formatters.money(e.value.priceKopecks),
              duration: Formatters.durationMinutes(e.value.estimatedMinutes),
              comment: null,
              isChecked: _checked.contains(e.value.id ?? 'msg_${e.key}'),
              enabled: !_isActioned,
              onChanged: (v) {
                setState(() {
                  if (v) _checked.add(e.value.id ?? 'msg_${e.key}');
                  else _checked.remove(e.value.id ?? 'msg_${e.key}');
                });
              },
            )),
          ] else ...[
            if (widget.approvalMessage?.originalApprovalItems != null && widget.approvalMessage!.originalApprovalItems!.isNotEmpty) ...[
              const Text('Текущий состав заказа', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
              )),
              const SizedBox(height: 6),
              ...widget.approvalMessage!.originalApprovalItems!.map((item) => _WorkRow(
                name: item.name,
                price: Formatters.money(item.priceKopecks),
                duration: Formatters.durationMinutes(item.estimatedMinutes),
              )),
            ] else if (originalItems.isNotEmpty) ...[
              const Text('Изначально согласовано:', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
              )),
              const SizedBox(height: 6),
              ...originalItems.map((item) => _WorkRow(
                name: item.name,
                price: Formatters.money(item.priceKopecks),
                duration: item.durationLabel,
              )),
            ],
            if (editedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Скорректированные услуги:', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
              )),
              const SizedBox(height: 6),
              ...editedItems.map((item) => _WorkRow(
                name: item.name,
                price: Formatters.money(item.priceKopecks),
                duration: '${item.estimatedMinutes} мин',
              )),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(newItems.isNotEmpty ? 'Добавленные услуги:' : 'Добавлено сервисом:', style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.statusApproval,
                )),
                const Spacer(),
                if (additionalTime > 0 && !_isActioned)
                  Text('+ ${Formatters.durationMinutes(additionalTime)}', style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
            const SizedBox(height: 6),
            if (useMessageForAdditional)
              ...messageItems.asMap().entries.map((e) => _CheckableWorkRow(
              name: e.value.name,
              price: Formatters.money(e.value.priceKopecks),
              duration: '${e.value.estimatedMinutes} мин',
              comment: null,
              isChecked: _checked.contains(e.value.id ?? 'msg_${e.key}'),
              enabled: !_isActioned,
              onChanged: (v) {
                setState(() {
                  if (v) _checked.add(e.value.id ?? 'msg_${e.key}');
                  else _checked.remove(e.value.id ?? 'msg_${e.key}');
                });
              },
            ))
          else
            ...orderAdditionalItems.map((item) => _CheckableWorkRow(
              name: item.name,
              price: Formatters.money(item.priceKopecks ?? 0),
              duration: item.durationLabel,
              comment: item.id == 'i10' ? 'Фреон подтекает, необходима заправка' : null,
              isChecked: _checked.contains(item.id),
              enabled: !_isActioned,
              onChanged: (v) {
                setState(() {
                  if (v) _checked.add(item.id);
                  else _checked.remove(item.id);
                });
              },
            )),
          ],

          const Divider(color: AppColors.border, height: 24),

          // Итого (для нового заказа от сервиса — только итого; иначе — было / добавлено / итого)
          if (!isNewOrderFromSto) _PriceRow('Было:', Formatters.money(displayWasTotal)),
          if (editedTotal > 0)
            _PriceRow('Скорректировано:', Formatters.money(editedTotal),
              color: AppColors.textSecondary),
          if (!isNewOrderFromSto && (displayAddedTotal != 0 || _checked.isNotEmpty))
            _PriceRow(newItems.isNotEmpty ? 'Добавленные услуги:' : 'Добавлено сервисом:', Formatters.money(displayAddedTotal != 0 ? displayAddedTotal : additionalTotal), color: AppColors.statusApproval),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Итого:', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
              )),
              Text(
                Formatters.money(displayTotalTotal),
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.primary, fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          // Время выполнения с ... до ... и кнопка «Изменить» (сетка слотов); Подтвердить / Отклонить.
          if (!_isActioned && _showInitialTimeAgreement(order)) ...[
            const Divider(color: AppColors.border, height: 24),
            Builder(
              builder: (context) {
                final effectiveStart = _draftSelectedTime ?? order.plannedStartTime ?? widget.approvalMessage?.proposedDateTime ?? order.dateTime;
                final durationMin = widget.approvalMessage?.totalsAfterMinutes ?? widget.approvalMessage?.approvalTotalMinutes ?? order.items.fold<int>(0, (s, i) => s + i.estimatedMinutes);
                final duration = durationMin > 0 ? durationMin : 60;
                final effectiveEnd = effectiveStart.add(Duration(minutes: duration));
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Время выполнения с ${Formatters.time(effectiveStart)} до ${Formatters.time(effectiveEnd)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: _isConfirming ? null : () async {
                        final orderId = _effectiveOrderId;
                        if (orderId.isEmpty) return;
                        final serviceIds = order.items
                            .map((i) => i.serviceId)
                            .whereType<String>()
                            .where((id) => id.isNotEmpty)
                            .toList();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ApprovalSlotPickerScreen(
                              orderId: orderId,
                              stoId: widget.chat.stoId,
                              serviceIds: serviceIds,
                              onTimeSelected: (DateTime chosen) {
                                setState(() => _draftSelectedTime = chosen);
                                if (context.mounted) Navigator.of(context).pop();
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Изменить'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmittingApproval ? null : () async {
                      setState(() { _isSubmittingApproval = true; _draftSelectedTime = null; });
                      await widget.onApproval(
                        approved: false,
                        checkedItemIds: {},
                        orderId: _effectiveOrderId.isEmpty ? null : _effectiveOrderId,
                        approvalCarId: widget.approvalMessage?.approvalCarId,
                        approvalMessageId: widget.approvalMessage?.id,
                      );
                      if (mounted) setState(() => _isSubmittingApproval = false);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textTertiary),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(_isSubmittingApproval ? '...' : 'Отклонить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isConfirming ? null : () => _confirmOrderWithTime(
                      _draftSelectedTime ?? order.plannedStartTime ?? widget.approvalMessage?.proposedDateTime,
                      acceptProposed: _draftSelectedTime == null,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: const Text('Подтвердить'),
                  ),
                ),
              ],
            ),
          ],

          // Кнопки согласования доп. работ (когда заказ уже в работе)
          if (!_isActioned && order.status == OrderStatus.pendingApproval && order.items.any((i) => i.isAdditional)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmittingApproval ? null : () async {
                      setState(() => _isSubmittingApproval = true);
                      await widget.onApproval(
                        approved: false,
                        checkedItemIds: {},
                        orderId: _effectiveOrderId.isEmpty ? null : _effectiveOrderId,
                        approvalCarId: widget.approvalMessage?.approvalCarId,
                        approvalMessageId: widget.approvalMessage?.id,
                      );
                      if (mounted) setState(() => _isSubmittingApproval = false);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textTertiary),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(_isSubmittingApproval ? '...' : 'Отклонить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: (_checked.isEmpty || _isSubmittingApproval) ? null : () async {
                          setState(() => _isSubmittingApproval = true);
                          await widget.onApproval(
                            approved: true,
                            checkedItemIds: Set.from(_checked),
                            orderId: _effectiveOrderId.isEmpty ? null : _effectiveOrderId,
                            approvalCarId: widget.approvalMessage?.approvalCarId,
                            approvalMessageId: widget.approvalMessage?.id,
                          );
                          if (mounted) setState(() => _isSubmittingApproval = false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          _isSubmittingApproval ? '...' : 'Согласовать (${_checked.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _checked.isEmpty
                                ? AppColors.textTertiary
                                : const Color(0xFF0D0D0D),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

}

class _WorkRow extends StatelessWidget {
  final String name, price;
  final String? duration;
  const _WorkRow({required this.name, required this.price, this.duration});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              if (duration != null)
                Text('⏱ $duration', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          )),
          Text(price, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _CheckableWorkRow extends StatelessWidget {
  final String name, price;
  final String? duration, comment;
  final bool isChecked, enabled;
  final ValueChanged<bool> onChanged;
  const _CheckableWorkRow({
    required this.name, required this.price,
    this.duration, this.comment, required this.isChecked,
    required this.enabled, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: isChecked,
                  onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                  activeColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.textTertiary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  if (duration != null)
                    Text('⏱ $duration', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              )),
              Text(price, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.statusApproval,
              )),
            ],
          ),
          if (comment != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(comment!, style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic,
              )),
            ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _PriceRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 14, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
