import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import 'create_order_screen.dart';

enum _CalendarView { day, week }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  _CalendarView _view = _CalendarView.day;

  static DateTime _weekStart(DateTime d) {
    final wday = d.weekday - 1;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: wday));
  }

  static List<Order> _ordersForDate(List<Order> orders, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return orders
        .where((o) =>
            o.effectiveDateTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
            o.effectiveDateTime.isBefore(end))
        .toList()
      ..sort((a, b) => a.effectiveDateTime.compareTo(b.effectiveDateTime));
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderRepositoryProvider);
    final weekStart = _weekStart(_selectedDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _view == _CalendarView.day
              ? 'Календарь • ${formatDate(_selectedDate)}'
              : 'Неделя ${formatDate(weekStart)} – ${formatDate(weekDays.last)}',
        ),
        actions: [
          SegmentedButton<_CalendarView>(
            segments: const [
              ButtonSegment(value: _CalendarView.day, label: Text('День')),
              ButtonSegment(value: _CalendarView.week, label: Text('Неделя')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && mounted) setState(() => _selectedDate = picked);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_view == _CalendarView.day) _buildDayNav(),
          if (_view == _CalendarView.week) _buildWeekStrip(weekDays, orders),
          const SizedBox(height: 8),
          Expanded(
            child: _view == _CalendarView.day
                ? _buildDayList(orders, _selectedDate)
                : _buildWeekList(orders, weekDays),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateOrderScreen(initialDate: _selectedDate),
          ),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDayNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                formatDate(_selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(List<DateTime> weekDays, List<Order> orders) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: weekDays.map((d) {
          final isSelected = d.year == _selectedDate.year &&
              d.month == _selectedDate.month &&
              d.day == _selectedDate.day;
          final count = _ordersForDate(orders, d).length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: isSelected ? AppColors.primary : AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDate = d),
                child: Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dayName(d.weekday),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? const Color(0xFF0D0D0D) : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFF0D0D0D) : AppColors.textPrimary,
                        ),
                      ),
                      if (count > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0D0D0D).withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFF0D0D0D) : AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _dayName(int weekday) {
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return names[weekday - 1];
  }

  Widget _buildDayList(List<Order> orders, DateTime date) {
    final ordersOnDay = _ordersForDate(orders, date);
    if (ordersOnDay.isEmpty) {
      return const Center(
        child: Text(
          'Нет записей на этот день',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: ordersOnDay.map((o) => _orderCard(o)).toList(),
    );
  }

  Widget _buildWeekList(List<Order> orders, List<DateTime> weekDays) {
    final ordersOnSelected = _ordersForDate(orders, _selectedDate);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Text(
          formatDate(_selectedDate),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (ordersOnSelected.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Нет записей',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...ordersOnSelected.map((o) => _orderCard(o)),
      ],
    );
  }

  Widget _orderCard(Order o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(
          formatTimeOrNull(o.dateTime),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text(o.orderNumber),
        subtitle: Text(o.carInfo),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: o.status.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            o.status.label,
            style: TextStyle(fontSize: 12, color: o.status.color),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: o.id),
          ),
        ),
      ),
    );
  }

}
