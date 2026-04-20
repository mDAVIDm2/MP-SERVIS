import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/client_avatar_from_chats.dart';
import '../../core/repositories/chat_repository.dart';
import '../models/order_model.dart';
import '../../features/chats/presentation/widgets/authenticated_profile_avatar.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';

Widget _mobileListServiceDot(bool completed, {double size = 16}) {
  if (completed) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.success.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check_rounded, size: size * 0.56, color: AppColors.success),
    );
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.borderLight, width: 1.35),
      color: AppColors.nestedBg,
    ),
  );
}

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

class _CarMetaChips extends StatelessWidget {
  const _CarMetaChips({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    void add(String text) {
      if (text.trim().isEmpty) return;
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.nestedBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.2),
          ),
        ),
      );
    }

    final plate = order.licensePlate?.trim();
    if (plate != null && plate.isNotEmpty) add(plate);
    final vin = order.vin?.trim();
    if (vin != null && vin.isNotEmpty) add('VIN $vin');
    if (order.mileage != null) add('${order.mileage} км');
    if (order.bodyType != null && order.bodyType!.trim().isNotEmpty) add(order.bodyType!.trim());
    if (order.engineType != null && order.engineType!.trim().isNotEmpty) add(order.engineType!.trim());

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips,
      ),
    );
  }
}

/// Карточка заказа в мобильном списке.
class MobileOrderCard extends ConsumerWidget {
  const MobileOrderCard({super.key, required this.order, required this.canSeePrices});

  final Order order;
  final bool canSeePrices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatRepositoryProvider).chats;
    final avatarUrl = resolvedClientAvatarUrl(
      chats: chats,
      orderClientAvatarUrl: order.clientAvatarUrl,
      clientPhone: order.clientPhone,
    );
    final previewItems = order.itemsForDisplay.take(4).toList();
    final clientLabel = order.clientName?.trim();
    final phone = order.clientPhone?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.85)),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (clientLabel != null && clientLabel.isNotEmpty || phone != null && phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: AuthenticatedProfileAvatar(
                        imageUrl: avatarUrl,
                        fallbackLetter: (clientLabel != null && clientLabel.isNotEmpty)
                            ? clientLabel[0].toUpperCase()
                            : '?',
                        size: 44,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.displayNumber,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (clientLabel != null && clientLabel.isNotEmpty)
                          Text(
                            clientLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary.withValues(alpha: 0.92),
                            ),
                          )
                        else if (phone != null && phone.isNotEmpty)
                          Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: order.status.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: order.status.color,
                        height: 1.15,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                order.carInfo.isNotEmpty ? order.carInfo : 'Авто не указано',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              _CarMetaChips(order: order),
              if (previewItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...previewItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _mobileListServiceDot(item.isCompleted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: AppColors.textPrimary,
                              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.textSecondary,
                            ),
                            maxLines: 4,
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
                  ),
                ),
                if (order.itemsForDisplay.length > previewItems.length)
                  Text(
                    'ещё ${order.itemsForDisplay.length - previewItems.length}…',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary.withValues(alpha: 0.95)),
                  ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDateTimeOrNull(order.dateTime),
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                        if (order.masterName != null && order.masterName!.trim().isNotEmpty)
                          Text(
                            order.masterName!.trim(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
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
