import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/client_palette.dart';
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
    final l10n = L10nScope.of(context);
    final isArchived = _showArchived;
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: context.palette.nestedBg,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Text(
          isArchived ? l10n.chatsArchivedRestoreSwipe : l10n.chatsArchivedSwipe,
          style: TextStyle(
            fontSize: 14,
            color: context.palette.textSecondary,
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
              SnackBar(content: Text(l10n.orderOpenFailed)),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
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
      backgroundColor: context.palette.background,
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
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.chatsTitle, style: AppTextStyles.screenTitle(p)),
                      ),
                    ),
                    if (headerUnreadTotal > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.palette.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          headerUnreadTotal > 99 ? '99+' : '$headerUnreadTotal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.onAccent,
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
                  color: context.palette.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 14),
                    Icon(Icons.search_rounded, size: 20, color: p.textSecondary),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        style: TextStyle(fontSize: 14, color: p.textPrimary),
                        decoration: InputDecoration(
                          hintText: l10n.searchChatsHint,
                          hintStyle: TextStyle(color: p.textPlaceholder, fontSize: 14),
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
                        color: _showArchived ? context.palette.primary : context.palette.textSecondary,
                      ),
                      label: Text(
                        _showArchived ? l10n.chatsBackToList : l10n.chatsArchiveTitle(archivedChats.length),
                        style: TextStyle(
                          fontSize: 14,
                          color: _showArchived ? context.palette.primary : context.palette.textSecondary,
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
                error: (e, st) => Center(child: Text(l10n.errorColon(e))),
                data: (_) => chats.isEmpty
                    ? EmptyState(
                        icon: _showArchived ? '📦' : '💬',
                        title: _showArchived ? l10n.chatsNoInArchive : l10n.noChatsTitle,
                        subtitle: _showArchived
                            ? l10n.chatsArchiveEmptyHint
                            : l10n.noChatsSubtitle,
                        buttonText: _showArchived ? null : l10n.findService,
                      )
                    : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (pinnedChats.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text(l10n.chatsPinnedHeading, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: p.textTertiary,
                              letterSpacing: 0.5,
                            )),
                          ),
                          ...pinnedChats.map((c) => _buildSwipeableChatCard(context, ref, c, displayUnread: unreadForList(c))),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(l10n.allChatsSection, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: p.textTertiary,
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
    final l10n = L10nScope.of(context);
    final hasUnread = displayUnreadCount > 0;
    final isSupportChat = chat.isSupportChat;

    return GestureDetector(
      onTap: () => pushCupertino(context, ChatDetailScreen(chat: chat)),
      child: Container(
        color: hasUnread ? context.palette.cardBg : context.palette.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChatListOrgAvatar(logoUrl: chat.stoLogoUrl, name: chat.stoName),
            SizedBox(width: 12),
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
                            color: context.palette.textPrimary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageTime != null)
                        Text(
                          Formatters.chatTime(chat.lastMessageTime!),
                          style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Строка 2: статус заказа
                  if (isSupportChat)
                    Row(
                      children: [
                        Icon(Icons.support_agent_rounded, size: 14, color: context.palette.info),
                        SizedBox(width: 6),
                        Text(
                          l10n.supportShortLabel,
                          style: TextStyle(fontSize: 14, color: context.palette.info, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else if (chat.needsAction)
                    Text(
                      l10n.approvalRequiredShort,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.statusApproval,
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
                        SizedBox(width: 6),
                        Text(chat.orderStatus.label, style: TextStyle(
                          fontSize: 14, color: context.palette.textSecondary,
                        )),
                      ],
                    ),
                  SizedBox(height: 4),
                  // Строка 3: последнее сообщение + badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessageFromUser
                              ? '${l10n.chatYouPrefix}${chat.lastMessage ?? ''}'
                              : chat.lastMessage ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: context.palette.textSecondary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageFromUser && !hasUnread)
                        _DeliveryStatus(status: chat.lastMessageStatus),
                      if (hasUnread) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.palette.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          child: Text(
                            displayUnreadCount > 99 ? '99+' : '$displayUnreadCount',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: context.palette.onAccent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  // Общий чат: не показываем #orderNumber (один чат на пару клиент↔сервис).
                  Text(
                    chat.chatWithOrganizationSubtitle,
                    style: TextStyle(fontSize: 12, color: context.palette.textTertiary),
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

class _ChatListOrgAvatar extends StatelessWidget {
  const _ChatListOrgAvatar({required this.logoUrl, required this.name});

  final String? logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final u = logoUrl?.trim();
    if (u != null && u.isNotEmpty) {
      final resolved = AppConfig.resolveOrganizationPhotoUrl(u);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          resolved,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (ctx, __, ___) => _letter(ctx),
        ),
      );
    }
    return _letter(context);
  }

  Widget _letter(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: p.nestedBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.primary),
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
        return Icon(Icons.check, size: 14, color: context.palette.textTertiary);
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: context.palette.textTertiary);
      case MessageDeliveryStatus.read:
        return Icon(Icons.done_all, size: 14, color: context.palette.info);
      case MessageDeliveryStatus.pending:
        return Icon(Icons.access_time, size: 14, color: context.palette.textTertiary);
      case MessageDeliveryStatus.error:
        return Icon(Icons.error_outline, size: 14, color: context.palette.error);
    }
  }
}
