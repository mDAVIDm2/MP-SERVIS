import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/models/staff_model.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

String _dashboardFormatOccupiedMinutes(int m) {
  if (m <= 0) return '0 мин';
  final h = m ~/ 60;
  final min = m % 60;
  if (h == 0) return '$min мин';
  if (min == 0) return '$h ч';
  return '$h ч $min мин';
}

/// Период отображения данных на панели владельца.
enum DashboardPeriod {
  today,
  yesterday,
  tomorrow,
  dayAfterTomorrow,
  week,
  month,
  custom,
}

enum _AttentionSeverity { warning, error, info, success }

class _AttentionItem {
  const _AttentionItem(this.label, this.count, this.severity, this.tabIndex);
  final String label;
  final int count;
  final _AttentionSeverity severity;
  final int? tabIndex;
}

/// Расширенная аналитика по мастеру за выбранный период.
class _MasterStats {
  final String masterId;
  final String masterName;
  final String? roleLabel;
  final int orderCount;
  final int completedCount;
  final int inProgressCount;
  final int pendingApprovalCount;
  final int cancelledCount;
  final int revenueKopecks;
  final int expectedRevenueKopecks;
  final int additionalKopecks;
  final int occupiedMinutes;

  _MasterStats({
    required this.masterId,
    required this.masterName,
    this.roleLabel,
    required this.orderCount,
    required this.completedCount,
    required this.inProgressCount,
    required this.pendingApprovalCount,
    required this.cancelledCount,
    required this.revenueKopecks,
    required this.expectedRevenueKopecks,
    required this.additionalKopecks,
    required this.occupiedMinutes,
  });

  static const int workingDayMinutes = 8 * 60;

  double get loadPercent => workingDayMinutes > 0
      ? (occupiedMinutes / workingDayMinutes * 100).clamp(0.0, 150.0)
      : 0.0;

  int get avgCheckKopecks => completedCount > 0 ? revenueKopecks ~/ completedCount : 0;

  int get additionalSharePercent => revenueKopecks > 0 && additionalKopecks > 0
      ? ((additionalKopecks / revenueKopecks) * 100).round()
      : 0;

  bool get isUnassigned => masterId.isEmpty;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

enum _MasterSort { byRevenue, byLoad, byOrders }

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.today;
  String? _selectedMasterId;
  _MasterSort _masterSort = _MasterSort.byRevenue;
  /// Мобильная главная: скрыть мастеров без заказов в выбранном периоде (список + график).
  bool _mobileMastersOnlyWithLoad = false;

  static (DateTime start, DateTime end) _rangeFor(DashboardPeriod period) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (period) {
      case DashboardPeriod.today:
        return (todayStart, todayStart.add(const Duration(days: 1)));
      case DashboardPeriod.yesterday:
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        return (yesterdayStart, todayStart);
      case DashboardPeriod.tomorrow:
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        return (tomorrowStart, tomorrowStart.add(const Duration(days: 1)));
      case DashboardPeriod.dayAfterTomorrow:
        final dayAfterTomorrowStart = todayStart.add(const Duration(days: 2));
        return (
          dayAfterTomorrowStart,
          dayAfterTomorrowStart.add(const Duration(days: 1)),
        );
      case DashboardPeriod.week:
        final weekStart = todayStart.subtract(const Duration(days: 6));
        return (weekStart, todayStart.add(const Duration(days: 1)));
      case DashboardPeriod.month:
        final monthStart = todayStart.subtract(const Duration(days: 29));
        return (monthStart, todayStart.add(const Duration(days: 1)));
      case DashboardPeriod.custom:
        return (todayStart, todayStart.add(const Duration(days: 1)));
    }
  }

  static List<Order> _ordersInRange(List<Order> orders, DateTime start, DateTime end) {
    final list = orders
        .where((o) =>
            !o.effectiveDateTime.isBefore(start) && o.effectiveDateTime.isBefore(end))
        .toList();
    list.sort((a, b) => a.effectiveDateTime.compareTo(b.effectiveDateTime));
    return list;
  }

  static List<Order> _attentionOrdersFromList(List<Order> orders) {
    return orders
        .where((o) =>
            o.status == OrderStatus.pendingConfirmation ||
            o.status == OrderStatus.pendingApproval)
        .toList();
  }

  /// Элементы блока «Требуют внимания»: подпись, количество, критичность, таб для перехода.
  static List<_AttentionItem> _buildAttentionItems(List<Order> allOrders, List<Order> rangeOrders) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayOrders = allOrders
        .where((o) => !o.effectiveDateTime.isBefore(todayStart) && o.effectiveDateTime.isBefore(todayEnd))
        .toList();

    final noMaster = todayOrders
        .where((o) =>
            (o.masterId == null || o.masterId!.isEmpty) &&
            o.status != OrderStatus.done &&
            o.status != OrderStatus.cancelled)
        .length;
    final needApproval = todayOrders.where((o) => o.status == OrderStatus.pendingApproval).length;
    final needConfirmation = todayOrders.where((o) => o.status == OrderStatus.pendingConfirmation).length;
    final cancelledCount = rangeOrders.where((o) => o.status == OrderStatus.cancelled).length;

    final items = <_AttentionItem>[];
    if (cancelledCount > 0) {
      items.add(_AttentionItem('Отменено за период', cancelledCount, _AttentionSeverity.info, 2));
    }
    if (noMaster > 0) {
      items.add(_AttentionItem('Без мастера', noMaster, _AttentionSeverity.warning, 2));
    }
    if (needApproval > 0) {
      items.add(_AttentionItem('Требуют согласования', needApproval, _AttentionSeverity.warning, 2));
    }
    if (needConfirmation > 0) {
      items.add(_AttentionItem('Не подтверждены', needConfirmation, _AttentionSeverity.warning, 2));
    }
    if (items.isEmpty) {
      items.add(_AttentionItem('Всё в порядке', 0, _AttentionSeverity.success, null));
    }
    return items;
  }

  /// Подпись периода для карточек.
  static String _periodLabel(DashboardPeriod p) {
    switch (p) {
      case DashboardPeriod.today:
        return 'сегодня';
      case DashboardPeriod.yesterday:
        return 'вчера';
      case DashboardPeriod.tomorrow:
        return 'завтра';
      case DashboardPeriod.dayAfterTomorrow:
        return 'послезавтра';
      case DashboardPeriod.week:
        return 'за неделю';
      case DashboardPeriod.month:
        return 'за месяц';
      case DashboardPeriod.custom:
        return 'за период';
    }
  }

  void _showRevenueBreakdown(BuildContext context, List<_MasterStats> byMaster, int totalKopecks) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColorsDesktop.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Выручка по мастерам', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Итого: ${formatMoney(totalKopecks)}', style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600, color: AppColorsDesktop.accentMoney)),
              const SizedBox(height: 16),
              if (byMaster.isEmpty)
                Text('Нет данных за период', style: DesktopDesignSystem.bodySecondary)
              else
                ...byMaster.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(m.masterName, style: DesktopDesignSystem.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(formatMoney(m.revenueKopecks), style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton(
                    onPressed: () { Navigator.pop(ctx); context.go('/app?tab=6'); },
                    style: FilledButton.styleFrom(backgroundColor: AppColorsDesktop.primary),
                    child: const Text('Финансы'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () { Navigator.pop(ctx); context.go('/app?tab=2'); },
                    child: const Text('Заказы'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpectedBreakdown(BuildContext context, List<Order> rangeOrders) {
    final active = rangeOrders.where((o) => o.status != OrderStatus.done && o.status != OrderStatus.cancelled && o.status != OrderStatus.completed).toList();
    final byConfirmed = active.where((o) => o.status == OrderStatus.confirmed).fold<int>(0, (s, o) => s + o.totalKopecks);
    final byInProgress = active.where((o) => o.status == OrderStatus.inProgress).fold<int>(0, (s, o) => s + o.totalKopecks);
    final byApproval = active.where((o) => o.status == OrderStatus.pendingApproval).fold<int>(0, (s, o) => s + o.totalKopecks);
    final byPending = active.where((o) => o.status == OrderStatus.pendingConfirmation).fold<int>(0, (s, o) => s + o.totalKopecks);
    final noMaster = active.where((o) => o.masterId == null || o.masterId!.isEmpty).fold<int>(0, (s, o) => s + o.totalKopecks);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColorsDesktop.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ожидаемая выручка', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              _BreakdownRow('Подтверждённые', formatMoney(byConfirmed)),
              _BreakdownRow('В работе', formatMoney(byInProgress)),
              _BreakdownRow('Требуют согласования', formatMoney(byApproval)),
              _BreakdownRow('Ожидают подтверждения', formatMoney(byPending)),
              _BreakdownRow('Без мастера', formatMoney(noMaster)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () { Navigator.pop(ctx); context.go('/app?tab=2'); },
                child: const Text('Открыть заказы'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvgCheckBreakdown(BuildContext context, List<_MasterStats> byMaster, int avgCheck, int completedCount) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColorsDesktop.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Средний чек', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text('$completedCount заказов в расчёте', style: DesktopDesignSystem.meta),
              const SizedBox(height: 12),
              Text(formatMoney(avgCheck), style: DesktopDesignSystem.pageTitle.copyWith(color: AppColorsDesktop.accentMoney)),
              if (byMaster.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('По мастерам', style: DesktopDesignSystem.label),
                const SizedBox(height: 8),
                ...byMaster.map((m) {
                  final cnt = m.orderCount;
                  final avg = cnt > 0 ? m.revenueKopecks ~/ cnt : 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(m.masterName, style: DesktopDesignSystem.bodySecondary, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(formatMoney(avg), style: DesktopDesignSystem.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () { Navigator.pop(ctx); context.go('/app?tab=6'); },
                child: const Text('Финансы'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttentionBreakdown(BuildContext context, List<_AttentionItem> items) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColorsDesktop.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Требуют внимания', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              ...items.where((i) => i.count > 0).map((i) => ListTile(
                title: Text(i.label, style: DesktopDesignSystem.body),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${i.count}', style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
                onTap: () { Navigator.pop(ctx); context.go('/app?tab=2'); },
              )),
              if (items.every((i) => i.count == 0))
                Text('Всё в порядке', style: DesktopDesignSystem.bodySecondary),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () { Navigator.pop(ctx); context.go('/app?tab=2'); },
                child: const Text('Открыть заказы'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Диапазон предыдущего периода для тренда.
  static (DateTime start, DateTime end) _previousRangeFor(DashboardPeriod period) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (period) {
      case DashboardPeriod.today:
        final yStart = todayStart.subtract(const Duration(days: 1));
        return (yStart, todayStart);
      case DashboardPeriod.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 2));
        return (yStart, todayStart.subtract(const Duration(days: 1)));
      case DashboardPeriod.tomorrow:
        return (todayStart, todayStart.add(const Duration(days: 1)));
      case DashboardPeriod.dayAfterTomorrow:
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        return (tomorrowStart, tomorrowStart.add(const Duration(days: 1)));
      case DashboardPeriod.week:
        final weekStart = todayStart.subtract(const Duration(days: 13));
        return (weekStart, todayStart.subtract(const Duration(days: 6)));
      case DashboardPeriod.month:
        final monthStart = todayStart.subtract(const Duration(days: 59));
        return (monthStart, todayStart.subtract(const Duration(days: 29)));
      case DashboardPeriod.custom:
        return (todayStart, todayStart.add(const Duration(days: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopPlatform;
    if (isDesktop) {
      return _buildDesktopPanel(context);
    }
    return _buildMobilePanel(context);
  }

  /// Десктоп: полная панель владельца со своим header и светлой темой.
  Widget _buildDesktopPanel(BuildContext context) {
    final now = DateTime.now();
    final orders = ref.watch(orderRepositoryProvider);
    final (start, end) = _rangeFor(_period);
    final rangeOrders = _ordersInRange(orders, start, end);
    final attentionOrders = _attentionOrdersFromList(orders);
    // Только исполнители (мастера) — без владельца и администраторов, не берущих заказы
    final executorStaff = ref.watch(staffRepositoryProvider)
        .where((e) => e.isActive && e.role == StaffRole.master)
        .map((e) => StaffMember(id: e.id, name: e.name, roleLabel: e.roleLabel))
        .toList();
    final staff = executorStaff;

    final completedInRange = rangeOrders
        .where((o) => o.status == OrderStatus.done || o.status == OrderStatus.completed);
    final revenueKopecks = completedInRange.fold<int>(0, (sum, o) => sum + o.totalKopecks);
    final expectedKopecks = rangeOrders
        .where((o) =>
            o.status != OrderStatus.done &&
            o.status != OrderStatus.cancelled &&
            o.status != OrderStatus.completed)
        .fold<int>(0, (sum, o) => sum + o.totalKopecks);
    final orderCount = rangeOrders.length;
    final completedCount = completedInRange.length;
    final avgCheck = completedCount > 0 ? revenueKopecks ~/ completedCount : 0;
    final attentionCount = attentionOrders.length;
    final byMaster = _buildMasterStats(rangeOrders, staff);
    final attentionItems = _buildAttentionItems(orders, rangeOrders);
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final weekOrders = _ordersInRange(orders, weekStart, todayStart.add(const Duration(days: 1)));
    final weekRevenue = weekOrders
        .where((o) => o.status == OrderStatus.done || o.status == OrderStatus.completed)
        .fold<int>(0, (sum, o) => sum + o.totalKopecks);
    final cancelledToday = rangeOrders.where((o) => o.status == OrderStatus.cancelled).fold<int>(0, (s, o) => s + o.totalKopecks);
    final additionalKopecks = rangeOrders.fold<int>(0, (s, o) => s + o.items.where((i) => i.isAdditional).fold<int>(0, (a, i) => a + (i.priceKopecks ?? 0)));
    final totalCapacityMinutes = staff.isEmpty ? 480 : staff.length * 8 * 60;
    final usedMinutes = byMaster.fold<int>(0, (s, m) => s + m.occupiedMinutes);
    final loadPercent = totalCapacityMinutes > 0
        ? (usedMinutes / totalCapacityMinutes * 100).clamp(0.0, 100.0).round()
        : 0;
    const kpiGap = DesktopDesignSystem.elementSpacing;

    // Предыдущий период для тренда
    final (prevStart, prevEnd) = _previousRangeFor(_period);
    final prevOrders = _ordersInRange(orders, prevStart, prevEnd);
    final prevRevenue = prevOrders
        .where((o) => o.status == OrderStatus.done || o.status == OrderStatus.completed)
        .fold<int>(0, (sum, o) => sum + o.totalKopecks);
    final orderTrend = prevOrders.isEmpty ? 0 : orderCount - prevOrders.length;
    final revenueTrendPct = prevRevenue > 0 && revenueKopecks > 0
        ? ((revenueKopecks - prevRevenue) / prevRevenue * 100).round()
        : (prevRevenue == 0 && revenueKopecks > 0 ? 100 : 0);

    // Разбивка заказов по статусам (для карточки «Заказов»)
    final confirmedCount = rangeOrders.where((o) => o.status == OrderStatus.confirmed).length;
    final inProgressCount = rangeOrders.where((o) => o.status == OrderStatus.inProgress).length;
    final noMasterCount = rangeOrders
        .where((o) => (o.masterId == null || o.masterId!.isEmpty) && o.status != OrderStatus.done && o.status != OrderStatus.cancelled)
        .length;
    final atRiskCount = rangeOrders
        .where((o) => o.status == OrderStatus.pendingConfirmation || o.status == OrderStatus.pendingApproval)
        .length;
    final additionalSharePct = revenueKopecks > 0
        ? ((additionalKopecks / revenueKopecks) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardDesktopHeader(
            period: _period,
            onPeriodChanged: (p) => setState(() => _period = p),
            onRefresh: () => ref.read(orderRepositoryProvider.notifier).loadFromApi(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(opacity: value, child: child),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Верхняя аналитическая зона: два ряда KPI
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Padding(
                            padding: const EdgeInsets.only(right: kpiGap / 2),
                            child: _OrdersKpiCard(
                              periodLabel: _periodLabel(_period),
                              orderCount: orderCount,
                              confirmedCount: confirmedCount,
                              inProgressCount: inProgressCount,
                              completedCount: completedCount,
                              cancelledCount: rangeOrders.where((o) => o.status == OrderStatus.cancelled).length,
                              trendDiff: orderTrend,
                              onTap: () => context.go('/app?tab=2'),
                            ),
                          )),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: kpiGap / 2),
                            child: _RevenueKpiCard(
                              revenueKopecks: revenueKopecks,
                              completedCount: completedCount,
                              trendPct: revenueTrendPct,
                              onTap: () => _showRevenueBreakdown(context, byMaster, revenueKopecks),
                            ),
                          )),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.only(left: kpiGap / 2),
                            child: _ExpectedKpiCard(
                              expectedKopecks: expectedKopecks,
                              activeCount: rangeOrders.where((o) =>
                                  o.status != OrderStatus.done &&
                                  o.status != OrderStatus.cancelled &&
                                  o.status != OrderStatus.completed).length,
                              atRiskCount: atRiskCount,
                              noMasterCount: noMasterCount,
                              onTap: () => _showExpectedBreakdown(context, rangeOrders),
                            ),
                          )),
                        ],
                      ),
                      const SizedBox(height: kpiGap),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Padding(
                            padding: const EdgeInsets.only(right: kpiGap / 2),
                            child: _AvgCheckKpiCard(
                              avgCheck: avgCheck,
                              completedCount: completedCount,
                              additionalSharePct: additionalSharePct,
                              onTap: () => _showAvgCheckBreakdown(context, byMaster, avgCheck, completedCount),
                            ),
                          )),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: kpiGap / 2),
                            child: _AttentionKpiCard(
                              attentionCount: attentionCount,
                              noMasterCount: noMasterCount,
                              needApprovalCount: rangeOrders.where((o) => o.status == OrderStatus.pendingApproval).length,
                              needConfirmationCount: rangeOrders.where((o) => o.status == OrderStatus.pendingConfirmation).length,
                              cancelledCount: rangeOrders.where((o) => o.status == OrderStatus.cancelled).length,
                              onTap: () => _showAttentionBreakdown(context, attentionItems),
                            ),
                          )),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.only(left: kpiGap / 2),
                            child: _LoadKpiCard(
                              loadPercent: loadPercent,
                              usedMinutes: usedMinutes,
                              totalCapacityMinutes: totalCapacityMinutes,
                              mastersCount: staff.length,
                              onTap: () => context.go('/app?tab=1'),
                            ),
                          )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing * 1.5),
                  // Требуют внимания + Статусы заказов (два столбца)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _AttentionCard(
                          items: attentionItems,
                          onTap: (tabIndex) {
                            if (tabIndex != null && context.mounted) {
                              context.go('/app?tab=$tabIndex');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: DesktopDesignSystem.blockSpacing),
                      Expanded(
                        flex: 1,
                        child: _OrderStatusDistributionCard(
                          orders: rangeOrders,
                          onSegmentTap: (status) => context.go('/app?tab=2'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing * 1.5),
                  // По мастерам — аналитический блок карточек
                  _MastersSection(
                    masters: () {
                      // Только мастера (исполнители), без строки «Без мастера»
                      final list = List<_MasterStats>.from(byMaster.where((m) => !m.isUnassigned));
                      switch (_masterSort) {
                        case _MasterSort.byRevenue: {
                          list.sort((a, b) => b.revenueKopecks.compareTo(a.revenueKopecks));
                          break;
                        }
                        case _MasterSort.byLoad: {
                          list.sort((a, b) => b.loadPercent.compareTo(a.loadPercent));
                          break;
                        }
                        case _MasterSort.byOrders: {
                          list.sort((a, b) => b.orderCount.compareTo(a.orderCount));
                          break;
                        }
                      }
                      return list;
                    }(),
                    periodLabel: _periodLabel(_period),
                    sortOrder: _masterSort,
                    onSortChanged: (s) => setState(() => _masterSort = s),
                    selectedMasterId: _selectedMasterId,
                    onMasterTap: (id) => setState(() => _selectedMasterId = _selectedMasterId == id ? null : id),
                    onClosePanel: () => setState(() => _selectedMasterId = null),
                    rangeOrders: rangeOrders,
                    onOpenSchedule: () => context.go('/app?tab=1'),
                    onOpenOrders: () => context.go('/app?tab=2'),
                    onOpenStaff: () => context.go('/app?tab=5'),
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing * 1.5),
                  // Заказы на сегодня (или за период)
                  Text(
                    _period == DashboardPeriod.today ? 'Заказы на сегодня' : 'Заказы за период',
                    style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: DesktopDesignSystem.elementSpacing),
                  if (rangeOrders.isEmpty)
                    _DesktopCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Нет заказов',
                            style: DesktopDesignSystem.bodySecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    _DesktopCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < rangeOrders.length && i < 15; i++) ...[
                            if (i > 0) Divider(height: 1, color: AppColorsDesktop.borderLight),
                            _OrderListTile(order: rangeOrders[i]),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing * 1.5),
                  // Финансовый срез
                  Text(
                    'Финансовый срез',
                    style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: DesktopDesignSystem.elementSpacing),
                  _FinancialSliceCard(
                    revenueToday: revenueKopecks,
                    revenueWeek: weekRevenue,
                    avgCheck: avgCheck,
                    additionalKopecks: additionalKopecks,
                    cancelledKopecks: cancelledToday,
                    atRiskKopecks: rangeOrders
                        .where((o) =>
                            o.status == OrderStatus.pendingConfirmation ||
                            o.status == OrderStatus.pendingApproval)
                        .fold<int>(0, (s, o) => s + o.totalKopecks),
                  ),
                  const SizedBox(height: DesktopDesignSystem.blockSpacing * 1.5),
                  // Быстрые переходы
                  Text(
                    'Быстрые переходы',
                    style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: DesktopDesignSystem.elementSpacing),
                  _QuickLinksGrid(
                    onNavigate: (tabIndex) {
                      if (context.mounted) context.go('/app?tab=$tabIndex');
                    },
                  ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePanel(BuildContext context) {
    final orders = ref.watch(orderRepositoryProvider);
    final (start, end) = _rangeFor(_period);
    final rangeOrders = _ordersInRange(orders, start, end);
    final attentionOrders = _attentionOrdersFromList(orders);
    final staff = ref.watch(staffListProvider);

    final periodTotal = rangeOrders
        .where((o) => o.status == OrderStatus.done || o.status == OrderStatus.completed)
        .fold<int>(0, (sum, o) => sum + o.totalKopecks);
    final periodCount = rangeOrders.length;
    final attentionCount = attentionOrders.length;
    final byMaster = _buildMasterStats(rangeOrders, staff);
    var mobileListRows = List<_MasterStats>.from(byMaster);
    if (_mobileMastersOnlyWithLoad) {
      mobileListRows = mobileListRows
          .where((m) => m.orderCount > 0 || m.occupiedMinutes > 0)
          .toList();
    }
    mobileListRows.sort((a, b) => b.revenueKopecks.compareTo(a.revenueKopecks));
    final mobileChartRows =
        mobileListRows.where((m) => !m.isUnassigned).toList();

    final periodOptions = <(DashboardPeriod period, String title)>[
      (DashboardPeriod.yesterday, 'Вчера'),
      (DashboardPeriod.today, 'Сегодня'),
      (DashboardPeriod.tomorrow, 'Завтра'),
      (DashboardPeriod.dayAfterTomorrow, 'Послезавтра'),
      (DashboardPeriod.week, 'Неделя'),
      (DashboardPeriod.month, 'Месяц'),
    ];

    String listTitle;
    switch (_period) {
      case DashboardPeriod.today:
        listTitle = 'Заказы на сегодня';
        break;
      case DashboardPeriod.yesterday:
        listTitle = 'Заказы за вчера';
        break;
      case DashboardPeriod.tomorrow:
        listTitle = 'Заказы на завтра';
        break;
      case DashboardPeriod.dayAfterTomorrow:
        listTitle = 'Заказы на послезавтра';
        break;
      case DashboardPeriod.week:
        listTitle = 'Заказы за неделю';
        break;
      case DashboardPeriod.month:
        listTitle = 'Заказы за месяц';
        break;
      case DashboardPeriod.custom:
        listTitle = 'Заказы за период';
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          if (ref.watch(authProvider).user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  ref.watch(authProvider).user!.role.label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Период: ${_periodLabel(_period)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in periodOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.$2),
                      selected: _period == option.$1,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _period = option.$1);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _KpiCard(
            title: 'Заказов ${_periodLabel(_period)}',
            value: '$periodCount',
            subtitle: periodCount > 0 ? 'по расписанию' : 'нет записей',
          ),
          const SizedBox(height: 12),
          _KpiCard(
            title: 'Выручка ${_periodLabel(_period)}',
            value: formatMoney(periodTotal),
            subtitle: periodTotal > 0 ? 'закрытые заказы' : 'пока нет',
          ),
          const SizedBox(height: 12),
          _KpiCard(
            title: 'Требуют внимания',
            value: '$attentionCount',
            subtitle: attentionCount > 0 ? 'новые заявки, согласование' : 'всё в порядке',
            accent: attentionCount > 0,
          ),
          const SizedBox(height: 24),
          Text(
            'Загруженность сотрудников (${_periodLabel(_period)})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Сравните количество заказов, занятое время и выручку по каждому мастеру.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Все мастера'),
                selected: !_mobileMastersOnlyWithLoad,
                onSelected: (v) {
                  if (v) setState(() => _mobileMastersOnlyWithLoad = false);
                },
              ),
              FilterChip(
                label: const Text('С загрузкой в периоде'),
                selected: _mobileMastersOnlyWithLoad,
                onSelected: (v) {
                  if (v) setState(() => _mobileMastersOnlyWithLoad = true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'В списке только активные сотрудники организации. Фильтр оставляет мастеров с заказами или занятым временем.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          if (mobileChartRows.isNotEmpty)
            _MobileMasterLoadBarChart(
              masters: mobileChartRows,
              periodLabel: _periodLabel(_period),
            ),
          if (mobileChartRows.isNotEmpty) const SizedBox(height: 12),
          if (mobileListRows.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                _mobileMastersOnlyWithLoad
                    ? 'Нет мастеров с загрузкой ${_periodLabel(_period)}'
                    : 'Нет данных по мастерам ${_periodLabel(_period)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...mobileListRows.map((s) => _MasterStatCard(stats: s)),
          const SizedBox(height: 24),
          Text(
            listTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (rangeOrders.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Нет заказов ${_periodLabel(_period)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...rangeOrders.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OrderTile(order: o),
                )),
        ],
      ),
    );
  }

  static List<_MasterStats> _buildMasterStats(
    List<Order> rangeOrders,
    List<StaffMember> staff,
  ) {
    final map = <String, _MasterStats>{};
    for (final m in staff) {
      map[m.id] = _MasterStats(
        masterId: m.id,
        masterName: m.name,
        roleLabel: m.roleLabel,
        orderCount: 0,
        completedCount: 0,
        inProgressCount: 0,
        pendingApprovalCount: 0,
        cancelledCount: 0,
        revenueKopecks: 0,
        expectedRevenueKopecks: 0,
        additionalKopecks: 0,
        occupiedMinutes: 0,
      );
    }
    map[''] = _MasterStats(
      masterId: '',
      masterName: 'Без мастера',
      orderCount: 0,
      completedCount: 0,
      inProgressCount: 0,
      pendingApprovalCount: 0,
      cancelledCount: 0,
      revenueKopecks: 0,
      expectedRevenueKopecks: 0,
      additionalKopecks: 0,
      occupiedMinutes: 0,
    );

    for (final o in rangeOrders) {
      final key = o.masterId ?? '';
      if (!map.containsKey(key)) {
        map[key] = _MasterStats(
          masterId: key,
          masterName: o.masterName ?? 'Без мастера',
          orderCount: 0,
          completedCount: 0,
          inProgressCount: 0,
          pendingApprovalCount: 0,
          cancelledCount: 0,
          revenueKopecks: 0,
          expectedRevenueKopecks: 0,
          additionalKopecks: 0,
          occupiedMinutes: 0,
        );
      }
      final s = map[key]!;
      final closed = o.status == OrderStatus.done || o.status == OrderStatus.completed;
      final occupied = o.items.fold<int>(0, (sum, i) => sum + i.estimatedMinutes);
      final expected = (closed ? 0 : o.totalKopecks);
      final additional = o.items.where((i) => i.isAdditional).fold<int>(0, (sum, i) => sum + (i.priceKopecks ?? 0));
      int completed = s.completedCount;
      int inProgress = s.inProgressCount;
      int pendingApproval = s.pendingApprovalCount;
      int cancelled = s.cancelledCount;
      if (o.status == OrderStatus.done || o.status == OrderStatus.completed) {
        completed++;
      } else if (o.status == OrderStatus.inProgress) {
        inProgress++;
      } else if (o.status == OrderStatus.pendingApproval) {
        pendingApproval++;
      } else if (o.status == OrderStatus.cancelled) {
        cancelled++;
      }

      map[key] = _MasterStats(
        masterId: s.masterId,
        masterName: s.masterName,
        roleLabel: s.roleLabel,
        orderCount: s.orderCount + 1,
        completedCount: completed,
        inProgressCount: inProgress,
        pendingApprovalCount: pendingApproval,
        cancelledCount: cancelled,
        revenueKopecks: s.revenueKopecks + (closed ? o.totalKopecks : 0),
        expectedRevenueKopecks: s.expectedRevenueKopecks + expected,
        additionalKopecks: s.additionalKopecks + additional,
        occupiedMinutes: s.occupiedMinutes + occupied,
      );
    }

    // Все мастера (включая без заказов) + «Без мастера» только если есть такие заказы
    final list = map.entries
        .where((e) => e.key.isNotEmpty || e.value.orderCount > 0)
        .map((e) => e.value)
        .toList();
    list.sort((a, b) => b.revenueKopecks.compareTo(a.revenueKopecks));
    return list;
  }
}

// --- Desktop header ---

class _DashboardDesktopHeader extends StatelessWidget {
  const _DashboardDesktopHeader({
    required this.period,
    required this.onPeriodChanged,
    required this.onRefresh,
  });

  final DashboardPeriod period;
  final void Function(DashboardPeriod) onPeriodChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopDesignSystem.pagePadding,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        border: const Border(bottom: BorderSide(color: AppColorsDesktop.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Панель владельца',
                  style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ключевые показатели сервиса, загрузка мастеров и заказы, требующие внимания',
                  style: DesktopDesignSystem.meta.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 1,
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<DashboardPeriod>(
                    segments: [
                      const ButtonSegment(value: DashboardPeriod.today, label: Text('Сегодня')),
                      const ButtonSegment(value: DashboardPeriod.yesterday, label: Text('Вчера')),
                      const ButtonSegment(value: DashboardPeriod.tomorrow, label: Text('Завтра')),
                      const ButtonSegment(value: DashboardPeriod.dayAfterTomorrow, label: Text('Послезавтра')),
                      const ButtonSegment(value: DashboardPeriod.week, label: Text('Неделя')),
                      const ButtonSegment(value: DashboardPeriod.month, label: Text('Месяц')),
                    ],
                    selected: {period},
                    onSelectionChanged: (set) {
                      final p = set.first;
                      if (p != period) onPeriodChanged(p);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) return AppColorsDesktop.surface;
                        return AppColorsDesktop.textSecondary;
                      }),
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) return AppColorsDesktop.primary;
                        return AppColorsDesktop.nestedBg;
                      }),
                      side: WidgetStateProperty.all(const BorderSide(color: AppColorsDesktop.border)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    tooltip: 'Обновить',
                    style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.download_rounded, size: 22),
                    tooltip: 'Экспорт',
                    style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined, size: 22),
                    tooltip: 'Уведомления',
                    style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Вспомогательный ряд для breakdown ---
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: DesktopDesignSystem.bodySecondary, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(value, style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Фиксированная высота всех KPI-карточек верхнего ряда — единый размер вне зависимости от наполнения.
const double _kKpiCardHeight = 136.0;

// --- Карточка «Заказов» (первый ряд) ---
class _OrdersKpiCard extends StatefulWidget {
  const _OrdersKpiCard({
    required this.periodLabel,
    required this.orderCount,
    required this.confirmedCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.trendDiff,
    required this.onTap,
  });
  final String periodLabel;
  final int orderCount;
  final int confirmedCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;
  final int trendDiff;
  final VoidCallback onTap;

  @override
  State<_OrdersKpiCard> createState() => _OrdersKpiCardState();
}

class _OrdersKpiCardState extends State<_OrdersKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Открыть список заказов',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _kKpiCardHeight,
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: _hover ? AppColorsDesktop.primary.withValues(alpha: 0.3) : AppColorsDesktop.borderLight,
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 20, color: AppColorsDesktop.textTertiary),
                          const SizedBox(width: 8),
                          Text('Заказов', style: DesktopDesignSystem.label),
                        ],
                      ),
                      Text('${widget.orderCount}', style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 26)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.periodLabel, style: DesktopDesignSystem.meta),
                          if (widget.trendDiff != 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.trendDiff > 0 ? '+${widget.trendDiff} к прошл. периоду' : '${widget.trendDiff} к прошл. периоду',
                              style: DesktopDesignSystem.meta.copyWith(
                                color: widget.trendDiff > 0 ? AppColorsDesktop.success : AppColorsDesktop.error,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColorsDesktop.nestedBg,
                    borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                    border: Border.all(color: AppColorsDesktop.borderLight),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusRow('подтв.', widget.confirmedCount, AppColorsDesktop.primary),
                      const SizedBox(height: 2),
                      _StatusRow('в работе', widget.inProgressCount, AppColorsDesktop.statusInProgress),
                      const SizedBox(height: 2),
                      _StatusRow('заверш.', widget.completedCount, AppColorsDesktop.success),
                      const SizedBox(height: 2),
                      _StatusRow('отменено', widget.cancelledCount, AppColorsDesktop.error),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: DesktopDesignSystem.meta.copyWith(fontSize: 10, color: AppColorsDesktop.textTertiary)),
        const SizedBox(width: 6),
        Text('$count', style: DesktopDesignSystem.meta.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// --- Карточка «Выручка» ---
class _RevenueKpiCard extends StatefulWidget {
  const _RevenueKpiCard({
    required this.revenueKopecks,
    required this.completedCount,
    required this.trendPct,
    required this.onTap,
  });
  final int revenueKopecks;
  final int completedCount;
  final int trendPct;
  final VoidCallback onTap;

  @override
  State<_RevenueKpiCard> createState() => _RevenueKpiCardState();
}

class _RevenueKpiCardState extends State<_RevenueKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Расшифровка выручки',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _kKpiCardHeight,
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: _hover ? AppColorsDesktop.primary.withValues(alpha: 0.3) : AppColorsDesktop.borderLight,
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppColorsDesktop.textTertiary),
                    const SizedBox(width: 8),
                    Text('Выручка', style: DesktopDesignSystem.label),
                  ],
                ),
                Text(
                  widget.revenueKopecks > 0 ? formatMoney(widget.revenueKopecks) : '—',
                  style: DesktopDesignSystem.pageTitle.copyWith(
                    fontSize: 26,
                    color: AppColorsDesktop.accentMoney,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.revenueKopecks > 0
                          ? 'факт по завершённым · ${widget.completedCount} зак.'
                          : 'нет завершённых заказов',
                      style: DesktopDesignSystem.meta,
                    ),
                    if (widget.trendPct != 0 && widget.revenueKopecks > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.trendPct > 0 ? '+${widget.trendPct}% к прошл. периоду' : '${widget.trendPct}% к прошл. периоду',
                        style: DesktopDesignSystem.meta.copyWith(
                          color: widget.trendPct > 0 ? AppColorsDesktop.success : AppColorsDesktop.error,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Карточка «Ожидается» ---
class _ExpectedKpiCard extends StatefulWidget {
  const _ExpectedKpiCard({
    required this.expectedKopecks,
    required this.activeCount,
    required this.atRiskCount,
    required this.noMasterCount,
    required this.onTap,
  });
  final int expectedKopecks;
  final int activeCount;
  final int atRiskCount;
  final int noMasterCount;
  final VoidCallback onTap;

  @override
  State<_ExpectedKpiCard> createState() => _ExpectedKpiCardState();
}

class _ExpectedKpiCardState extends State<_ExpectedKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Список незавершённых заказов',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _kKpiCardHeight,
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: _hover ? AppColorsDesktop.primary.withValues(alpha: 0.3) : AppColorsDesktop.borderLight,
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, size: 20, color: AppColorsDesktop.textTertiary),
                    const SizedBox(width: 8),
                    Text('Ожидается', style: DesktopDesignSystem.label),
                  ],
                ),
                Text(
                  widget.expectedKopecks > 0 ? formatMoney(widget.expectedKopecks) : '—',
                  style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 26, color: AppColorsDesktop.primary),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('по незавершённым', style: DesktopDesignSystem.meta),
                    if (widget.activeCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'активных: ${widget.activeCount} · в риске: ${widget.atRiskCount} · без мастера: ${widget.noMasterCount}',
                        style: DesktopDesignSystem.meta.copyWith(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Карточка «Средний чек» ---
class _AvgCheckKpiCard extends StatefulWidget {
  const _AvgCheckKpiCard({
    required this.avgCheck,
    required this.completedCount,
    required this.additionalSharePct,
    required this.onTap,
  });
  final int avgCheck;
  final int completedCount;
  final int additionalSharePct;
  final VoidCallback onTap;

  @override
  State<_AvgCheckKpiCard> createState() => _AvgCheckKpiCardState();
}

class _AvgCheckKpiCardState extends State<_AvgCheckKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.completedCount == 0;
    return Tooltip(
      message: 'Аналитика среднего чека',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _kKpiCardHeight,
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: _hover ? AppColorsDesktop.primary.withValues(alpha: 0.3) : AppColorsDesktop.borderLight,
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_rounded, size: 20, color: AppColorsDesktop.textTertiary),
                    const SizedBox(width: 8),
                    Text('Средний чек', style: DesktopDesignSystem.label),
                  ],
                ),
                Text(
                  isEmpty ? '—' : formatMoney(widget.avgCheck),
                  style: DesktopDesignSystem.pageTitle.copyWith(
                    fontSize: 26,
                    color: isEmpty ? AppColorsDesktop.textTertiary : AppColorsDesktop.accentMoney,
                  ),
                ),
                Text(
                  isEmpty
                      ? 'Недостаточно закрытых заказов для расчёта'
                      : 'по ${widget.completedCount} зак. · доп. работы: ${widget.additionalSharePct}%',
                  style: DesktopDesignSystem.meta,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Карточка «Требуют внимания» ---
class _AttentionKpiCard extends StatefulWidget {
  const _AttentionKpiCard({
    required this.attentionCount,
    required this.noMasterCount,
    required this.needApprovalCount,
    required this.needConfirmationCount,
    required this.cancelledCount,
    required this.onTap,
  });
  final int attentionCount;
  final int noMasterCount;
  final int needApprovalCount;
  final int needConfirmationCount;
  final int cancelledCount;
  final VoidCallback onTap;

  @override
  State<_AttentionKpiCard> createState() => _AttentionKpiCardState();
}

class _AttentionKpiCardState extends State<_AttentionKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hasIssues = widget.attentionCount > 0;
    return Tooltip(
      message: 'Список проблемных заказов',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _kKpiCardHeight,
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
            decoration: BoxDecoration(
              color: hasIssues ? AppColorsDesktop.warning.withValues(alpha: 0.06) : AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: hasIssues ? AppColorsDesktop.warning.withValues(alpha: 0.35) : (_hover ? AppColorsDesktop.primary.withValues(alpha: 0.3) : AppColorsDesktop.borderLight),
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: hasIssues ? AppColorsDesktop.warning : AppColorsDesktop.textTertiary),
                    const SizedBox(width: 8),
                    Text('Требуют внимания', style: DesktopDesignSystem.label.copyWith(color: hasIssues ? AppColorsDesktop.warning : AppColorsDesktop.textSecondary)),
                  ],
                ),
                Text(
                  '${widget.attentionCount}',
                  style: DesktopDesignSystem.pageTitle.copyWith(
                    fontSize: 26,
                    color: hasIssues ? AppColorsDesktop.warning : AppColorsDesktop.textPrimary,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasIssues ? 'согласование, без мастера, переносы' : 'всё в порядке',
                      style: DesktopDesignSystem.meta,
                    ),
                    if (hasIssues) ...[
                      const SizedBox(height: 2),
                      Text(
                        'без мастера: ${widget.noMasterCount} · соглас.: ${widget.needApprovalCount} · не подтв.: ${widget.needConfirmationCount} · отменено: ${widget.cancelledCount}',
                        style: DesktopDesignSystem.meta.copyWith(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Карточка «Загрузка сервиса» ---
class _LoadKpiCard extends StatefulWidget {
  const _LoadKpiCard({
    required this.loadPercent,
    required this.usedMinutes,
    required this.totalCapacityMinutes,
    required this.mastersCount,
    required this.onTap,
  });
  final int loadPercent;
  final int usedMinutes;
  final int totalCapacityMinutes;
  final int mastersCount;
  final VoidCallback onTap;

  @override
  State<_LoadKpiCard> createState() => _LoadKpiCardState();
}

class _LoadKpiCardState extends State<_LoadKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final usedH = widget.usedMinutes ~/ 60;
    final usedM = widget.usedMinutes % 60;
    final totalH = widget.totalCapacityMinutes ~/ 60;
    return Tooltip(
      message: 'Загрузка по мастерам',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _kKpiCardHeight,
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(
                color: _hover ? AppColorsDesktop.primary.withValues(alpha: 0.3) : AppColorsDesktop.borderLight,
              ),
              boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, size: 20, color: AppColorsDesktop.textTertiary),
                    const SizedBox(width: 8),
                    Text('Загрузка сервиса', style: DesktopDesignSystem.label),
                  ],
                ),
                Text('${widget.loadPercent}%', style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 26)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('по заказам за период', style: DesktopDesignSystem.meta),
                    const SizedBox(height: 2),
                    Text(
                      '$usedHч $usedMм занято из $totalHч · мастеров: ${widget.mastersCount}',
                      style: DesktopDesignSystem.meta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Desktop KPI card (legacy, with hover) ---

class _DesktopKpiCard extends StatefulWidget {
  const _DesktopKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  State<_DesktopKpiCard> createState() => _DesktopKpiCardState();
}

class _DesktopKpiCardState extends State<_DesktopKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
        decoration: BoxDecoration(
          color: AppColorsDesktop.surface,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
          border: Border.all(
            color: AppColorsDesktop.borderLight,
          ),
          boxShadow: _hover ? DesktopDesignSystem.shadowCardHover : DesktopDesignSystem.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: AppColorsDesktop.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: DesktopDesignSystem.label.copyWith(
                      color: AppColorsDesktop.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.value,
              style: DesktopDesignSystem.pageTitle.copyWith(
                fontSize: 24,
                color: AppColorsDesktop.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: DesktopDesignSystem.meta,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Блок «По мастерам» — секция с карточками и панелью мастера ---

class _MastersSection extends StatelessWidget {
  const _MastersSection({
    required this.masters,
    required this.periodLabel,
    required this.sortOrder,
    required this.onSortChanged,
    required this.selectedMasterId,
    required this.onMasterTap,
    required this.onClosePanel,
    required this.rangeOrders,
    required this.onOpenSchedule,
    required this.onOpenOrders,
    required this.onOpenStaff,
  });

  final List<_MasterStats> masters;
  final String periodLabel;
  final _MasterSort sortOrder;
  final void Function(_MasterSort) onSortChanged;
  final String? selectedMasterId;
  final void Function(String?) onMasterTap;
  final VoidCallback onClosePanel;
  final List<Order> rangeOrders;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenStaff;

  @override
  Widget build(BuildContext context) {
    final panelStats = selectedMasterId != null
        ? masters.where((m) => m.masterId == selectedMasterId).toList()
        : <_MasterStats>[];
    final statsForPanel = panelStats.isNotEmpty ? panelStats.first : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'По мастерам',
                    style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    periodLabel,
                    style: DesktopDesignSystem.meta.copyWith(fontSize: 14),
                  ),
                  const Spacer(),
                  DropdownButton<_MasterSort>(
                    value: sortOrder,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: DesktopDesignSystem.body.copyWith(fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: _MasterSort.byRevenue, child: Text('По выручке')),
                      DropdownMenuItem(value: _MasterSort.byLoad, child: Text('По загрузке')),
                      DropdownMenuItem(value: _MasterSort.byOrders, child: Text('По заказам')),
                    ],
                    onChanged: (v) => v != null ? onSortChanged(v) : null,
                  ),
                ],
              ),
              const SizedBox(height: DesktopDesignSystem.elementSpacing),
              if (masters.isEmpty)
                _DesktopCard(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Нет мастеров в организации или заказов за период',
                        style: DesktopDesignSystem.bodySecondary,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: masters.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MasterCard(
                      stats: m,
                      isSelected: selectedMasterId == m.masterId,
                      onTap: () => onMasterTap(m.masterId),
                    ),
                  )).toList(),
                ),
            ],
          ),
        ),
        if (statsForPanel != null) ...[
          const SizedBox(width: 20),
          TweenAnimationBuilder<Offset>(
            key: ValueKey(statsForPanel.masterId),
            tween: Tween(begin: const Offset(0.12, 0), end: Offset.zero),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: (1 - value.dx * 4).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(value.dx * 80, 0),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: 380,
              child: _MasterDetailPanel(
                stats: statsForPanel,
                rangeOrders: rangeOrders,
                onClose: onClosePanel,
                onOpenSchedule: onOpenSchedule,
                onOpenOrders: onOpenOrders,
                onOpenStaff: onOpenStaff,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MasterCard extends StatefulWidget {
  const _MasterCard({
    required this.stats,
    required this.isSelected,
    required this.onTap,
  });
  final _MasterStats stats;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_MasterCard> createState() => _MasterCardState();
}

class _MasterCardState extends State<_MasterCard> {
  bool _hover = false;

  /// Цвет прогресс-бара загрузки: до 40% — сине-серый, 40–75% — синий, 75–95% — янтарный, >95% — красный.
  static Color _loadBarColor(double pct) {
    if (pct > 95) return AppColorsDesktop.error;
    if (pct >= 75) return AppColorsDesktop.warning;
    if (pct >= 40) return AppColorsDesktop.primary;
    return AppColorsDesktop.textTertiary;
  }

  /// Статус мастера и цвет индикатора.
  static (String label, Color color) _status(double loadPct, int orderCount) {
    if (orderCount == 0) return ('Свободен', AppColorsDesktop.textTertiary);
    if (loadPct > 95) return ('Загружен', AppColorsDesktop.error);
    if (loadPct >= 75) return ('Почти заполнен', AppColorsDesktop.warning);
    return ('В смене', AppColorsDesktop.success);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final loadPct = s.loadPercent;
    final freeMinutes = _MasterStats.workingDayMinutes - s.occupiedMinutes;
    final hasOrders = s.orderCount > 0;
    final (statusLabel, statusColor) = _status(loadPct, s.orderCount);
    const shiftLabel = '09:00–18:00';

    return Tooltip(
      message: 'Подробнее о мастере',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColorsDesktop.primary.withValues(alpha: 0.05)
                  : AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.isSelected
                    ? AppColorsDesktop.primary
                    : (_hover ? AppColorsDesktop.primary.withValues(alpha: 0.3) : AppColorsDesktop.borderLight),
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: _hover || widget.isSelected
                  ? DesktopDesignSystem.shadowCardHover
                  : DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ----- Верхняя часть: аватар + имя/роль/статус | KPI заказов -----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.12),
                      child: Text(
                        s.masterName.isNotEmpty ? s.masterName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColorsDesktop.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.masterName,
                            style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 17),
                          ),
                          if (s.roleLabel != null && s.roleLabel!.isNotEmpty)
                            Text(
                              s.roleLabel!,
                              style: DesktopDesignSystem.meta.copyWith(fontSize: 13),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: DesktopDesignSystem.meta.copyWith(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (s.cancelledCount > 0 || (s.additionalSharePercent >= 25 && s.additionalSharePercent > 0) || !hasOrders) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (!hasOrders)
                                  _SmallBadge('Свободен', AppColorsDesktop.success),
                                if (s.cancelledCount > 0)
                                  _SmallBadge('Есть отмены', AppColorsDesktop.error),
                                if (s.additionalSharePercent >= 25 && s.additionalSharePercent > 0)
                                  _SmallBadge('Много доп.работ', AppColorsDesktop.warning),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // KPI заказов справа
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColorsDesktop.nestedBg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Заказов: ${s.orderCount}',
                            style: DesktopDesignSystem.body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColorsDesktop.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'заверш.: ${s.completedCount} · в работе: ${s.inProgressCount}',
                            style: DesktopDesignSystem.meta.copyWith(fontSize: 11),
                          ),
                          if (s.pendingApprovalCount > 0 || s.cancelledCount > 0)
                            Text(
                              'соглас.: ${s.pendingApprovalCount} · отмен.: ${s.cancelledCount}',
                              style: DesktopDesignSystem.meta.copyWith(
                                fontSize: 11,
                                color: s.cancelledCount > 0 ? AppColorsDesktop.error : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ----- Центральная часть: факт, ожидается, доп.работы -----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Факт — главный денежный показатель
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.revenueKopecks > 0
                              ? formatMoney(s.revenueKopecks)
                              : (hasOrders ? 'Пока нет закрытых' : '—'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: s.revenueKopecks > 0
                                ? AppColorsDesktop.accentMoney
                                : AppColorsDesktop.textTertiary,
                          ),
                        ),
                        Text('Факт', style: DesktopDesignSystem.meta.copyWith(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    if (s.expectedRevenueKopecks > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${formatMoney(s.expectedRevenueKopecks)}',
                            style: DesktopDesignSystem.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColorsDesktop.primary,
                              fontSize: 15,
                            ),
                          ),
                          Text('Ожидается', style: DesktopDesignSystem.meta.copyWith(fontSize: 11)),
                        ],
                      ),
                    if (s.expectedRevenueKopecks > 0) const SizedBox(width: 24),
                    if (s.additionalKopecks > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatMoney(s.additionalKopecks),
                            style: DesktopDesignSystem.body.copyWith(
                              color: AppColorsDesktop.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text('Доп.работы', style: DesktopDesignSystem.meta.copyWith(fontSize: 11)),
                        ],
                      ),
                    const Spacer(),
                    if (s.completedCount > 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(s.avgCheckKopecks),
                            style: DesktopDesignSystem.meta.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text('средний чек', style: DesktopDesignSystem.meta.copyWith(fontSize: 10)),
                        ],
                      ),
                      if (s.additionalSharePercent > 0) ...[
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${s.additionalSharePercent}%',
                              style: DesktopDesignSystem.meta.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColorsDesktop.warning,
                              ),
                            ),
                            Text('доля доп.', style: DesktopDesignSystem.meta.copyWith(fontSize: 10)),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                // ----- Нижняя часть: смена, время, прогресс-бар загрузки -----
                Divider(height: 1, color: AppColorsDesktop.borderLight),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Смена: $shiftLabel',
                      style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Занято: ${s.occupiedMinutes ~/ 60}ч ${s.occupiedMinutes % 60}м',
                      style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Свободно: ${freeMinutes ~/ 60}ч ${freeMinutes % 60}м',
                      style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (loadPct / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: AppColorsDesktop.nestedBg,
                          valueColor: AlwaysStoppedAnimation<Color>(_loadBarColor(loadPct)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${loadPct.round()}%',
                        style: DesktopDesignSystem.label.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _loadBarColor(loadPct),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                if (!hasOrders)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '8ч доступно',
                      style: DesktopDesignSystem.meta.copyWith(fontSize: 12, color: AppColorsDesktop.success),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MasterDetailPanel extends StatelessWidget {
  const _MasterDetailPanel({
    required this.stats,
    required this.rangeOrders,
    required this.onClose,
    required this.onOpenSchedule,
    required this.onOpenOrders,
    required this.onOpenStaff,
  });
  final _MasterStats stats;
  final List<Order> rangeOrders;
  final VoidCallback onClose;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenStaff;

  static Color _statusColor(double loadPct, int orderCount) {
    if (orderCount == 0) return AppColorsDesktop.textTertiary;
    if (loadPct > 95) return AppColorsDesktop.error;
    if (loadPct >= 75) return AppColorsDesktop.warning;
    return AppColorsDesktop.success;
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final masterOrders = rangeOrders.where((o) => (o.masterId ?? '') == s.masterId).toList();
    masterOrders.sort((a, b) => (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)));
    final freeMin = _MasterStats.workingDayMinutes - s.occupiedMinutes;
    final statusColor = _statusColor(s.loadPercent, s.orderCount);

    return _DesktopCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.12),
                  child: Text(
                    s.masterName.isNotEmpty ? s.masterName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColorsDesktop.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.masterName,
                        style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 18),
                      ),
                      if (s.roleLabel != null && s.roleLabel!.isNotEmpty)
                        Text(s.roleLabel!, style: DesktopDesignSystem.meta.copyWith(fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.orderCount == 0
                                ? 'Свободен'
                                : (s.loadPercent > 95
                                    ? 'Загружен'
                                    : (s.loadPercent >= 75 ? 'Почти заполнен' : 'В смене')),
                            style: DesktopDesignSystem.meta.copyWith(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Смена: 09:00–18:00', style: DesktopDesignSystem.meta.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(foregroundColor: AppColorsDesktop.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('KPI за период', style: DesktopDesignSystem.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _ChipLabel('Заказов: ${s.orderCount}', null),
                _ChipLabel('Завершено: ${s.completedCount}', AppColorsDesktop.success),
                _ChipLabel('В работе: ${s.inProgressCount}', AppColorsDesktop.primary),
                if (s.pendingApprovalCount > 0) _ChipLabel('Согласование: ${s.pendingApprovalCount}', AppColorsDesktop.warning),
                if (s.cancelledCount > 0) _ChipLabel('Отменено: ${s.cancelledCount}', AppColorsDesktop.error),
                _ChipLabel('Факт: ${formatMoney(s.revenueKopecks)}', AppColorsDesktop.accentMoney),
                _ChipLabel('Ожидается: ${formatMoney(s.expectedRevenueKopecks)}', null),
                if (s.additionalKopecks > 0) _ChipLabel('Доп.работы: ${formatMoney(s.additionalKopecks)}', AppColorsDesktop.warning),
                _ChipLabel('Ср. чек: ${formatMoney(s.avgCheckKopecks)}', null),
                _ChipLabel('Загрузка: ${s.loadPercent.round()}%', null),
              ],
            ),
            const SizedBox(height: 16),
            Text('Время', style: DesktopDesignSystem.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Занято: ${s.occupiedMinutes ~/ 60}ч ${s.occupiedMinutes % 60}м · Свободно: ${freeMin ~/ 60}ч ${freeMin % 60}м',
              style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text('Заказы (${masterOrders.length})', style: DesktopDesignSystem.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (masterOrders.isEmpty)
              Text('Нет заказов за период', style: DesktopDesignSystem.meta)
            else
              ...masterOrders.take(5).map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          o.orderNumber,
                          style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            o.carInfo,
                            style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatMoney(o.totalKopecks),
                          style: DesktopDesignSystem.meta.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenSchedule,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: const Text('Расписание'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColorsDesktop.primary,
                      side: const BorderSide(color: AppColorsDesktop.border),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenOrders,
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Заказы'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColorsDesktop.primary,
                      side: const BorderSide(color: AppColorsDesktop.border),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenStaff,
              icon: const Icon(Icons.person_rounded, size: 18),
              label: const Text('Профиль сотрудника'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColorsDesktop.textSecondary,
                side: const BorderSide(color: AppColorsDesktop.border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel(this.text, this.color);
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColorsDesktop.nestedBg).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: color != null ? Border.all(color: color!.withValues(alpha: 0.5)) : null,
      ),
      child: Text(
        text,
        style: DesktopDesignSystem.meta.copyWith(
          fontSize: 11,
          color: color ?? AppColorsDesktop.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: DesktopDesignSystem.meta.copyWith(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// --- Desktop card container ---

class _DesktopCard extends StatelessWidget {
  const _DesktopCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: child,
    );
  }
}

// --- Требуют внимания (actionable list) ---

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.items, required this.onTap});

  final List<_AttentionItem> items;
  final void Function(int? tabIndex) onTap;

  static Color _severityColor(_AttentionSeverity s) {
    switch (s) {
      case _AttentionSeverity.warning:
        return AppColorsDesktop.warning;
      case _AttentionSeverity.error:
        return AppColorsDesktop.error;
      case _AttentionSeverity.info:
        return AppColorsDesktop.textSecondary;
      case _AttentionSeverity.success:
        return AppColorsDesktop.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DesktopCard(
      child: Padding(
        padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: AppColorsDesktop.warning),
                const SizedBox(width: 8),
                Text(
                  'Требуют внимания',
                  style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              final color = _severityColor(item.severity);
              return InkWell(
                onTap: item.count > 0 ? () => onTap(item.tabIndex) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      if (item.count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.count}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      if (item.count > 0) const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: DesktopDesignSystem.bodySecondary.copyWith(
                            color: item.count > 0 ? AppColorsDesktop.textPrimary : AppColorsDesktop.textTertiary,
                          ),
                        ),
                      ),
                      if (item.count > 0 && item.tabIndex != null)
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColorsDesktop.textTertiary),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- Распределение статусов заказов ---

class _OrderStatusDistributionCard extends StatelessWidget {
  const _OrderStatusDistributionCard({required this.orders, required this.onSegmentTap});

  final List<Order> orders;
  final void Function(OrderStatus status) onSegmentTap;

  @override
  Widget build(BuildContext context) {
    final byStatus = <OrderStatus, int>{};
    final sumByStatus = <OrderStatus, int>{};
    for (final s in OrderStatus.values) {
      byStatus[s] = 0;
      sumByStatus[s] = 0;
    }
    for (final o in orders) {
      byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
      sumByStatus[o.status] = (sumByStatus[o.status] ?? 0) + o.totalKopecks;
    }
    final total = orders.length;
    final segments = OrderStatus.values
        .where((s) => (byStatus[s] ?? 0) > 0)
        .map((s) => _StatusSegment(s, byStatus[s]!, sumByStatus[s]!))
        .toList();
    if (segments.isEmpty) {
      return _DesktopCard(
        child: Padding(
          padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Статусы заказов', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15)),
              const SizedBox(height: 12),
              Text('Нет заказов за период', style: DesktopDesignSystem.meta),
            ],
          ),
        ),
      );
    }
    return _DesktopCard(
      child: Padding(
        padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Статусы заказов', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: segments.map((seg) {
                final pct = total > 0 ? (seg.count / total * 100).toStringAsFixed(0) : '0';
                return Flexible(
                  flex: seg.count > 0 ? seg.count : 1,
                  child: Tooltip(
                    message: '${seg.status.label}: ${seg.count} · ${formatMoney(seg.sumKopecks)} · $pct%',
                    child: InkWell(
                      onTap: () => onSegmentTap(seg.status),
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: _orderStatusColor(seg.status),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: segments.map((seg) {
                final pct = total > 0 ? (seg.count / total * 100).toStringAsFixed(0) : '0';
                return Tooltip(
                  message: '${seg.status.label}: ${seg.count} · ${formatMoney(seg.sumKopecks)} · $pct%',
                  child: InkWell(
                    onTap: () => onSegmentTap(seg.status),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _orderStatusColor(seg.status),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${seg.status.label}: ${seg.count}',
                            style: DesktopDesignSystem.meta.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  static Color _orderStatusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pendingConfirmation:
        return AppColorsDesktop.statusPending;
      case OrderStatus.confirmed:
        return AppColorsDesktop.statusConfirmed;
      case OrderStatus.inProgress:
        return AppColorsDesktop.statusInProgress;
      case OrderStatus.pendingApproval:
        return AppColorsDesktop.statusApproval;
      case OrderStatus.completed:
      case OrderStatus.done:
        return AppColorsDesktop.statusCompleted;
      case OrderStatus.cancelled:
        return AppColorsDesktop.statusCancelled;
    }
  }
}

class _StatusSegment {
  const _StatusSegment(this.status, this.count, this.sumKopecks);
  final OrderStatus status;
  final int count;
  final int sumKopecks;
}

// --- Финансовый срез ---

class _FinancialSliceCard extends StatelessWidget {
  const _FinancialSliceCard({
    required this.revenueToday,
    required this.revenueWeek,
    required this.avgCheck,
    required this.additionalKopecks,
    required this.cancelledKopecks,
    required this.atRiskKopecks,
  });

  final int revenueToday;
  final int revenueWeek;
  final int avgCheck;
  final int additionalKopecks;
  final int cancelledKopecks;
  final int atRiskKopecks;

  @override
  Widget build(BuildContext context) {
    final additionalShare = revenueToday > 0
        ? ((additionalKopecks / revenueToday) * 100).toStringAsFixed(0)
        : '0';
    return _DesktopCard(
      child: Padding(
        padding: const EdgeInsets.all(DesktopDesignSystem.cardPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FinancialRow('Выручка за период', formatMoney(revenueToday), null),
                  _FinancialRow('Выручка за неделю', formatMoney(revenueWeek), null),
                  _FinancialRow('Средний чек', formatMoney(avgCheck), null),
                  _FinancialRow('Доп. работы', formatMoney(additionalKopecks), '$additionalShare% от выручки'),
                  _FinancialRow('Отменено / упущено', formatMoney(cancelledKopecks), null),
                  _FinancialRow('В риске (неподтвержд.)', formatMoney(atRiskKopecks), null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow(this.label, this.value, this.hint);

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DesktopDesignSystem.bodySecondary),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: DesktopDesignSystem.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColorsDesktop.accentMoney,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 6),
                Text('($hint)', style: DesktopDesignSystem.meta),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// --- Быстрые переходы ---

class _QuickLinksGrid extends StatelessWidget {
  const _QuickLinksGrid({required this.onNavigate});

  final void Function(int tabIndex) onNavigate;

  static const _links = [
    (icon: Icons.calendar_today_rounded, label: 'Расписание', tab: 1),
    (icon: Icons.receipt_long_rounded, label: 'Активные заказы', tab: 2),
    (icon: Icons.person_off_rounded, label: 'Заказы без мастера', tab: 2),
    (icon: Icons.handshake_rounded, label: 'На согласовании', tab: 2),
    (icon: Icons.chat_bubble_rounded, label: 'Чаты с клиентами', tab: 4),
    (icon: Icons.badge_rounded, label: 'Персонал', tab: 5),
    (icon: Icons.account_balance_wallet_rounded, label: 'Финансы', tab: 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _links.map((link) {
        return Material(
          color: AppColorsDesktop.surface,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            onTap: () => onNavigate(link.tab),
            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                border: Border.all(color: AppColorsDesktop.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(link.icon, size: 22, color: AppColorsDesktop.primary),
                  const SizedBox(width: 10),
                  Text(
                    link.label,
                    style: DesktopDesignSystem.button.copyWith(
                      color: AppColorsDesktop.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// --- Master stat row (legacy, replaced by _MasterCard) ---
// ignore: unused_element
class _MasterStatRow extends StatelessWidget {
  const _MasterStatRow({required this.stats});

  final _MasterStats stats;

  @override
  Widget build(BuildContext context) {
    const workingDayMinutes = 8 * 60;
    final loadPercent = workingDayMinutes > 0
        ? (stats.occupiedMinutes / workingDayMinutes * 100).clamp(0.0, 100.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesktopDesignSystem.cardPadding,
        vertical: 12,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.12),
            child: Text(
              stats.masterName.isNotEmpty ? stats.masterName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColorsDesktop.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.masterName,
                  style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600),
                ),
                if (stats.roleLabel != null && stats.roleLabel!.isNotEmpty)
                  Text(
                    stats.roleLabel!,
                    style: DesktopDesignSystem.meta,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${stats.orderCount} зак.', style: DesktopDesignSystem.bodySecondary),
                Text(
                  '${stats.occupiedMinutes ~/ 60}ч ${stats.occupiedMinutes % 60}м из 8ч',
                  style: DesktopDesignSystem.meta,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMoney(stats.revenueKopecks),
                  style: DesktopDesignSystem.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColorsDesktop.textPrimary,
                  ),
                ),
                if (stats.expectedRevenueKopecks > 0)
                  Text(
                    '+${formatMoney(stats.expectedRevenueKopecks)} ожид.',
                    style: DesktopDesignSystem.meta.copyWith(color: AppColorsDesktop.primary),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: loadPercent / 100,
                minHeight: 8,
                backgroundColor: AppColorsDesktop.nestedBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  loadPercent > 100 ? AppColorsDesktop.error : AppColorsDesktop.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${loadPercent.round()}%',
            style: DesktopDesignSystem.label,
          ),
        ],
      ),
    );
  }
}

// --- Order list tile (desktop) ---

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({required this.order});

  final Order order;

  static Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pendingConfirmation:
        return AppColorsDesktop.statusPending;
      case OrderStatus.confirmed:
        return AppColorsDesktop.statusConfirmed;
      case OrderStatus.inProgress:
        return AppColorsDesktop.statusInProgress;
      case OrderStatus.pendingApproval:
        return AppColorsDesktop.statusApproval;
      case OrderStatus.completed:
      case OrderStatus.done:
        return AppColorsDesktop.statusCompleted;
      case OrderStatus.cancelled:
        return AppColorsDesktop.statusCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAttention = order.status == OrderStatus.pendingConfirmation ||
        order.status == OrderStatus.pendingApproval ||
        order.masterId == null ||
        (order.masterId?.isEmpty ?? true);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: order.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesktopDesignSystem.cardPadding,
          vertical: 10,
        ),
        child: Row(
          children: [
            Text(
              order.orderNumber,
              style: DesktopDesignSystem.body.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                order.carInfo,
                style: DesktopDesignSystem.bodySecondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              order.masterName ?? '—',
              style: DesktopDesignSystem.meta,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(order.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                order.status.label,
                style: TextStyle(
                  fontSize: 12,
                  color: _statusColor(order.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatTimeOrNull(order.dateTime),
              style: DesktopDesignSystem.meta,
            ),
            const SizedBox(width: 12),
            Text(
              formatMoney(order.totalKopecks),
              style: DesktopDesignSystem.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColorsDesktop.accentMoney,
              ),
            ),
            if (needsAttention)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppColorsDesktop.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Mobile (legacy) components ---

/// Горизонтальные бары: занятое время по позициям заказа (минуты) за период.
class _MobileMasterLoadBarChart extends StatelessWidget {
  const _MobileMasterLoadBarChart({
    required this.masters,
    required this.periodLabel,
  });

  final List<_MasterStats> masters;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final data = List<_MasterStats>.from(masters)
      ..sort((a, b) => b.occupiedMinutes.compareTo(a.occupiedMinutes));
    final top = data.take(10).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final maxMin = top.map((e) => e.occupiedMinutes).reduce(math.max);
    final denom = math.max(1, maxMin);

    return Card(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stacked_bar_chart_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Загрузка по времени ($periodLabel)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Сумма оценок по работам в заказах (мин.). Дольше полоса — больше занято слотов.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            for (final m in top) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      m.masterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (m.occupiedMinutes / denom).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: AppColors.border.withValues(alpha: 0.35),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      _dashboardFormatOccupiedMinutes(m.occupiedMinutes),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _MasterStatCard extends StatelessWidget {
  final _MasterStats stats;

  const _MasterStatCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                stats.masterName.isNotEmpty ? stats.masterName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.masterName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats.orderCount} заказов • ${_dashboardFormatOccupiedMinutes(stats.occupiedMinutes)} занято • ${formatMoney(stats.revenueKopecks)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool accent;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? AppColors.primary.withValues(alpha: 0.15) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: accent ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: ListTile(
        title: Text(order.orderNumber),
        subtitle: Text('${order.carInfo} • ${formatTimeOrNull(order.dateTime)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: order.status.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            order.status.label,
            style: TextStyle(
              fontSize: 12,
              color: order.status.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ),
      ),
    );
  }
}
