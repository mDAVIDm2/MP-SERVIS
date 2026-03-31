import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../orders/presentation/screens/order_photos_screen.dart';
import '../../../orders/presentation/screens/order_extra_work_screen.dart';

/// Экран «Мои задачи» для роли Master: заказы, назначенные на текущего мастера; без цен и телефонов.
class MasterTasksScreen extends ConsumerWidget {
  const MasterTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myStaffId = ref.watch(currentMasterStaffIdProvider);
    final orders = ref.watch(orderRepositoryProvider);
    final myOrders = orders
        .where((o) => o.masterId == myStaffId && o.status.isActive)
        .toList()
      ..sort((a, b) => a.effectiveDateTime.compareTo(b.effectiveDateTime));

    final current = myOrders.isNotEmpty ? myOrders.first : null;
    final next = myOrders.length > 1 ? myOrders.sublist(1) : <Order>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Мои задачи'),
      ),
      body: myStaffId == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ваш профиль не найден в списке сотрудников.\nОбратитесь к администратору, чтобы вас добавили в персонал — тогда здесь появятся назначенные вам заказы.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : myOrders.isEmpty
              ? const Center(
                  child: Text(
                    'Нет назначенных задач',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Текущая задача',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _TaskCard(
                  order: current!,
                  onCompleteItem: (orderId, itemId) =>
                      ref.read(orderRepositoryProvider.notifier).completeOrderItem(orderId, itemId),
                ),
                const SizedBox(height: 24),
                if (next.isNotEmpty) ...[
                  const Text(
                    'Следующие',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...next.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(o.orderNumber),
                            subtitle: Text('${o.carInfo} • ${formatTimeOrNull(o.dateTime)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(orderId: o.id),
                              ),
                            ),
                          ),
                        ),
                      )),
                ],
              ],
            ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Order order;
  final Future<Result<void>> Function(String orderId, String itemId) onCompleteItem;

  const _TaskCard({required this.order, required this.onCompleteItem});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.status.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(fontSize: 12, color: order.status.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.carInfo,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            if (order.comment != null && order.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Комментарий клиента: ${order.comment}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Работы',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) {
              final canTap = !item.isCompleted && order.status.isActive;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: canTap
                      ? () async {
                          final result = await onCompleteItem(order.id, item.id);
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
                          size: 22,
                          color: item.isCompleted ? AppColors.success : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderPhotosScreen(orderId: order.id),
                    ),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  label: const Text('Фото'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderExtraWorkScreen(orderId: order.id),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Доп. работы'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(orderId: order.id),
                  ),
                ),
                child: const Text('Открыть заказ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
