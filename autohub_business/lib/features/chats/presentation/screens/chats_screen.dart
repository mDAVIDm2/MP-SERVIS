import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../shared/widgets/api_failure_banner.dart';
import 'chat_detail_screen.dart';

/// Порог ширины для переключения в режим «мессенджер» (список слева, чат справа).
const double _kSplitLayoutBreakpoint = 700;

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String? _selectedChatId;

  static String _formatTime(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(d.year, d.month, d.day);
    if (msgDay == today) return DateFormat('HH:mm').format(d);
    if (now.difference(d).inDays < 2) return 'Вчера';
    return DateFormat('dd.MM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatRepositoryProvider);
    final orderIds = ref.watch(orderRepositoryProvider).map((o) => o.id).toSet();
    final syncReady = ref.watch(ordersSyncReadyForChatFilterProvider);
    final ordersLoadErr = ref.watch(ordersLoadErrorProvider);
    /// Пока заказы не подтянулись или была ошибка загрузки заказов — не отсекаем чаты по orderId (иначе список «пустой» при живом API чатов).
    final chats = syncReady
        ? state.chats.where((c) => c.isSupportChat || orderIds.contains(c.orderId)).toList()
        : state.chats.toList();
    final totalUnreadAllChats = chats.fold<int>(0, (s, c) => s + c.unreadCount);
    final loadError = state.loadError;

    Future<void> retryApi() async {
      await ref.read(orderRepositoryProvider.notifier).loadFromApi();
      await ref.read(chatRepositoryProvider.notifier).loadFromApi();
    }
    final width = MediaQuery.sizeOf(context).width;
    final useSplitLayout = isDesktopPlatform || width >= _kSplitLayoutBreakpoint;

    if (loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Чаты')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ApiFailureBanner(
              message: loadError,
              onRetry: retryApi,
            ),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Пока список чатов недоступен. После восстановления связи нажмите «Повторить».',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (useSplitLayout) {
      return Scaffold(
        backgroundColor: AppColorsDesktop.background,
        body: Column(
          children: [
            if (ordersLoadErr != null)
              ApiFailureBanner(
                message: 'Заказы: $ordersLoadErr',
                dense: true,
                onRetry: retryApi,
              ),
            Expanded(
              child: Row(
                children: [
                  Container(
              width: 320,
              decoration: BoxDecoration(
                color: AppColorsDesktop.surface,
                border: const Border(right: BorderSide(color: AppColorsDesktop.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Заголовок «Чаты» только в верхней полосе приложения (_DesktopTopBar).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Row(
                      children: [
                        const Spacer(),
                        if (totalUnreadAllChats > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColorsDesktop.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              totalUnreadAllChats > 99 ? '99+' : '$totalUnreadAllChats',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (chats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        ordersLoadErr != null
                            ? 'Нет чатов или заказы не загрузились — см. баннер сверху.'
                            : 'Нет чатов',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColorsDesktop.textSecondary),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: chats.length,
                        itemBuilder: (context, i) {
                          final c = chats[i];
                          final isSelected = _selectedChatId == c.id;
                          return Material(
                            color: isSelected
                                ? AppColorsDesktop.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () async {
                                await ensureChatDataLoaded(ref, c.id, refValid: () => mounted);
                                if (!mounted) return;
                                await ref.read(chatRepositoryProvider.notifier).markChatRead(c.id);
                                if (!mounted) return;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  setState(() => _selectedChatId = c.id);
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.2),
                                      child: Text(
                                        (c.isSupportChat
                                                ? 'П'
                                                : (c.clientName.isNotEmpty ? c.clientName[0] : '?'))
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColorsDesktop.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            c.isSupportChat
                                                ? 'Поддержка AutoHub'
                                                : (c.clientName.isNotEmpty ? c.clientName : 'Клиент'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppColorsDesktop.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.isSupportChat ? 'Служба поддержки' : c.orderNumber,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColorsDesktop.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.lastMessageText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColorsDesktop.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatTime(c.lastMessageAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColorsDesktop.textTertiary,
                                          ),
                                        ),
                                        if (c.unreadCount > 0)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColorsDesktop.primary,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${c.unreadCount}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _selectedChatId == null
                  ? Container(
                      color: AppColorsDesktop.background,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 64,
                              color: AppColorsDesktop.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Выберите диалог',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColorsDesktop.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ChatDetailScreen(
                      chatId: _selectedChatId!,
                      embeddedInSplit: true,
                    ),
            ),
          ],
        ),
      ),
    ],
  ),
);
    }

    // Мобильный вид: только список, без дублирования заголовка «Чаты»
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Чаты'),
            if (totalUnreadAllChats > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  totalUnreadAllChats > 99 ? '99+' : '$totalUnreadAllChats',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D0D0D),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ordersLoadErr != null)
            ApiFailureBanner(
              message: 'Заказы: $ordersLoadErr',
              dense: true,
              onRetry: retryApi,
            ),
          Expanded(
            child: chats.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        ordersLoadErr != null
                            ? 'Чаты по заказам могут не отображаться, пока не загрузятся заказы.'
                            : 'Нет чатов',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final c = chats[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                      child: Text(
                        (c.isSupportChat
                                ? 'П'
                                : (c.clientName.isNotEmpty ? c.clientName[0] : '?'))
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      c.isSupportChat
                          ? 'Поддержка AutoHub'
                          : (c.clientName.isNotEmpty ? c.clientName : 'Клиент'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.isSupportChat ? 'Служба поддержки' : c.orderNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (c.lastMessageText.isNotEmpty)
                          Text(
                            c.lastMessageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(c.lastMessageAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (c.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${c.unreadCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0D0D0D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () async {
                      await ensureChatDataLoaded(ref, c.id, refValid: () => context.mounted);
                      if (!context.mounted) return;
                      await ref.read(chatRepositoryProvider.notifier).markChatRead(c.id);
                      if (!context.mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(chatId: c.id),
                          ),
                        );
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
