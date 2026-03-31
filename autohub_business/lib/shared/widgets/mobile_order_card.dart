import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../models/organization_business_kind.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';

/// Группировка заказов по календарным дням (как на вкладке «Заказы»).
List<MapEntry<DateTime, List<Order>>> groupOrdersByCalendarDay(
  List<Order> orders, {
  required bool historyMode,
}) {
  final map = <DateTime, List<Order>>{};
  for (final o in orders) {
    final d = o.effectiveDateTime;
    final day = DateTime(d.year, d.month, d.day);
    map.putIfAbsent(day, () => []).add(o);
  }
  for (final list in map.values) {
    list.sort(
      (a, b) => historyMode
          ? b.effectiveDateTime.compareTo(a.effectiveDateTime)
          : a.effectiveDateTime.compareTo(b.effectiveDateTime),
    );
  }
  final keys = map.keys.toList()..sort();
  if (historyMode) {
    keys.sort((a, b) => b.compareTo(a));
  }
  return [for (final k in keys) MapEntry(k, map[k]!)];
}

/// Заголовок дня для мобильного списка заказов.
class MobileDayHeader extends StatelessWidget {
  const MobileDayHeader({super.key, required this.day, required this.isFirst});

  final DateTime day;
  final bool isFirst;

  static String labelForDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Сегодня · ${formatDateShort(date)}';
    if (d == tomorrow) return 'Завтра · ${formatDateShort(date)}';
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final wd = date.weekday - 1;
    return '${weekdays[wd]} · ${formatDateShort(date)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isFirst ? 0 : 14, bottom: 8),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.75)),
        ),
      ),
      child: Text(
        labelForDay(day),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _OrderMiniItemRow extends StatelessWidget {
  const _OrderMiniItemRow({required this.item, required this.canSeePrices});

  final OrderItem item;
  final bool canSeePrices;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: item.isCompleted ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canSeePrices && item.priceKopecks != null) ...[
            const SizedBox(width: 6),
            Text(
              formatMoney(item.priceKopecks!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: item.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Карточка заказа в мобильном списке (вкладка «Заказы», карточка клиента и т.п.).
class MobileOrderCard extends StatelessWidget {
  const MobileOrderCard({super.key, required this.order, required this.canSeePrices});

  final Order order;
  final bool canSeePrices;

  @override
  Widget build(BuildContext context) {
    final previewItems = order.itemsForDisplay.take(3).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      order.displayNumber,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.status.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: order.status.color.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        order.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: order.status.color,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              if (OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind).isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    OrganizationBusinessKindCodes.labelForOrderSnapshot(order.organizationBusinessKind),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary.withValues(alpha: 0.95)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.nestedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 18,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.carInfo.isNotEmpty ? order.carInfo : 'Автомобиль не указан',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (order.licensePlate != null && order.licensePlate!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                order.licensePlate!.trim(),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (previewItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final item in previewItems)
                  _OrderMiniItemRow(item: item, canSeePrices: canSeePrices),
                if (order.itemsForDisplay.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'и ещё ${order.itemsForDisplay.length - 3}…',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary.withValues(alpha: 0.95)),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDateTimeOrNull(order.dateTime),
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        if (order.masterName != null && order.masterName!.trim().isNotEmpty)
                          Text(
                            order.masterName!.trim(),
                            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (order.bayName != null && order.bayName!.trim().isNotEmpty)
                          Text(
                            'Пост: ${order.bayName!.trim()}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (canSeePrices && order.totalKopecksForDisplay > 0)
                    Text(
                      formatMoney(order.totalKopecksForDisplay),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
