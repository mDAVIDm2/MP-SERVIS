import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/pending_car_notification_payload.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.initialCarId});

  final String? initialCarId;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _filterCarId;

  @override
  void initState() {
    super.initState();
    _filterCarId = widget.initialCarId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).loadNotifications(carId: _filterCarId);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(unreadByCarProvider);
    });
  }

  List<NotificationItem> _items(AsyncValue<List<NotificationItem>> async) {
    return async.valueOrNull ?? [];
  }

  List<NotificationItem> _today(List<NotificationItem> items) => items.where((n) {
    final diff = DateTime.now().difference(n.time);
    return diff.inHours < 24;
  }).toList();

  List<NotificationItem> _yesterday(List<NotificationItem> items) => items.where((n) {
    final diff = DateTime.now().difference(n.time);
    return diff.inHours >= 24 && diff.inHours < 48;
  }).toList();

  List<NotificationItem> _earlier(List<NotificationItem> items) => items.where((n) {
    final diff = DateTime.now().difference(n.time);
    return diff.inHours >= 48;
  }).toList();

  Future<void> _markAllRead() async {
    await ref.read(notificationsProvider.notifier).markAllAsRead(carId: _filterCarId);
  }

  void _onFilterChanged(String? carId) {
    setState(() => _filterCarId = (carId == null || carId.isEmpty) ? null : carId);
    ref.read(notificationsProvider.notifier).loadNotifications(carId: _filterCarId);
  }

  Future<void> _onNotificationTap(NotificationItem item) async {
    await ref.read(notificationsProvider.notifier).markAsRead(item.id);
    if (!mounted) return;
    await _applyPendingCarDataFromNotification(item);

    switch (item.targetType) {
      case NotificationTarget.order:
        if (item.targetId != null) {
          final result = await ref.read(orderRepositoryProvider).getOrderById(item.targetId!);
          if (context.mounted && result.dataOrNull != null) {
            pushCupertino(context, OrderDetailScreen(order: result.dataOrNull!));
          }
        }
        break;

      case NotificationTarget.chat:
        if (item.targetId != null) {
          final result = await ref.read(chatRepositoryProvider).getChatById(item.targetId!);
          if (context.mounted && result.dataOrNull != null) {
            pushCupertino(context, ChatDetailScreen(chat: result.dataOrNull!));
          }
        }
        break;

      case NotificationTarget.garage:
        if (context.mounted) Navigator.pop(context);
        break;

      case NotificationTarget.profile:
        if (context.mounted) Navigator.pop(context);
        break;

      case NotificationTarget.none:
        break;
    }
  }

  /// Обновляет локальную карточку авто по payload (после подтверждения разработчиками / предложения из справочника).
  /// Вызывается и при тапе по карточке, и при нажатии «Прочитано» — иначе многие жмут только галочку и данные не применяются.
  Future<void> _applyPendingCarDataFromNotification(NotificationItem item) async {
    final cid = item.carId?.trim();
    if (cid == null || cid.isEmpty) return;

    final isApproved = item.type == NotificationType.pendingCarApproved;
    final isSuggested = item.type == NotificationType.pendingCarSuggested;
    if (!isApproved && !isSuggested) return;

    final p = PendingCarNotificationPayload.asStringKeyedMap(item.payload);
    if (p == null || p.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('В уведомлении нет данных для обновления авто. Попробуйте обновить список уведомлений.'),
            backgroundColor: AppColors.cardBg,
          ),
        );
      }
      return;
    }

    final parsed = PendingCarNotificationPayload.parse(p, isSuggested: isSuggested);
    if (parsed.brandId == null || parsed.modelId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('В уведомлении нет id марки/модели — авто не обновлено. Обратитесь в поддержку.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final brandName = parsed.brandName.isNotEmpty ? parsed.brandName : 'Авто';
    final modelName = parsed.modelName.isNotEmpty ? parsed.modelName : 'Модель';

    final res = await ref.read(carRepositoryProvider).updateCarReference(
      cid,
      brandId: parsed.brandId!,
      modelId: parsed.modelId!,
      generationId: parsed.genId ?? 0,
      brandName: brandName,
      modelName: modelName,
      generationName: parsed.genName.isNotEmpty ? parsed.genName : '',
    );

    if (!mounted) return;

    if (res.dataOrNull != null) {
      await ref.read(carsProvider.notifier).loadCars();
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(unreadByCarProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Данные авто обновлены: $brandName $modelName'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = res.errorOrNull?.message ?? 'Ошибка';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить авто: $err'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final items = _items(async);
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final carLabel = _filterCarId == null || _filterCarId!.isEmpty
        ? 'Все уведомления'
        : cars.where((c) => c.id == _filterCarId).map((c) => c.nickname ?? '${c.brand} ${c.model}').firstOrNull ?? 'Машина';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Уведомления', style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600,
        )),
        actions: [
          TextButton(
            onPressed: async.isLoading ? null : _markAllRead,
            child: const Text('Прочитать все', style: TextStyle(
              fontSize: 13, color: AppColors.primary,
            )),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _filterCarId,
                isExpanded: true,
                hint: const Text('Все машины'),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Все машины')),
                  ...cars.map((c) => DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(c.nickname ?? '${c.brand} ${c.model}', overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => _onFilterChanged(v ?? ''),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'По машине: $carLabel',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (_) => items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔔', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 16),
                        Text('Нет уведомлений', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
                        )),
                      ],
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      if (_today(items).isNotEmpty) ...[
                        const _GroupLabel('Сегодня'),
                        ..._today(items).map((n) => _NotificationCard(
                          item: n,
                          onTap: () => _onNotificationTap(n),
                          onMarkRead: () async {
                            await ref.read(notificationsProvider.notifier).markAsRead(n.id);
                            if (mounted) await _applyPendingCarDataFromNotification(n);
                          },
                          onDelete: () => _confirmDelete(n),
                        )),
                      ],
                      if (_yesterday(items).isNotEmpty) ...[
                        const _GroupLabel('Вчера'),
                        ..._yesterday(items).map((n) => _NotificationCard(
                          item: n,
                          onTap: () => _onNotificationTap(n),
                          onMarkRead: () async {
                            await ref.read(notificationsProvider.notifier).markAsRead(n.id);
                            if (mounted) await _applyPendingCarDataFromNotification(n);
                          },
                          onDelete: () => _confirmDelete(n),
                        )),
                      ],
                      if (_earlier(items).isNotEmpty) ...[
                        const _GroupLabel('Ранее'),
                        ..._earlier(items).map((n) => _NotificationCard(
                          item: n,
                          onTap: () => _onNotificationTap(n),
                          onMarkRead: () async {
                            await ref.read(notificationsProvider.notifier).markAsRead(n.id);
                            if (mounted) await _applyPendingCarDataFromNotification(n);
                          },
                          onDelete: () => _confirmDelete(n),
                        )),
                      ],
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(NotificationItem n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить уведомление?'),
        content: Text(n.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(notificationsProvider.notifier).deleteNotification(n.id);
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(unreadByCarProvider);
    }
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textTertiary,
      )),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  /// Может быть async (например, применение данных авто из уведомления).
  final Future<void> Function()? onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasTarget = item.targetType != NotificationTarget.none;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: item.isRead ? AppColors.background : AppColors.cardBg,
          border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TextStyle(
                    fontSize: 15,
                    fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary,
                  )),
                  if (!item.isRead && hasTarget) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.targetType == NotificationTarget.chat
                          ? 'Нажмите, чтобы перейти к согласованию →'
                          : 'Нажмите, чтобы посмотреть →',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!item.isRead)
                      IconButton(
                        icon: const Icon(Icons.done_outline, size: 20),
                        tooltip: 'Прочитано',
                        onPressed: onMarkRead == null ? null : () => onMarkRead!(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                      tooltip: 'Удалить уведомление',
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                Text(Formatters.chatTime(item.time), style: const TextStyle(
                  fontSize: 12, color: AppColors.textTertiary,
                )),
                if (!item.isRead) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
