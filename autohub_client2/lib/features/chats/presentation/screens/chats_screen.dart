import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/archived_chats_provider.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  bool _showArchived = false;

  List<Chat> _sortedChats(
    List<Chat> list, {
    required bool filterByCar,
    String? selectedCarId,
    required bool ordersReady,
    required List<Order> orders,
  }) {
    int u(Chat c) => chatUnreadForChatsScreen(
      c,
      filterByCar: filterByCar,
      selectedCarId: selectedCarId,
      ordersReady: ordersReady,
      orders: orders,
    );
    final copy = List<Chat>.from(list);
    copy.sort((a, b) {
      if (a.needsAction != b.needsAction) return a.needsAction ? -1 : 1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (u(a) != u(b)) return u(b).compareTo(u(a));
      return (b.lastMessageTime ?? DateTime(2000)).compareTo(a.lastMessageTime ?? DateTime(2000));
    });
    return copy;
  }

  Widget _buildSwipeableChatCard(
    BuildContext context,
    WidgetRef ref,
    Chat c, {
    required int displayUnread,
  }) {
    final isArchived = _showArchived;
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: AppColors.nestedBg,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Text(
          isArchived ? 'Вернуть из архива' : 'В архив',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onDismissed: (_) {
        ref.read(archivedChatIdsProvider.notifier).toggle(c.id);
      },
      child: _ChatCard(
        chat: c,
        displayUnreadCount: displayUnread,
        onOrderTap: () async {
          var result = await ref.read(orderRepositoryProvider).getOrderById(c.orderId);
          if (context.mounted && result.dataOrNull != null) {
            pushCupertino(context, OrderDetailScreen(order: result.dataOrNull!));
            return;
          }
          ref.read(ordersProvider.notifier).loadOrders();
          await Future.delayed(const Duration(milliseconds: 500));
          if (!context.mounted) return;
          final orders = ref.read(ordersProvider).valueOrNull ?? [];
          Order? order;
          try {
            order = orders.firstWhere((o) => o.id == c.orderId);
          } catch (_) {}
          if (context.mounted && order != null) {
            pushCupertino(context, OrderDetailScreen(order: order));
            return;
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Не удалось открыть заказ. Проверьте подключение.')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    final allChats = chatsAsync.valueOrNull ?? [];
    final archivedIds = ref.watch(archivedChatIdsProvider);
    var mainChats = allChats.where((c) => !archivedIds.contains(c.id)).toList();
    var archivedChats = allChats.where((c) => archivedIds.contains(c.id)).toList();
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final selectedCarId = ref.watch(selectedCarIdProvider);
    final ordersAsync = ref.watch(ordersProvider);
    // Фильтруем по машине только когда заказы уже загружены — иначе при загрузке показывалось бы «Нет чатов».
    // Показываем чат, если у выбранной машины есть хотя бы один заказ у этой организации (один чат на пару клиент↔точка).
    if (filterByCar && selectedCarId != null && ordersAsync.hasValue) {
      final orders = ordersAsync.valueOrNull ?? [];
      mainChats = mainChats.where((c) {
        final ordersInThisChat = orders.where((o) => o.stoId == c.stoId);
        if (ordersInThisChat.isEmpty) return true;
        return ordersInThisChat.any((o) => o.carId.isEmpty || o.carId == selectedCarId);
      }).toList();
      archivedChats = archivedChats.where((c) {
        final ordersInThisChat = orders.where((o) => o.stoId == c.stoId);
        if (ordersInThisChat.isEmpty) return true;
        return ordersInThisChat.any((o) => o.carId.isEmpty || o.carId == selectedCarId);
      }).toList();
    }
    final ordersReady = ordersAsync.hasValue;
    final orders = ordersAsync.valueOrNull ?? [];
    int unreadForList(Chat c) => chatUnreadForChatsScreen(
      c,
      filterByCar: filterByCar,
      selectedCarId: selectedCarId,
      ordersReady: ordersReady,
      orders: orders,
    );
    final chats = _showArchived
        ? _sortedChats(
            archivedChats,
            filterByCar: filterByCar,
            selectedCarId: selectedCarId,
            ordersReady: ordersReady,
            orders: orders,
          )
        : _sortedChats(
            mainChats,
            filterByCar: filterByCar,
            selectedCarId: selectedCarId,
            ordersReady: ordersReady,
            orders: orders,
          );
    final headerUnreadTotal = chats.fold<int>(0, (s, c) => s + unreadForList(c));
    final pinnedChats = chats.where((c) => c.isPinned || c.needsAction).toList();
    final regularChats = chats.where((c) => !c.isPinned && !c.needsAction).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header: сумма непрочитанного только по выбранной машине (при фильтре и загруженных заказах).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Чаты', style: AppTextStyles.screenTitle),
                      ),
                    ),
                    if (headerUnreadTotal > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          headerUnreadTotal > 99 ? '99+' : '$headerUnreadTotal',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D0D0D),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Поиск
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 14),
                    Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Поиск по чатам...',
                          hintStyle: TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Кнопка «Архив» для переключения на архивные чаты
            if (archivedChats.isNotEmpty || _showArchived)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _showArchived = !_showArchived),
                      icon: Icon(
                        _showArchived ? Icons.inbox_rounded : Icons.archive_rounded,
                        size: 20,
                        color: _showArchived ? AppColors.primary : AppColors.textSecondary,
                      ),
                      label: Text(
                        _showArchived ? 'Чаты' : 'Архив (${archivedChats.length})',
                        style: TextStyle(
                          fontSize: 14,
                          color: _showArchived ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Список чатов
            Expanded(
              child: chatsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Ошибка: $e')),
                data: (_) => chats.isEmpty
                    ? EmptyState(
                        icon: _showArchived ? '📦' : '💬',
                        title: _showArchived ? 'Нет чатов в архиве' : 'Нет чатов',
                        subtitle: _showArchived
                            ? 'Смахните чат вправо в основном списке, чтобы перенести в архив.'
                            : 'Чаты создаются при записи в автосервис.\nЗакажите услугу в разделе Поиск.',
                        buttonText: _showArchived ? null : 'Найти сервис',
                      )
                    : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (pinnedChats.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text('📌 ЗАКРЕПЛЁННЫЕ', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary,
                              letterSpacing: 0.5,
                            )),
                          ),
                          ...pinnedChats.map((c) => _buildSwipeableChatCard(context, ref, c, displayUnread: unreadForList(c))),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text('ВСЕ ЧАТЫ', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary,
                              letterSpacing: 0.5,
                            )),
                          ),
                        ],
                        ...regularChats.map((c) => _buildSwipeableChatCard(context, ref, c, displayUnread: unreadForList(c))),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final Chat chat;
  /// С учётом выбранной машины на экране «Чаты»; в нижней панели — отдельно, по всем машинам.
  final int displayUnreadCount;
  final VoidCallback onOrderTap;

  const _ChatCard({required this.chat, required this.displayUnreadCount, required this.onOrderTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = displayUnreadCount > 0;
    final isSupportChat = chat.isSupportChat;

    return GestureDetector(
      onTap: () => pushCupertino(context, ChatDetailScreen(chat: chat)),
      child: Container(
        color: hasUnread ? AppColors.cardBg : AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Лого организации
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.nestedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(chat.stoName.isNotEmpty ? chat.stoName[0] : '?', style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary,
                )),
              ),
            ),
            const SizedBox(width: 12),
            // Контент
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Строка 1: название + время
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.stoName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageTime != null)
                        Text(
                          Formatters.chatTime(chat.lastMessageTime!),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Строка 2: статус заказа
                  if (isSupportChat)
                    const Row(
                      children: [
                        Icon(Icons.support_agent_rounded, size: 14, color: AppColors.info),
                        SizedBox(width: 6),
                        Text(
                          'Поддержка',
                          style: TextStyle(fontSize: 14, color: AppColors.info, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else if (chat.needsAction)
                    Text(
                      '⚠️ Требуется согласование',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.statusApproval,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: chat.orderStatus.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(chat.orderStatus.label, style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary,
                        )),
                      ],
                    ),
                  const SizedBox(height: 4),
                  // Строка 3: последнее сообщение + badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessageFromUser
                              ? 'Вы: ${chat.lastMessage ?? ''}'
                              : chat.lastMessage ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageFromUser && !hasUnread)
                        _DeliveryStatus(status: chat.lastMessageStatus),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          child: Text(
                            displayUnreadCount > 99 ? '99+' : '$displayUnreadCount',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D0D0D),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Общий чат: не показываем #orderNumber (один чат на пару клиент↔сервис).
                  Text(
                    chat.chatWithOrganizationSubtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryStatus extends StatelessWidget {
  final MessageDeliveryStatus status;
  const _DeliveryStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.check, size: 14, color: AppColors.textTertiary);
      case MessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: AppColors.textTertiary);
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all, size: 14, color: AppColors.info);
      case MessageDeliveryStatus.pending:
        return const Icon(Icons.access_time, size: 14, color: AppColors.textTertiary);
      case MessageDeliveryStatus.error:
        return const Icon(Icons.error_outline, size: 14, color: AppColors.error);
    }
  }
}
