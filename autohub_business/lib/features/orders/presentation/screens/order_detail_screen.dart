import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/pdf/order_worksheet_pdf.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/organization_business_kind.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/api/services/api_services_providers.dart';
import 'master_picker_screen.dart';
import 'order_payment_screen.dart';
import 'confirm_correct_order_screen.dart';
import '../../../chats/presentation/screens/chat_detail_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Всегда обновляем заказ при открытии экрана (актуальные items после подтверждения согласования и т.д.).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderRepositoryProvider.notifier).refreshOrder(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId));
    final canSeePrices = ref.watch(authProvider).user?.role.canSeePrices ?? true;
    final canAssignMaster = ref.watch(authProvider).user?.role.canAssignMaster ?? false;

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Заказ')),
        body: const Center(
          child: Text('Заказ не найден', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.displayNumber,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: order.status.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                order.status.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: order.status.color,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Заказ-наряд (PDF)',
            onPressed: () => printOrderWorksheet(context, order, showPrices: canSeePrices),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (order.clientName != null)
            _Section(
              title: 'Клиент',
              child: Text(
                order.clientName!,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ),
          if (order.clientPhone != null)
            _Section(
              title: 'Телефон',
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      order.clientPhone!,
                      style: const TextStyle(fontSize: 16, color: AppColors.primary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                    onPressed: () {
                      final uri = Uri(scheme: 'tel', path: order.clientPhone!.replaceAll(RegExp(r'[^\d+]'), ''));
                      launchUrl(uri);
                    },
                  ),
                ],
              ),
            ),
          _Section(
            title: 'Автомобиль',
            child: Text(
              order.carInfo,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ),
          _Section(
            title: 'Дата и время',
            child: Text(
              formatDateTimeOrNull(order.dateTime),
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ),
          if (OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty ||
              OrganizationBusinessKindCodes.schedulingModeShortLabel(order.organizationSchedulingMode).isNotEmpty)
            _Section(
              title: 'Точка',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty)
                    Text(
                      OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind),
                      style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
                    ),
                  if (OrganizationBusinessKindCodes.schedulingModeShortLabel(order.organizationSchedulingMode).isNotEmpty) ...[
                    if (OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty)
                      const SizedBox(height: 6),
                    Text(
                      'Запись: ${OrganizationBusinessKindCodes.schedulingModeShortLabel(order.organizationSchedulingMode)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          if (canAssignMaster && order.status.isActive) ...[
            _Section(
              title: 'Плановое время (бронь С — По)',
              child: _PlannedTimeBlock(
                orderId: widget.orderId,
                order: order,
                onEditTime: (start, end) => _showEditDialog(context, ref, widget.orderId, start, end),
              ),
            ),
          ],
          _Section(
            title: order.itemsForDisplay.any((i) => i.isAdditional) ? 'Основное' : 'Услуги',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: order.itemsForDisplay
                  .where((item) => !item.isAdditional)
                  .map<Widget>((item) => _buildOrderItemTile(context, order, item, canSeePrices))
                  .toList(),
            ),
          ),
          if (order.itemsForDisplay.any((i) => i.isAdditional)) ...[
            _Section(
              title: 'Добавлено после согласования',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: order.itemsForDisplay
                    .where((item) => item.isAdditional)
                    .map<Widget>((item) => _buildOrderItemTile(context, order, item, canSeePrices))
                    .toList(),
              ),
            ),
          ],
          if (canSeePrices && order.totalKopecksForDisplay > 0)
            _Section(
              title: 'Итого',
              child: Text(
                formatMoney(order.totalKopecksForDisplay),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (order.comment != null && order.comment!.isNotEmpty)
            _Section(
              title: 'Комментарий',
              child: Text(
                order.comment!,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          if (canAssignMaster && order.status.isActive)
            _Section(
              title: 'Мастер',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      order.masterName ?? 'Не назначен',
                      style: TextStyle(
                        fontSize: 16,
                        color: order.masterName == null ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (order.masterId != null && order.masterId!.isNotEmpty) ...[
                    IconButton(
                      tooltip: 'Сменить мастера',
                      icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(builder: (_) => MasterPickerScreen(orderId: widget.orderId)),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Снять мастера',
                      icon: const Icon(Icons.close_rounded, color: AppColors.error),
                      onPressed: () async {
                        final repo = ref.read(orderRepositoryProvider.notifier);
                        final r = await repo.clearMaster(widget.orderId);
                        if (!context.mounted) return;
                        if (r.errorOrNull != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(r.errorOrNull!.message), backgroundColor: AppColors.error),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Мастер снят с заказа')),
                          );
                        }
                      },
                    ),
                  ] else
                    IconButton(
                      tooltip: 'Назначить мастера',
                      icon: const Icon(Icons.person_add_rounded, color: AppColors.primary),
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(builder: (_) => MasterPickerScreen(orderId: widget.orderId)),
                        );
                      },
                    ),
                ],
              ),
            )
          else if (order.masterName != null)
            _Section(
              title: 'Мастер',
              child: Text(
                order.masterName!,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ),
          if (ref.watch(settingsRepositoryProvider).slotsSettings.hasNamedBays)
            _Section(
              title: 'Пост',
              child: Text(
                order.bayName != null && order.bayName!.trim().isNotEmpty
                    ? order.bayName!.trim()
                    : (order.bayId != null && order.bayId!.trim().isNotEmpty
                        ? order.bayId!.trim()
                        : 'Не назначен'),
                style: TextStyle(
                  fontSize: 16,
                  color: (order.bayId == null || order.bayId!.isEmpty) ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
            ),
          const SizedBox(height: 24),
          _Actions(
            orderId: widget.orderId,
            order: order,
            canAssignMaster: canAssignMaster,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemTile(BuildContext context, Order order, OrderItem item, bool canSeePrices) {
    final canTap = order.status.isActive && order.status != OrderStatus.pendingApproval;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: canTap
            ? () async {
                final notifier = ref.read(orderRepositoryProvider.notifier);
                final result = item.isCompleted
                    ? await notifier.uncompleteOrderItem(order.id, item.id)
                    : await notifier.completeOrderItem(order.id, item.id);
                if (!context.mounted) return;
                if (result.errorOrNull != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.errorOrNull!.message), backgroundColor: AppColors.cardBg),
                  );
                }
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: item.isCompleted ? AppColors.success : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (canSeePrices && item.priceKopecks != null)
                Text(
                  formatMoney(item.priceKopecks!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                item.durationLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, String orderId, DateTime initialStart, DateTime initialEnd) async {
    final baseDate = DateTime(initialStart.year, initialStart.month, initialStart.day);
    var start = DateTime(baseDate.year, baseDate.month, baseDate.day, initialStart.hour, initialStart.minute);
    var end = DateTime(baseDate.year, baseDate.month, baseDate.day, initialEnd.hour, initialEnd.minute);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Плановое время'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Начало'),
                  trailing: Text(formatTime(start)),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: start.hour, minute: start.minute));
                    if (t != null) setState(() => start = DateTime(baseDate.year, baseDate.month, baseDate.day, t.hour, t.minute));
                  },
                ),
                ListTile(
                  title: const Text('Окончание'),
                  trailing: Text(formatTime(end)),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: end.hour, minute: end.minute));
                    if (t != null) setState(() => end = DateTime(baseDate.year, baseDate.month, baseDate.day, t.hour, t.minute));
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(
                onPressed: () {
                  if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Окончание должно быть позже начала')));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );
    if (result != true || !context.mounted) return;
    start = DateTime(baseDate.year, baseDate.month, baseDate.day, start.hour, start.minute);
    end = DateTime(baseDate.year, baseDate.month, baseDate.day, end.hour, end.minute);
    final res = await ref.read(orderRepositoryProvider.notifier).updateOrderTime(orderId, plannedStartTime: start, plannedEndTime: end);
    if (!context.mounted) return;
    res.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Время обновлено'))),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error)),
    );
  }
}

/// Блок планового времени с кнопкой «Изменить» (вызов PATCH /orders/:id/time).
class _PlannedTimeBlock extends StatelessWidget {
  final String orderId;
  final Order order;
  final void Function(DateTime start, DateTime end)? onEditTime;

  const _PlannedTimeBlock({required this.orderId, required this.order, this.onEditTime});

  @override
  Widget build(BuildContext context) {
    final startRaw = order.plannedStartTime ?? order.effectiveDateTime;
    final endRaw = order.plannedEndTime ?? order.effectiveDateTime.add(Duration(minutes: order.items.fold<int>(0, (s, i) => s + i.estimatedMinutes)));
    final start = startRaw.isUtc ? startRaw.toLocal() : startRaw;
    final end = endRaw.isUtc ? endRaw.toLocal() : endRaw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('С ${formatTime(start)}', style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('По ${formatTime(end)}', style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onEditTime != null ? () => onEditTime!(start, end) : null,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Изменить'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  final String orderId;
  final Order order;
  final bool canAssignMaster;

  const _Actions({
    required this.orderId,
    required this.order,
    required this.canAssignMaster,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(orderRepositoryProvider.notifier);

    void showMessage(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.cardBg),
      );
    }

    Future<void> setStatus(OrderStatus status, String successMsg) async {
      final result = await repo.setOrderStatus(orderId, status);
      if (!context.mounted) return;
      if (result.errorOrNull == null) {
        showMessage(successMsg);
      } else {
        showMessage(result.errorOrNull!.message);
      }
    }

    Future<void> cancel() async {
      final result = await repo.cancelOrder(orderId);
      if (!context.mounted) return;
      if (result.errorOrNull == null) {
        showMessage('Заказ отменён');
        Navigator.pop(context);
      } else {
        showMessage(result.errorOrNull!.message);
      }
    }

    final canChangeComposition = order.status != OrderStatus.done && order.status != OrderStatus.cancelled;

    /// На мобильном — переход на полный экран (состав, правка услуг, время). Без диалога.
    Future<void> openComposeOverlay() async {
      final orderApi = ref.read(orderApiServiceProvider);
      final chatResult = await orderApi.getChatForOrder(orderId);
      if (!context.mounted) return;
      final chatId = chatResult.dataOrNull;
      if (chatId == null || chatId.isEmpty) {
        showMessage(chatResult.errorOrNull?.message ?? 'Чат по заказу не найден');
        return;
      }
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmCorrectOrderScreen(
            orderId: orderId,
            chatId: chatId,
          ),
        ),
      );
      if (context.mounted) ref.read(orderRepositoryProvider.notifier).refreshOrder(orderId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Одна кнопка «Изменить состав»: для ожидания подтверждения и «Подтверждён» ниже свои кнопки — не дублируем.
        if (canChangeComposition &&
            order.status != OrderStatus.pendingConfirmation &&
            order.status != OrderStatus.confirmed) ...[
          OutlinedButton.icon(
            onPressed: () async {
              await openComposeOverlay();
              if (context.mounted) showMessage('Перечень работ отправлен клиенту');
            },
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Изменить состав заказа'),
          ),
          const SizedBox(height: 8),
        ],
        if (order.status.isActive) ...[
          OutlinedButton.icon(
            onPressed: () async {
              final orderApi = ref.read(orderApiServiceProvider);
              final chatResult = await orderApi.getChatForOrder(orderId);
              if (!context.mounted) return;
              final chatId = chatResult.dataOrNull;
              if (chatId == null || chatId.isEmpty) {
                showMessage(chatResult.errorOrNull?.message ?? 'Чат по заказу не найден');
                return;
              }
              await ensureChatDataLoaded(ref, chatId, refValid: () => context.mounted);
              if (!context.mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(chatId: chatId, currentOrderId: orderId),
                  ),
                );
              });
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            label: const Text('Открыть чат'),
          ),
          const SizedBox(height: 8),
        ],
        if (order.status == OrderStatus.pendingConfirmation) ...[
          ElevatedButton(
            onPressed: () async {
              await openComposeOverlay();
              if (context.mounted) showMessage('Перечень работ отправлен клиенту');
            },
            child: const Text('Изменить состав заказа'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setStatus(OrderStatus.confirmed, 'Заказ подтверждён без изменений'),
            child: const Text('Подтвердить без изменений'),
          ),
        ],
        if (order.status == OrderStatus.confirmed && canAssignMaster) ...[
          OutlinedButton(
            onPressed: () async {
              await openComposeOverlay();
              if (context.mounted) showMessage('Перечень работ отправлен клиенту на согласование');
            },
            child: const Text('Изменить состав заказа'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => MasterPickerScreen(orderId: orderId),
                ),
              );
              if (updated == true && context.mounted) {}
            },
            child: const Text('Назначить мастера'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => setStatus(OrderStatus.inProgress, 'Статус: В работе'),
            child: const Text('В работу'),
          ),
        ],
        if (order.status == OrderStatus.inProgress) ...[
          ElevatedButton(
            onPressed: () => setStatus(OrderStatus.completed, 'Готово к выдаче'),
            child: const Text('Завершить работы'),
          ),
        ],
        if (order.status == OrderStatus.pendingApproval) ...[
          ElevatedButton(
            onPressed: () async {
              final result = await repo.confirmOrderByPhone(orderId);
              if (!context.mounted) return;
              if (result.errorOrNull == null) {
                await ref.read(orderRepositoryProvider.notifier).refreshOrder(orderId);
                if (!context.mounted) return;
                showMessage('Подтверждено по телефону');
              } else {
                showMessage(result.errorOrNull!.message);
              }
            },
            child: const Text('Подтвердить по телефону'),
          ),
        ],
        if (order.status == OrderStatus.completed) ...[
          ElevatedButton(
            onPressed: () async {
              final closed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderPaymentScreen(orderId: orderId),
                ),
              );
              if (closed == true && context.mounted) Navigator.pop(context);
            },
            child: const Text('Оплата / Выдать заказ'),
          ),
        ],
        if (order.status.isActive) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Отменить заказ?'),
                  content: const Text('Заказ будет отменён. Эту операцию нельзя отменить.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Нет'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Отменить заказ'),
                    ),
                  ],
                ),
              );
              if (confirm == true) await cancel();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            child: const Text('Отменить заказ'),
          ),
        ],
        if (order.status == OrderStatus.cancelled ||
            order.status == OrderStatus.done ||
            order.status == OrderStatus.completed) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Скрыть заказ?'),
                  content: const Text(
                    'Заказ исчезнет из списков, расписания и чатов. В БД сохранится с пометкой «удалён». Вы больше не будете его видеть.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      child: const Text('Скрыть'),
                    ),
                  ],
                ),
              );
              if (confirm != true || !context.mounted) return;
              final result = await repo.hideOrderFromUser(orderId);
              if (!context.mounted) return;
              result.when(
                success: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заказ скрыт из списка')),
                  );
                  Navigator.pop(context);
                },
                failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.visibility_off_rounded, size: 20),
            label: const Text('Скрыть из списка'),
          ),
        ],
      ],
    );
  }
}
