import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../shared/models/order_model.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _lastCenteredCarId;

  @override
  Widget build(BuildContext context) {
    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCarIdProvider);
    if (cars.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Аналитика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        body: const Center(child: Text('Добавьте автомобиль в Гараж', style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    var carIndex = 0;
    if (selectedId != null) {
      final i = cars.indexWhere((c) => c.id == selectedId);
      if (i >= 0) carIndex = i;
    }
    final activeCarId = cars[carIndex].id;
    if (activeCarId != _lastCenteredCarId) {
      _lastCenteredCarId = activeCarId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        scrollWidgetToViewportCenter(GlobalObjectKey(activeCarId).currentContext);
      });
    }
    final car = cars[carIndex];
    final carOrders = orders.where((o) => o.carId == car.id).toList();
    final totalSpent = carOrders.fold(0, (sum, o) => sum + o.totalKopecks);
    final avgCheck = carOrders.isNotEmpty ? totalSpent ~/ carOrders.length : 0;
    final doneOrders = carOrders.where((o) => o.status == OrderStatus.done).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Аналитика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Car selector
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cars.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = cars[i];
                final isSelected = i == carIndex;
                return GestureDetector(
                  key: GlobalObjectKey(c.id),
                  onTap: () => ref.read(selectedCarIdProvider.notifier).set(c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text('${c.brand} ${c.model}', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF0D0D0D) : AppColors.textPrimary,
                    )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Основные метрики
          Row(
            children: [
              _MetricCard(label: 'Общие расходы', value: Formatters.money(totalSpent), icon: Icons.account_balance_wallet_rounded),
              const SizedBox(width: 8),
              _MetricCard(label: 'Средний чек', value: Formatters.money(avgCheck), icon: Icons.receipt_long_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetricCard(label: 'Всего заказов', value: '${carOrders.length}', icon: Icons.list_alt_rounded),
              const SizedBox(width: 8),
              _MetricCard(label: 'Завершено', value: '$doneOrders', icon: Icons.check_circle_outline_rounded),
            ],
          ),
          const SizedBox(height: 24),

          // График расходов по месяцам
          const Text('Расходы по месяцам', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          const SizedBox(height: 12),
          _buildBarChart(),
          const SizedBox(height: 24),

          // Категории расходов
          const Text('По категориям', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(carOrders),
          const SizedBox(height: 24),

          // История заказов
          const Text('История', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          const SizedBox(height: 12),
          ...carOrders.map((o) => _HistoryRow(order: o)),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
    final values = [0.2, 0.0, 0.45, 0.15, 0.6, 0.3, 0.0, 0.5, 1.0, 0.4, 0.7, 0.85];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (values[i] > 0)
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400 + i * 50),
                          height: 120 * values[i],
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.4)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              )),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: months.map((m) => Expanded(
              child: Text(m, style: const TextStyle(fontSize: 9, color: AppColors.textTertiary),
                textAlign: TextAlign.center),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(List<Order> orders) {
    final categories = <String, int>{};
    for (final o in orders) {
      for (final item in o.items.where((i) => i.isApproved)) {
        final cat = _categorize(item.name);
        categories[cat] = (categories[cat] ?? 0) + item.priceKopecks;
      }
    }
    final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(0, (sum, e) => sum + e.value);
    final colors = [AppColors.primary, AppColors.info, AppColors.success, AppColors.warning, AppColors.error];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: List.generate(sorted.length, (i) {
                  final pct = total > 0 ? sorted[i].value / total : 0.0;
                  return Expanded(
                    flex: (pct * 100).round().clamp(1, 100),
                    child: Container(color: colors[i % colors.length]),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(sorted.length, (i) {
            final pct = total > 0 ? (sorted[i].value / total * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(
                    color: colors[i % colors.length], borderRadius: BorderRadius.circular(3),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: Text(sorted[i].key, style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary,
                  ))),
                  Text('$pct%', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  Text(Formatters.money(sorted[i].value), style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                  )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _categorize(String name) {
    final n = name.toLowerCase();
    if (n.contains('масл') || n.contains('фильтр') || n.contains('антифриз')) return 'ТО и расходники';
    if (n.contains('тормоз') || n.contains('колод') || n.contains('диск')) return 'Тормозная система';
    if (n.contains('диагн')) return 'Диагностика';
    if (n.contains('кондиц') || n.contains('фреон')) return 'Климат';
    return 'Прочее';
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'monospace',
            )),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Order order;
  const _HistoryRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: order.status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.stoName, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
                )),
                Text(order.items.map((i) => i.name).join(', '), style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.money(order.totalKopecks), style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
              )),
              Text(Formatters.dateShortRu(order.dateTime), style: const TextStyle(
                fontSize: 12, color: AppColors.textTertiary,
              )),
            ],
          ),
        ],
      ),
    );
  }
}
