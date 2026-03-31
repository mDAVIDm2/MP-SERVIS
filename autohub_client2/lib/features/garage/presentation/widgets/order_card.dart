import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';

/// Компактный чип состояния заказа: под строкой даты, аккуратный вид.
class _CompactStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isWarning;

  const _CompactStatusChip({
    required this.label,
    required this.color,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Компактная action-кнопка: тёмный фон, золотой бордер, золотая иконка (36–40 px).
Widget _buildActionButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bgCard2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.strokeGold.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 20, color: AppColors.gold1),
      ),
    ),
  );
}

class OrderCard extends ConsumerWidget {
  final Order order;
  final Car car;
  final VoidCallback? onReturnFromDetail;

  const OrderCard({
    super.key,
    required this.order,
    required this.car,
    this.onReturnFromDetail,
  });

  static Future<void> _openStoProfile(BuildContext context, WidgetRef ref, Order order) async {
    final repo = ref.read(stoRepositoryProvider);
    final result = await repo.getSTOById(order.stoId);
    if (!context.mounted) return;
    final sto = result.dataOrNull;
    if (sto != null) {
      pushCupertino(context, STODetailScreen(sto: sto));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить карточку сервиса'), backgroundColor: AppColors.warning),
      );
    }
  }

  static Future<void> _openPhone(BuildContext context, Order order) async {
    final phone = order.stoPhone;
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Номер не указан'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await launchUrl(Uri.parse('tel:$digits'), mode: LaunchMode.externalApplication);
  }

  static Future<void> _openRoute(BuildContext context, WidgetRef ref, Order order) async {
    final sto = await ref.read(stoByIdProvider(order.stoId).future);
    if (!context.mounted) return;
    if (sto != null && sto.latitude != null && sto.longitude != null) {
      await OrderDetailScreen.openRouteToSto(context, ref, sto);
    } else if (order.stoAddress != null && order.stoAddress!.isNotEmpty) {
      final encoded = Uri.encodeComponent(order.stoAddress!);
      final url = 'https://www.google.com/maps/search/?api=1&query=$encoded';
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Адрес не указан'), backgroundColor: AppColors.warning),
      );
    }
  }

  static String? _orderOrgKindLabel(Order order) {
    final code = order.organizationBusinessKind;
    if (code == null || code.isEmpty) return null;
    const labels = <String, String>{
      'sto': 'Автосервис',
      'car_wash': 'Мойка',
      'detailing': 'Детейлинг',
      'car_audio': 'Автозвук',
      'tire_service': 'Шиномонтаж',
      'body_shop': 'Кузовной',
      'glass': 'Стёкла',
      'tuning': 'Тюнинг',
      'ev_service': 'EV-сервис',
      'other': 'Сервис',
    };
    return labels[code] ?? code;
  }

  static (DateTime start, DateTime? end) _timeRange(Order order) {
    final start = order.plannedStartTime ?? order.dateTime;
    if (order.plannedEndTime != null) return (start, order.plannedEndTime);
    final end = start.add(Duration(minutes: order.estimatedMinutesForDisplay));
    return (start, end);
  }

  /// Две самые дорогие позиции + остальные одной строкой «+N позиций». [isCompleted] для кружка/галочки и перечёркивания.
  static List<({String name, int kopecks, bool isRest, bool? isCompleted})> _summaryRows(Order order) {
    if (order.itemsForDisplay.isEmpty) return [];
    final sorted = List<OrderItem>.from(order.itemsForDisplay)
      ..sort((a, b) => b.priceKopecks.compareTo(a.priceKopecks));
    final top2 = sorted.take(2).toList();
    final rest = sorted.skip(2).toList();
    final restSum = rest.fold<int>(0, (s, i) => s + i.priceKopecks);

    final rows = <({String name, int kopecks, bool isRest, bool? isCompleted})>[];
    for (final i in top2) {
      rows.add((name: i.name, kopecks: i.priceKopecks, isRest: false, isCompleted: i.isCompleted));
    }
    if (rest.isNotEmpty) {
      rows.add((name: '+${rest.length} позиций', kopecks: restSum, isRest: true, isCompleted: null));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (timeStart, timeEnd) = _timeRange(order);
    final dateStr = Formatters.dateShortRu(order.dateTime);
    final timeRangeStr = Formatters.timeRange(timeStart, timeEnd);
    final summaryRows = _summaryRows(order);
    const double spacing = 12;

    return GestureDetector(
      onTap: () async {
        await pushCupertino(context, OrderDetailScreen(order: order));
        onReturnFromDetail?.call();
      },
      child: Container(
        decoration: AppDesignSystem.orderCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Шапка: название сервиса + кнопки Позвонить / Маршрут
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                color: AppColors.bgCard2.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesignSystem.radiusOrderCard)),
                border: Border(bottom: BorderSide(color: AppColors.strokeSoft.withValues(alpha: 0.6), width: 1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openStoProfile(context, ref, order),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.stoName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_orderOrgKindLabel(order) != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.nestedBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                _orderOrgKindLabel(order)!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Позвонить',
                        child: _buildActionButton(
                          icon: Icons.phone_rounded,
                          tooltip: 'Позвонить',
                          onPressed: () => _openPhone(context, order),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Маршрут',
                        child: _buildActionButton(
                          icon: Icons.directions_rounded,
                          tooltip: 'Маршрут',
                          onPressed: () => _openRoute(context, ref, order),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Информация по заказу: иконка, номер заказа, авто, дата, состояние
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                      border: Border.all(color: AppColors.strokeSoft),
                    ),
                    child: Icon(
                      Icons.build_circle_rounded,
                      size: 40,
                      color: AppColors.gold2.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold1,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${car.brand} ${car.model} \'${car.year.toString().substring(car.year.toString().length - 2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$dateStr, $timeRangeStr',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Состояние заказа: компактный бейдж под строкой даты
                        _CompactStatusChip(
                          label: order.displayStatus.label,
                          color: order.status.color,
                          isWarning: order.status == OrderStatus.pendingApproval,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Состав заказа
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            if (order.itemsForDisplay.isNotEmpty) ...[
              const Text(
                'Состав заказа',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            // Строки состава: кружок/галочка, название (перечёркнуто если выполнено), цена справа
            if (summaryRows.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...summaryRows.map((row) {
                final completed = row.isCompleted == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: completed ? AppColors.success : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: row.isRest ? AppColors.textMuted : AppColors.textSecondary,
                            decoration: completed ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 72,
                        child: Text(
                          Formatters.money(row.kopecks),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            decoration: completed ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            if (order.status == OrderStatus.inProgress) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: order.itemsProgress,
                  minHeight: 3,
                  backgroundColor: AppColors.bgCard2,
                  valueColor: AlwaysStoppedAnimation(order.status.color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(order.itemsProgress * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],

            // Footer: Итого слева, сумма справа
            SizedBox(height: summaryRows.isNotEmpty ? 10 : 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Итого:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  Formatters.money(order.totalKopecksForDisplay),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
