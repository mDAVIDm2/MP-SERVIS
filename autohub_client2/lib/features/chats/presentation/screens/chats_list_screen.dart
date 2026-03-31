import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  bool _showActive = true;

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    var allChats = chatsAsync.valueOrNull ?? [];
    final filterByCar = ref.watch(filterByCarSettingProvider);
    final selectedCarId = ref.watch(selectedCarIdProvider);
    final ordersAsync = ref.watch(ordersProvider);
    if (filterByCar && selectedCarId != null && ordersAsync.hasValue) {
      final orders = ordersAsync.valueOrNull ?? [];
      allChats = allChats.where((c) {
        final ordersInThisChat = orders.where((o) => o.stoId == c.stoId);
        if (ordersInThisChat.isEmpty) return true;
        return ordersInThisChat.any((o) => o.carId.isEmpty || o.carId == selectedCarId);
      }).toList();
    }
    final activeChats = allChats.where((c) => c.orderStatus.isActive).toList();
    final doneChats = allChats.where((c) => !c.orderStatus.isActive).toList();
    final chats = _showActive ? activeChats : doneChats;

    final ordersReady = ordersAsync.hasValue;
    final orders = ordersAsync.valueOrNull ?? [];
    int unreadForList(Chat c) => chatUnreadForChatsScreen(
      c,
      filterByCar: filterByCar,
      selectedCarId: selectedCarId,
      ordersReady: ordersReady,
      orders: orders,
    );
    final headerUnreadTotal = chats.fold<int>(0, (s, c) => s + unreadForList(c));

    final pinned = chats.where((c) => c.isPinned || c.needsAction).toList();
    final unpinned = chats.where((c) => !c.isPinned && !c.needsAction).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Чаты', style: AppTextStyles.screenTitle),
                  if (headerUnreadTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          headerUnreadTotal > 99 ? '99+' : '$headerUnreadTotal',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D0D0D),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Поиск по чатам...',
                          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                          filled: false, contentPadding: EdgeInsets.zero, isDense: true,
                          hintStyle: TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
                        ),
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _filterTab('Активные (${activeChats.length})', _showActive, () => setState(() => _showActive = true))),
                  const SizedBox(width: 2),
                  Expanded(child: _filterTab('Завершённые (${doneChats.length})', !_showActive, () => setState(() => _showActive = false))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: chatsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
                data: (_) => chats.isEmpty
                    ? const EmptyState(
                      icon: '💬',
                      title: 'Нет чатов',
                      subtitle: 'Чаты создаются при записи в автосервис.\nЗакажите услугу в разделе Поиск.',
                      buttonText: 'Найти сервис',
                    )
                    : ListView(
                      children: [
                        if (pinned.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text('📌 ЗАКРЕПЛЁННЫЕ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                          ),
                          ...pinned.map((c) => _ChatCard(
                                chat: c,
                                displayUnreadCount: unreadForList(c),
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
                              )),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text('ВСЕ ЧАТЫ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                          ),
                        ],
                        ...unpinned.map((c) => _ChatCard(
                              chat: c,
                              displayUnreadCount: unreadForList(c),
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
                            )),
                        const SizedBox(height: 24),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterTab(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Center(
          child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? const Color(0xFF0D0D0D) : AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final Chat chat;
  final int displayUnreadCount;
  final VoidCallback onOrderTap;

  const _ChatCard({required this.chat, required this.displayUnreadCount, required this.onOrderTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = displayUnreadCount > 0;
    final isSupportChat = chat.isSupportChat;
    return Container(
      color: hasUnread ? AppColors.cardBg : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.nestedBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(chat.stoName.isNotEmpty ? chat.stoName.substring(0, 1) : '?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(chat.stoName, style: AppTextStyles.cardTitle.copyWith(fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (chat.lastMessageTime != null) Text(Formatters.chatTime(chat.lastMessageTime!), style: AppTextStyles.small.copyWith(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (isSupportChat)
                    const Row(
                      children: [
                        Icon(Icons.support_agent_rounded, size: 13, color: AppColors.info),
                        SizedBox(width: 5),
                        Text(
                          'Поддержка',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.info),
                        ),
                      ],
                    )
                  else if (chat.needsAction)
                    const Text('⚠️ Требуется согласование', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning))
                  else
                    Row(children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: chat.orderStatus.color, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(chat.orderStatus.label, style: TextStyle(fontSize: 13, color: chat.orderStatus.color)),
                    ]),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessageFromUser ? 'Вы: ${chat.lastMessage ?? ''}' : chat.lastMessage ?? '',
                          style: TextStyle(fontSize: 13, color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageFromUser && chat.lastMessageStatus == MessageDeliveryStatus.read)
                        const Text(' ✓✓', style: TextStyle(fontSize: 12, color: AppColors.info)),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                          child: Text(displayUnreadCount > 99 ? '99+' : '$displayUnreadCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D0D0D))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Общий чат: не показываем #orderNumber (один чат на пару клиент↔сервис).
                  Text(
                    chat.chatWithOrganizationSubtitle,
                    style: AppTextStyles.small.copyWith(color: AppColors.textTertiary, fontSize: 11),
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
