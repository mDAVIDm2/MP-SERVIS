import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/navigation/shell_navigation_provider.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../core/l10n/maintenance_type_l10n.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/settings/car_manual_expenses_provider.dart';
import '../../../../core/settings/car_expense_group_ids.dart';
import '../widgets/add_car_manual_expense_sheet.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/org_business_kind.dart';
import '../analytics/analytics_block_editor_screen.dart';
import '../analytics/analytics_catalog_helper.dart';
import '../analytics/analytics_dashboard_models.dart';
import '../analytics/analytics_export.dart';
import '../analytics/car_expense_analytics.dart';
import '../analytics/domain/analytics_expense_entry.dart';
import '../analytics/domain/analytics_financial_order.dart';
import '../analytics/domain/analytics_global_period.dart';
import '../analytics/data/analytics_expense_aggregator.dart';
import '../analytics/data/analytics_taxonomy_l10n.dart';
import '../analytics/presentation/analytics_all_operations_screen.dart';
import '../analytics/presentation/analytics_expense_drilldown_screens.dart';
import '../analytics/presentation/analytics_hub_charts.dart';
import '../analytics/presentation/analytics_hub_widgets.dart';

Map<String, int> _categoryTotalsForCalendarMonth(
  AppL10n l10n,
  List<Order> financialCar,
  List<MaintenanceRecord> maintCar,
  List<CarManualExpenseRecord> manualCar,
  int year,
  int month,
  List<CatalogCategory> catalogCategories,
  List<CatalogServiceItem> catalogItems,
) {
  final map = <String, int>{};
  for (final o in financialCar) {
    if (o.dateTime.year != year || o.dateTime.month != month) continue;
    for (final item in o.itemsForDisplay.where(
      (i) => i.isApproved && !i.isRejected,
    )) {
      final cat = AnalyticsCatalogHelper.labelForOrderItem(
        item,
        categories: catalogCategories,
        catalogLines: catalogItems,
        english: l10n.isEn,
      );
      map[cat] = (map[cat] ?? 0) + item.priceKopecks;
    }
  }
  for (final r in maintCar) {
    if (r.date.year != year || r.date.month != month) continue;
    final p = r.priceKopecks;
    if (p == null || p <= 0) continue;
    final type = MaintenanceType.fromTypeKey(r.typeKey);
    if (type == null) continue;
    final label = type.localizedTitle(l10n);
    map[label] = (map[label] ?? 0) + p;
  }
  for (final m in manualCar) {
    if (m.date.year != year || m.date.month != month) continue;
    final label = m.groupLabelAppL10n(l10n);
    map[label] = (map[label] ?? 0) + m.priceKopecks;
  }
  return map;
}

/// Предрасчёт для главного хаба: один раз сортируем и считаем топ.
class _HubOverview {
  _HubOverview({
    required this.sortedByDateDesc,
    required this.recentFive,
    required this.topRows,
    required this.grandTotalKopecks,
  });

  final List<AnalyticsExpenseEntry> sortedByDateDesc;
  final List<AnalyticsExpenseEntry> recentFive;
  final List<
    ({String groupId, String categoryId, String itemTitle, int sum, int n})
  >
  topRows;
  final int grandTotalKopecks;

  static _HubOverview build(List<AnalyticsExpenseEntry> entries) {
    if (entries.isEmpty) {
      return _HubOverview(
        sortedByDateDesc: const [],
        recentFive: const [],
        topRows: const [],
        grandTotalKopecks: 0,
      );
    }
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    final map =
        <
          String,
          ({
            String groupId,
            String categoryId,
            String itemTitle,
            int sum,
            int n,
          })
        >{};
    for (final e in entries) {
      final item = e.expenseItemTitle.trim().isEmpty
          ? e.title.trim()
          : e.expenseItemTitle.trim();
      final key = '${e.expenseGroupId}|${e.expenseCategoryId}|$item';
      final cur = map[key];
      if (cur == null) {
        map[key] = (
          groupId: e.expenseGroupId,
          categoryId: e.expenseCategoryId,
          itemTitle: item,
          sum: e.totalKopecks,
          n: 1,
        );
      } else {
        map[key] = (
          groupId: cur.groupId,
          categoryId: cur.categoryId,
          itemTitle: cur.itemTitle,
          sum: cur.sum + e.totalKopecks,
          n: cur.n + 1,
        );
      }
    }
    final list = map.values.toList()..sort((a, b) => b.sum.compareTo(a.sum));
    final grand = entries.fold<int>(0, (s, e) => s + e.totalKopecks);
    return _HubOverview(
      sortedByDateDesc: sorted,
      recentFive: sorted.take(5).toList(),
      topRows: list.take(5).toList(),
      grandTotalKopecks: grand,
    );
  }
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _lastCenteredCarId;
  bool _prefsLoaded = false;
  AnalyticsGlobalPeriod _globalPeriod = const AnalyticsGlobalPeriod();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cars = ref.read(carsProvider).valueOrNull;
      if (cars == null || cars.isEmpty) return;
      unawaited(
        ref
            .read(carManualExpensesProvider.notifier)
            .syncGarageAndManual(cars.map((c) => c.id).toList()),
      );
    });
  }

  /// Каждый элемент — отдельная диаграмма со своими параметрами (сохраняется в [AnalyticsDashboardStorage]).
  List<AnalyticsBlockConfig> _blocks = [];

  Future<void> _loadPrefs() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!mounted) return;
    final blocks = await AnalyticsDashboardStorage.load(prefs);
    final globalPeriod = await AnalyticsGlobalPeriodStorage.load(prefs);
    setState(() {
      _blocks = blocks.isEmpty
          ? [AnalyticsBlockConfig(id: 'default_1')]
          : blocks;
      _globalPeriod = globalPeriod;
      _prefsLoaded = true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await AnalyticsDashboardStorage.save(prefs, _blocks);
  }

  String _chartDisplayLabel(AppL10n l10n, AnalyticsChartDisplay d) {
    return switch (d) {
      AnalyticsChartDisplay.bar => l10n.analyticsChartBars,
      AnalyticsChartDisplay.pie => l10n.analyticsChartPie,
      AnalyticsChartDisplay.table => l10n.analyticsChartTable,
      AnalyticsChartDisplay.spendingList => l10n.analyticsChartSpendingList,
      AnalyticsChartDisplay.fuelConsumptionLine => l10n.analyticsChartFuelLine,
      AnalyticsChartDisplay.tripCostScales => l10n.analyticsChartTripCost,
      AnalyticsChartDisplay.monthCompareCategories =>
        l10n.analyticsChartMonthCompare,
    };
  }

  Future<void> _openAnalyticsBlockEditor(
    BuildContext context,
    AppL10n l10n,
    Car car, {
    int? existingIndex,
  }) async {
    final isNew = existingIndex == null;
    final primary = _blocks.first;
    final initial = isNew
        ? AnalyticsBlockConfig(
            id: 'b_${DateTime.now().millisecondsSinceEpoch}',
            periodMonths: primary.periodMonths,
            groupBy: primary.groupBy,
            display: AnalyticsChartDisplay.pie,
            metric: primary.metric,
            orgKindFilterCode: primary.orgKindFilterCode,
            showLifetimeFuelAverageLine: primary.showLifetimeFuelAverageLine,
          )
        : _blocks[existingIndex].duplicate();

    final orders = ref.read(ordersProvider).valueOrNull ?? [];
    final maintAll = ref.read(maintenanceRemindersProvider).records;
    final manualAll = visibleCarManualExpenses(
      ref.read(carManualExpensesProvider),
    );
    final catalogData = ref.read(catalogServicesProvider(null));
    final catCategories =
        catalogData.valueOrNull?.categories ?? const <CatalogCategory>[];
    final catItems =
        catalogData.valueOrNull?.items ?? const <CatalogServiceItem>[];
    final catalogLoading = catalogData.isLoading;

    final kindCodes = <String>{};
    for (final o in orders.where((o) => o.carId == car.id)) {
      final k = OrgBusinessKind.normalizeCode(o.organizationBusinessKind);
      if (k != null && k.isNotEmpty) kindCodes.add(k);
    }
    final kindList = kindCodes.toList()..sort();

    final result = await Navigator.of(context).push<AnalyticsBlockConfig>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AnalyticsBlockEditorScreen(
          initial: initial,
          filtersCard: (draft, onUpdate) => _FiltersCard(
            l10n: l10n,
            block: draft,
            catalogLoading: catalogLoading,
            kindCodes: kindList,
            chartDisplayLabel: (d) => _chartDisplayLabel(l10n, d),
            onUpdate: onUpdate,
          ),
          preview: (draft) {
            final financialB = _filteredOrders(
              orders,
              car.id,
              draft,
            ).where(_countsFinancial).toList();
            final maintB = _maintenanceRecordsInPeriod(
              maintAll,
              car.id,
              draft.periodMonths,
            );
            final manualB = _carManualRecordsInPeriod(
              manualAll,
              car.id,
              draft.periodMonths,
            );
            final groupsB = _buildGroups(
              l10n,
              financialB,
              groupBy: draft.groupBy,
              catalogCategories: catCategories,
              catalogItems: catItems,
              maintenanceRecordsInPeriod: maintB,
              manualExpensesInPeriod: manualB,
            );
            return _buildMainVisual(
              ctx,
              l10n,
              car,
              orders,
              groupsB,
              draft,
              catCategories,
              catItems,
              maintAll,
              manualAll,
            );
          },
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      if (isNew) {
        _blocks.add(result);
      } else {
        _blocks[existingIndex] = result;
      }
    });
    await _savePrefs();
  }

  DateTime? _rangeStartMonths(int periodMonths) {
    if (periodMonths <= 0) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month - periodMonths, now.day);
  }

  /// Средний расход для подписи под диаграммой «классы трат».
  double? _fuelAvgForExpenseClassFooter(
    AnalyticsBlockConfig block,
    Car car,
    List<CarManualExpenseRecord> manualAll,
  ) {
    if (block.groupBy != AnalyticsGroupBy.expenseClass ||
        block.metric != AnalyticsValueMetric.totalSpend) {
      return null;
    }
    return computeCarFuelRefuelStats(
      manualAll,
      car.id,
      fromInclusive: _rangeStartMonths(block.periodMonths),
    )?.meanLPer100FromIntervals;
  }

  List<MaintenanceRecord> _maintenanceRecordsInPeriod(
    List<MaintenanceRecord> all,
    String carId,
    int periodMonths,
  ) {
    final rangeStart = _rangeStartMonths(periodMonths);
    return all
        .where((r) => r.carId == carId)
        .where((r) => rangeStart == null || !r.date.isBefore(rangeStart))
        .toList();
  }

  List<CarManualExpenseRecord> _carManualRecordsInPeriod(
    List<CarManualExpenseRecord> all,
    String carId,
    int periodMonths,
  ) {
    final rangeStart = _rangeStartMonths(periodMonths);
    return all
        .where((r) => r.carId == carId)
        .where((r) => rangeStart == null || !r.date.isBefore(rangeStart))
        .toList();
  }

  List<Order> _filteredOrders(
    List<Order> orders,
    String carId,
    AnalyticsBlockConfig block,
  ) {
    final start = _rangeStartMonths(block.periodMonths);
    var list = orders.where((o) => o.carId == carId).toList();
    if (start != null) {
      list = list.where((o) => !o.dateTime.isBefore(start)).toList();
    }
    if (block.orgKindFilterCode != null &&
        block.orgKindFilterCode!.isNotEmpty) {
      final want =
          OrgBusinessKind.normalizeCode(block.orgKindFilterCode) ??
          block.orgKindFilterCode;
      list = list.where((o) {
        final g = OrgBusinessKind.normalizeCode(o.organizationBusinessKind);
        return g == want;
      }).toList();
    }
    return list;
  }

  static bool _countsFinancial(Order o) => isCompletedFinancialOrder(o);

  List<CarManualExpenseRecord> _carManualRecordsInGlobalPeriod(
    List<CarManualExpenseRecord> all,
    String carId,
    AnalyticsGlobalPeriod period,
  ) {
    final now = DateTime.now();
    final start = period.rangeStartInclusive(now);
    final end = period.rangeEndInclusive(now);
    return all.where((r) => r.carId == carId).where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (start != null) {
        final s = DateTime(start.year, start.month, start.day);
        if (d.isBefore(s)) return false;
      }
      if (end != null && r.date.isAfter(end)) return false;
      return true;
    }).toList();
  }

  String _globalPeriodLabel(AppL10n l10n, DateTime now) {
    switch (_globalPeriod.preset) {
      case AnalyticsPeriodPreset.thisMonth:
        return l10n.analyticsPeriodThisMonth;
      case AnalyticsPeriodPreset.lastMonth:
        return l10n.analyticsPeriodLastMonth;
      case AnalyticsPeriodPreset.last3Months:
        return l10n.analyticsPeriodChipMonths(3);
      case AnalyticsPeriodPreset.last6Months:
        return l10n.analyticsPeriodChipMonths(6);
      case AnalyticsPeriodPreset.last12Months:
        return l10n.analyticsPeriodChipMonths(12);
      case AnalyticsPeriodPreset.allTime:
        return l10n.analyticsKpiPeriodAll();
      case AnalyticsPeriodPreset.custom:
        final a = _globalPeriod.customStart;
        final b = _globalPeriod.customEnd;
        if (a != null && b != null) {
          return l10n.analyticsPeriodCustomRange(
            DateFormat('d.MM.yyyy', l10n.intlLocale).format(a),
            DateFormat('d.MM.yyyy', l10n.intlLocale).format(b),
          );
        }
        return l10n.analyticsPeriodCustom;
    }
  }

  int _monthsDenominatorForGlobal(
    List<AnalyticsExpenseEntry> entries,
    DateTime now,
  ) {
    switch (_globalPeriod.preset) {
      case AnalyticsPeriodPreset.thisMonth:
      case AnalyticsPeriodPreset.lastMonth:
        return 1;
      case AnalyticsPeriodPreset.last3Months:
        return 3;
      case AnalyticsPeriodPreset.last6Months:
        return 6;
      case AnalyticsPeriodPreset.last12Months:
        return 12;
      case AnalyticsPeriodPreset.allTime:
        final keys = entries
            .map((e) => '${e.date.year}-${e.date.month}')
            .toSet();
        return keys.isEmpty ? 1 : math.max(1, keys.length);
      case AnalyticsPeriodPreset.custom:
        final a = _globalPeriod.customStart;
        final b = _globalPeriod.customEnd ?? now;
        if (a == null) return 1;
        return math.max(1, (b.year - a.year) * 12 + (b.month - a.month) + 1);
    }
  }

  Future<void> _pickGlobalCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final initialStart =
        _globalPeriod.customStart ?? DateTime(now.year, now.month);
    final initialEnd = _globalPeriod.customEnd ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.palette.primary,
              onPrimary: context.palette.onAccent,
              surface: context.palette.cardBg,
              onSurface: context.palette.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    final p = AnalyticsGlobalPeriod(
      preset: AnalyticsPeriodPreset.custom,
      customStart: picked.start,
      customEnd: picked.end,
    );
    setState(() => _globalPeriod = p);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await AnalyticsGlobalPeriodStorage.save(prefs, p);
  }

  static int _orderAmount(Order o) => o.totalKopecksForDisplay;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    if (!_prefsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_prefsLoaded) _loadPrefs();
      });
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          backgroundColor: context.palette.background,
          title: Text(
            l10n.analyticsTitle,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cars = ref.watch(carsProvider).valueOrNull ?? [];
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCarIdProvider);
    if (cars.isEmpty) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          backgroundColor: context.palette.background,
          title: Text(
            l10n.analyticsTitle,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AnalyticsEmptyState(
              palette: context.palette,
              icon: Icons.directions_car_outlined,
              title: l10n.analyticsEmptyNoCarsTitle,
              subtitle: l10n.analyticsEmptyNoCarsSubtitle,
              primaryLabel: l10n.analyticsAddCarButton,
              onPrimary: () {
                ref.read(shellTargetTabProvider.notifier).state = 0;
              },
            ),
          ],
        ),
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
        scrollWidgetToViewportCenter(
          GlobalObjectKey(activeCarId).currentContext,
        );
      });
    }
    final car = cars[carIndex];
    final now = DateTime.now();
    final primary = _blocks.first;
    final catalogData = ref.watch(catalogServicesProvider(null));
    final catCategories =
        catalogData.valueOrNull?.categories ?? const <CatalogCategory>[];
    final catItems =
        catalogData.valueOrNull?.items ?? const <CatalogServiceItem>[];
    final maintAll = ref.watch(maintenanceRemindersProvider).records;
    final manualAll = visibleCarManualExpenses(
      ref.watch(carManualExpensesProvider),
    );

    final journalEntries = AnalyticsExpenseAggregator.build(
      l10n: l10n,
      carId: car.id,
      period: _globalPeriod,
      orders: orders,
      manual: manualAll,
      maintenance: maintAll,
      catalogCategories: catCategories,
      catalogItems: catItems,
      now: now,
    );

    final List<AnalyticsExpenseEntry> lifetimeEntries;
    if (journalEntries.isEmpty) {
      lifetimeEntries = AnalyticsExpenseAggregator.build(
        l10n: l10n,
        carId: car.id,
        period: const AnalyticsGlobalPeriod(
          preset: AnalyticsPeriodPreset.allTime,
        ),
        orders: orders,
        manual: manualAll,
        maintenance: maintAll,
        catalogCategories: catCategories,
        catalogItems: catItems,
        now: now,
      );
    } else {
      lifetimeEntries = const [];
    }
    final hasLifetimeSpend =
        journalEntries.isEmpty && lifetimeEntries.isNotEmpty;
    final noSpendEver = journalEntries.isEmpty && lifetimeEntries.isEmpty;

    final hubOverview = journalEntries.isEmpty
        ? null
        : _HubOverview.build(journalEntries);
    final recentTop =
        hubOverview?.recentFive ?? const <AnalyticsExpenseEntry>[];

    final carOrders = _filteredOrders(orders, car.id, primary);
    final financial = carOrders.where(_countsFinancial).toList();
    final maintInPrimary = _maintenanceRecordsInPeriod(
      maintAll,
      car.id,
      primary.periodMonths,
    );
    final manualInPrimary = _carManualRecordsInPeriod(
      manualAll,
      car.id,
      primary.periodMonths,
    );
    final manualInGlobal = _carManualRecordsInGlobalPeriod(
      manualAll,
      car.id,
      _globalPeriod,
    );

    final fuelInGlobal = manualInGlobal.where((r) => r.isFuel).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final fuelRecordsCount = fuelInGlobal.length;
    final fuelWithOdometerCount = fuelInGlobal
        .where((r) => r.odometerKm != null)
        .length;
    final lastFuelRec = fuelInGlobal.isNotEmpty ? fuelInGlobal.first : null;
    final avgFuelPriceLiter = computeFuelAveragePricePerLiterRub(
      manualAll,
      car.id,
      fromInclusive: _globalPeriod.rangeStartInclusive(now),
    );

    final totalKopecks = journalEntries.fold<int>(
      0,
      (s, e) => s + e.totalKopecks,
    );
    final operationCount = journalEntries.length;
    final avgCheck = operationCount > 0 ? totalKopecks ~/ operationCount : 0;
    final monthsForAvg = _monthsDenominatorForGlobal(journalEntries, now);
    final avgMonthly = monthsForAvg > 0 ? totalKopecks ~/ monthsForAvg : 0;

    final groupOrder = CarExpenseGroupIds.ordered;
    final groupTotals = <String, int>{for (final id in groupOrder) id: 0};
    for (final e in journalEntries) {
      groupTotals[e.expenseGroupId] =
          (groupTotals[e.expenseGroupId] ?? 0) + e.totalKopecks;
    }
    final donutIds = groupOrder
        .where((id) => (groupTotals[id] ?? 0) > 0)
        .toList();
    final donutAmounts = donutIds.map((id) => groupTotals[id]!).toList();

    final fuelStatsGlobal = computeCarFuelRefuelStats(
      manualAll,
      car.id,
      fromInclusive: _globalPeriod.rangeStartInclusive(now),
    );

    final primaryGroups = _buildGroups(
      l10n,
      financial,
      groupBy: primary.groupBy,
      catalogCategories: catCategories,
      catalogItems: catItems,
      maintenanceRecordsInPeriod: maintInPrimary,
      manualExpensesInPeriod: manualInPrimary,
    );
    final primaryExportValues = primaryGroups
        .map((g) => _bucketValue(g, primary))
        .toList();

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(
          l10n.analyticsTitle,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (journalEntries.isNotEmpty || primaryGroups.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: l10n.analyticsExportMenuTitle,
              icon: Icon(
                Icons.ios_share_rounded,
                color: context.palette.textPrimary,
              ),
              onSelected: (v) async {
                switch (v) {
                  case 'journal':
                    if (journalEntries.isNotEmpty) {
                      await AnalyticsExport.shareJournal(
                        l10n: l10n,
                        carLabel: '${car.brand} ${car.model}',
                        periodDescription: _globalPeriodLabel(l10n, now),
                        entries: journalEntries,
                      );
                    }
                    break;
                  case 'groups':
                    if (journalEntries.isNotEmpty) {
                      await AnalyticsExport.shareGroupSummary(
                        l10n: l10n,
                        carLabel: '${car.brand} ${car.model}',
                        periodDescription: _globalPeriodLabel(l10n, now),
                        entries: journalEntries,
                      );
                    }
                    break;
                  case 'cats':
                    if (journalEntries.isNotEmpty) {
                      await AnalyticsExport.shareCategorySummary(
                        l10n: l10n,
                        carLabel: '${car.brand} ${car.model}',
                        periodDescription: _globalPeriodLabel(l10n, now),
                        entries: journalEntries,
                      );
                    }
                    break;
                  case 'fuel':
                    if (journalEntries.isNotEmpty) {
                      await AnalyticsExport.shareFuel(
                        l10n: l10n,
                        carLabel: '${car.brand} ${car.model}',
                        periodDescription: _globalPeriodLabel(l10n, now),
                        entries: journalEntries,
                      );
                    }
                    break;
                  case 'table':
                    if (primaryGroups.isNotEmpty) {
                      await _shareAnalyticsTable(
                        context,
                        l10n,
                        carLabel: '${car.brand} ${car.model}',
                        groups: primaryGroups,
                        values: primaryExportValues,
                        block: primary,
                      );
                    }
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (journalEntries.isNotEmpty)
                  PopupMenuItem(
                    value: 'journal',
                    child: Text(l10n.analyticsExportAllOperations),
                  ),
                if (journalEntries.isNotEmpty)
                  PopupMenuItem(
                    value: 'groups',
                    child: Text(l10n.analyticsExportGroups),
                  ),
                if (journalEntries.isNotEmpty)
                  PopupMenuItem(
                    value: 'cats',
                    child: Text(l10n.analyticsExportCategories),
                  ),
                if (journalEntries.isNotEmpty)
                  PopupMenuItem(
                    value: 'fuel',
                    child: Text(l10n.analyticsExportFuel),
                  ),
                if (primaryGroups.isNotEmpty)
                  PopupMenuItem(
                    value: 'table',
                    child: Text(l10n.analyticsExportCurrentChart),
                  ),
              ],
            ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cars.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = cars[i];
                final isSelected = i == carIndex;
                return GestureDetector(
                  key: GlobalObjectKey(c.id),
                  onTap: () =>
                      ref.read(selectedCarIdProvider.notifier).set(c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.palette.primary
                          : context.palette.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? context.palette.primary
                            : context.palette.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${c.brand} ${c.model}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? context.palette.onAccent
                            : context.palette.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          AnalyticsHubPeriodRow(
            l10n: l10n,
            palette: context.palette,
            period: _globalPeriod,
            onChanged: (p) async {
              setState(() => _globalPeriod = p);
              final prefs = await ref.read(sharedPreferencesProvider.future);
              await AnalyticsGlobalPeriodStorage.save(prefs, p);
            },
            onPickCustomRange: () => _pickGlobalCustomRange(context),
          ),
          const SizedBox(height: 12),
          AnalyticsHubQuickActions(
            l10n: l10n,
            palette: context.palette,
            onFuel: () => showAddCarManualExpenseSheet(
              context,
              ref,
              car: car,
              startWithFuel: true,
            ),
            onExpense: () => showAddCarManualExpenseSheet(
              context,
              ref,
              car: car,
              startWithFuel: false,
            ),
            onAll: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AnalyticsAllOperationsScreen(
                    car: car,
                    entries: journalEntries,
                    periodDescription: _globalPeriodLabel(l10n, now),
                  ),
                ),
              );
            },
          ),
          if (noSpendEver) ...[
            const SizedBox(height: 8),
            AnalyticsEmptyState(
              palette: context.palette,
              icon: Icons.receipt_long_outlined,
              title: l10n.analyticsEmptyNoExpensesTitle,
              subtitle: l10n.analyticsEmptyNoExpensesSubtitle,
              primaryLabel: l10n.analyticsQuickFuel,
              onPrimary: () => showAddCarManualExpenseSheet(
                context,
                ref,
                car: car,
                startWithFuel: true,
              ),
              secondaryLabel: l10n.analyticsQuickExpense,
              onSecondary: () => showAddCarManualExpenseSheet(
                context,
                ref,
                car: car,
                startWithFuel: false,
              ),
            ),
          ] else if (hasLifetimeSpend) ...[
            const SizedBox(height: 8),
            AnalyticsEmptyState(
              palette: context.palette,
              icon: Icons.date_range_outlined,
              title: l10n.analyticsEmptyNoPeriodExpensesTitle,
              subtitle: l10n.analyticsEmptyNoPeriodExpensesSubtitle,
              extra: Center(
                child: ActionChip(
                  label: Text(l10n.analyticsEmptyShowAllTime),
                  onPressed: () async {
                    final p = const AnalyticsGlobalPeriod(
                      preset: AnalyticsPeriodPreset.allTime,
                    );
                    setState(() => _globalPeriod = p);
                    final prefs = await ref.read(
                      sharedPreferencesProvider.future,
                    );
                    await AnalyticsGlobalPeriodStorage.save(prefs, p);
                  },
                ),
              ),
              primaryLabel: l10n.analyticsQuickExpense,
              onPrimary: () => showAddCarManualExpenseSheet(
                context,
                ref,
                car: car,
                startWithFuel: false,
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            AnalyticsHubHeroCard(
              l10n: l10n,
              palette: context.palette,
              periodLabel: _globalPeriodLabel(l10n, now),
              totalKopecks: totalKopecks,
              operationCount: operationCount,
              avgCheckKopecks: avgCheck,
              avgMonthlyKopecks: avgMonthly,
              fuelMedianL100: fuelStatsGlobal?.medianLPer100FromIntervals,
              fuelMedianKpk: fuelStatsGlobal?.medianKopecksPerKm,
              fuelExactMethod: fuelStatsGlobal?.usedFullTankIntervals,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: context.palette.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              child: AnalyticsHubDonutSummary(
                l10n: l10n,
                palette: context.palette,
                groupIds: donutIds,
                amounts: donutAmounts,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AnalyticsExpenseGroupsScreen(
                        car: car,
                        entries: journalEntries,
                        periodDescription: _globalPeriodLabel(l10n, now),
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.account_tree_outlined,
                  color: context.palette.primary,
                ),
                label: Text(
                  l10n.analyticsHubOpenCategories,
                  style: TextStyle(color: context.palette.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.palette.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              child: AnalyticsHubSpendStackChart(
                l10n: l10n,
                palette: context.palette,
                entries: journalEntries,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.palette.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.palette.border),
              ),
              child: AnalyticsHubTopItemsCard(
                l10n: l10n,
                palette: context.palette,
                entries: journalEntries,
                precomputedTopRows: hubOverview!.topRows,
                totalSpendKopecksOverride: hubOverview.grandTotalKopecks,
                onOpenItem: (gid, cid, item) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AnalyticsExpenseItemHistoryScreen(
                        car: car,
                        entries: journalEntries,
                        groupId: gid,
                        categoryId: cid,
                        itemTitle: item,
                        periodDescription: _globalPeriodLabel(l10n, now),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            AnalyticsHubFuelCard(
              l10n: l10n,
              palette: context.palette,
              fuelStats: fuelStatsGlobal,
              fuelRecordsCount: fuelRecordsCount,
              fuelWithOdometerCount: fuelWithOdometerCount,
              avgPricePerLiterRub: avgFuelPriceLiter,
              lastFuelDate: lastFuelRec?.date,
              lastFuelStation: lastFuelRec?.fuelStationName,
              onDetails: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnalyticsAllOperationsScreen(
                      car: car,
                      entries: journalEntries,
                      periodDescription: _globalPeriodLabel(l10n, now),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              l10n.analyticsRecentOpsTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (recentTop.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l10n.analyticsAllOpsEmptySubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textSecondary,
                    height: 1.35,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTop.length,
                itemBuilder: (ctx, i) {
                  final e = recentTop[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _JournalMiniTile(l10n: l10n, entry: e),
                  );
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AnalyticsAllOperationsScreen(
                        car: car,
                        entries: journalEntries,
                        periodDescription: _globalPeriodLabel(l10n, now),
                      ),
                    ),
                  );
                },
                child: Text(l10n.analyticsRecentOpsSeeAll),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                l10n.analyticsAdditionalChartsTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              children: [
                if (journalEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnalyticsHubMonthCompareCard(
                          l10n: l10n,
                          palette: context.palette,
                          entries: journalEntries,
                          now: now,
                        ),
                        const SizedBox(height: 16),
                        AnalyticsHubSummaryTableCard(
                          l10n: l10n,
                          palette: context.palette,
                          entries: journalEntries,
                        ),
                      ],
                    ),
                  ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _blocks.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final t = _blocks.removeAt(oldIndex);
                      _blocks.insert(newIndex, t);
                    });
                    _savePrefs();
                  },
                  itemBuilder: (context, blockIndex) {
                    final block = _blocks[blockIndex];
                    final maintAllRows = ref
                        .read(maintenanceRemindersProvider)
                        .records;
                    final manualAllRows = visibleCarManualExpenses(
                      ref.read(carManualExpensesProvider),
                    );
                    final financialB = _filteredOrders(
                      orders,
                      car.id,
                      block,
                    ).where(_countsFinancial).toList();
                    final maintB = _maintenanceRecordsInPeriod(
                      maintAllRows,
                      car.id,
                      block.periodMonths,
                    );
                    final manualB = _carManualRecordsInPeriod(
                      manualAllRows,
                      car.id,
                      block.periodMonths,
                    );
                    final groupsB = _buildGroups(
                      l10n,
                      financialB,
                      groupBy: block.groupBy,
                      catalogCategories: catCategories,
                      catalogItems: catItems,
                      maintenanceRecordsInPeriod: maintB,
                      manualExpensesInPeriod: manualB,
                    );
                    final exportValsB = groupsB
                        .map((g) => _bucketValue(g, block))
                        .toList();
                    final standaloneChart = switch (block.display) {
                      AnalyticsChartDisplay.fuelConsumptionLine => true,
                      AnalyticsChartDisplay.tripCostScales => true,
                      AnalyticsChartDisplay.monthCompareCategories => true,
                      _ => false,
                    };
                    final showEmptyFilterHint =
                        !standaloneChart && groupsB.isEmpty;
                    return Material(
                      key: ValueKey<String>(block.id),
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ReorderableDragStartListener(
                                  index: blockIndex,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      right: 4,
                                      top: 2,
                                    ),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: context.palette.textTertiary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _blocks.length > 1
                                        ? '${l10n.analyticsDataSection} · ${blockIndex + 1}'
                                        : l10n.analyticsDataSection,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: context.palette.textPrimary,
                                    ),
                                  ),
                                ),
                                if (groupsB.isNotEmpty)
                                  IconButton(
                                    tooltip: l10n.analyticsExportTooltip,
                                    onPressed: () => _shareAnalyticsTable(
                                      context,
                                      l10n,
                                      carLabel: '${car.brand} ${car.model}',
                                      groups: groupsB,
                                      values: exportValsB,
                                      block: block,
                                    ),
                                    icon: Icon(
                                      Icons.ios_share_rounded,
                                      size: 22,
                                      color: context.palette.textPrimary,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: l10n.analyticsEditChartBlock,
                                  onPressed: () => _openAnalyticsBlockEditor(
                                    context,
                                    l10n,
                                    car,
                                    existingIndex: blockIndex,
                                  ),
                                  icon: Icon(
                                    Icons.tune_rounded,
                                    size: 22,
                                    color: context.palette.textPrimary,
                                  ),
                                ),
                                if (_blocks.length > 1)
                                  IconButton(
                                    tooltip: l10n.analyticsRemoveChartBlock,
                                    onPressed: () {
                                      setState(
                                        () => _blocks.removeAt(blockIndex),
                                      );
                                      _savePrefs();
                                    },
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: context.palette.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.analyticsTapChartToConfigure,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.palette.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (showEmptyFilterHint)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  l10n.analyticsNoOrdersFiltered,
                                  style: TextStyle(
                                    color: context.palette.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _openAnalyticsBlockEditor(
                                    context,
                                    l10n,
                                    car,
                                    existingIndex: blockIndex,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: _buildMainVisual(
                                      context,
                                      l10n,
                                      car,
                                      orders,
                                      groupsB,
                                      block,
                                      catCategories,
                                      catItems,
                                      maintAllRows,
                                      manualAllRows,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _openAnalyticsBlockEditor(context, l10n, car),
                    icon: Icon(
                      Icons.add_chart_rounded,
                      color: context.palette.primary,
                    ),
                    label: Text(
                      l10n.analyticsAddChartBlock,
                      style: TextStyle(color: context.palette.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.analyticsOrdersSection,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...carOrders.map((o) => _HistoryRow(order: o)),
        ],
      ),
    );
  }

  List<_GroupBucket> _buildGroups(
    AppL10n l10n,
    List<Order> financial, {
    required AnalyticsGroupBy groupBy,
    List<CatalogCategory> catalogCategories = const [],
    List<CatalogServiceItem> catalogItems = const [],
    List<MaintenanceRecord> maintenanceRecordsInPeriod = const [],
    List<CarManualExpenseRecord> manualExpensesInPeriod = const [],
  }) {
    switch (groupBy) {
      case AnalyticsGroupBy.month:
        final orderMap = <String, List<Order>>{};
        for (final o in financial) {
          final k =
              '${o.dateTime.year}-${o.dateTime.month.toString().padLeft(2, '0')}';
          orderMap.putIfAbsent(k, () => []).add(o);
        }
        final monthManual = <String, ({int k, int n})>{};
        for (final m in manualExpensesInPeriod) {
          final k = '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}';
          final cur = monthManual[k];
          if (cur == null) {
            monthManual[k] = (k: m.priceKopecks, n: 1);
          } else {
            monthManual[k] = (k: cur.k + m.priceKopecks, n: cur.n + 1);
          }
        }
        final allKeys = {...orderMap.keys, ...monthManual.keys}.toList()
          ..sort();
        return allKeys
            .map(
              (k) => _GroupBucket(
                label: _monthLabel(k, l10n),
                sortKey: k,
                orders: orderMap[k] ?? const [],
                additiveKopecks: monthManual[k]?.k ?? 0,
                additiveCount: monthManual[k]?.n ?? 0,
              ),
            )
            .toList();
      case AnalyticsGroupBy.orgKind:
        final map = <String, List<Order>>{};
        for (final o in financial) {
          final raw = o.organizationBusinessKind;
          final code = (raw != null && raw.trim().isNotEmpty)
              ? raw.trim().toLowerCase().replaceAll('-', '_')
              : '';
          final label = code.isEmpty
              ? l10n.analyticsOrgKindUnknown
              : (OrgBusinessKind.labelForOrderSnapshot(
                      code,
                      english: l10n.isEn,
                    ).isEmpty
                    ? code
                    : OrgBusinessKind.labelForOrderSnapshot(
                        code,
                        english: l10n.isEn,
                      ));
          map.putIfAbsent(label, () => []).add(o);
        }
        var manualK = 0;
        var manualN = 0;
        for (final m in manualExpensesInPeriod) {
          manualK += m.priceKopecks;
          manualN++;
        }
        final entries = map.entries.toList()
          ..sort(
            (a, b) => _groupValue(b.value).compareTo(_groupValue(a.value)),
          );
        final out = entries
            .map(
              (e) =>
                  _GroupBucket(label: e.key, sortKey: e.key, orders: e.value),
            )
            .toList();
        if (manualK > 0) {
          out.add(
            _GroupBucket(
              label: l10n.analyticsManualOrgKindGroup,
              sortKey: '\u0000manual',
              orders: const [],
              additiveKopecks: manualK,
              additiveCount: manualN,
            ),
          );
        }
        return out;
      case AnalyticsGroupBy.serviceCategory:
        final map = <String, int>{};
        final counts = <String, int>{};
        for (final o in financial) {
          for (final item in o.itemsForDisplay.where(
            (i) => i.isApproved && !i.isRejected,
          )) {
            final cat = AnalyticsCatalogHelper.labelForOrderItem(
              item,
              categories: catalogCategories,
              catalogLines: catalogItems,
              english: l10n.isEn,
            );
            map[cat] = (map[cat] ?? 0) + item.priceKopecks;
            counts[cat] = (counts[cat] ?? 0) + 1;
          }
        }
        for (final r in maintenanceRecordsInPeriod) {
          final p = r.priceKopecks;
          if (p == null || p <= 0) continue;
          final type = MaintenanceType.fromTypeKey(r.typeKey);
          if (type == null) continue;
          final label = type.localizedTitle(l10n);
          map[label] = (map[label] ?? 0) + p;
          counts[label] = (counts[label] ?? 0) + 1;
        }
        for (final m in manualExpensesInPeriod) {
          final label = m.groupLabelAppL10n(l10n);
          map[label] = (map[label] ?? 0) + m.priceKopecks;
          counts[label] = (counts[label] ?? 0) + 1;
        }
        final entries = map.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return entries
            .map(
              (e) => _GroupBucket(
                label: e.key,
                sortKey: e.key,
                orders: const [],
                extraKopecks: e.value,
                lineCount: counts[e.key] ?? 0,
              ),
            )
            .toList();
      case AnalyticsGroupBy.expenseClass:
        final map = <String, int>{};
        final counts = <String, int>{};
        for (final id in CarExpenseGroupIds.ordered) {
          map[id] = 0;
          counts[id] = 0;
        }
        for (final o in financial) {
          for (final item in o.itemsForDisplay.where(
            (i) => i.isApproved && !i.isRejected,
          )) {
            final g = CarExpenseClassifier.groupForOrderItem(
              item,
              categories: catalogCategories,
              catalogItems: catalogItems,
            );
            map[g] = (map[g] ?? 0) + item.priceKopecks;
            counts[g] = (counts[g] ?? 0) + 1;
          }
        }
        for (final r in maintenanceRecordsInPeriod) {
          final p = r.priceKopecks;
          if (p == null || p <= 0) continue;
          final g = CarExpenseGroupIds.maintenance;
          map[g] = (map[g] ?? 0) + p;
          counts[g] = (counts[g] ?? 0) + 1;
        }
        for (final m in manualExpensesInPeriod) {
          final g = CarExpenseClassifier.groupForManual(m);
          map[g] = (map[g] ?? 0) + m.priceKopecks;
          counts[g] = (counts[g] ?? 0) + 1;
        }
        return CarExpenseGroupIds.ordered
            .map(
              (id) => _GroupBucket(
                label: l10n.carExpenseClassGroupTitle(id),
                sortKey: id,
                orders: const [],
                extraKopecks: map[id] ?? 0,
                lineCount: counts[id] ?? 0,
              ),
            )
            .toList();
    }
  }

  String _monthLabel(String yyyymm, AppL10n l10n) {
    final parts = yyyymm.split('-');
    if (parts.length != 2) return yyyymm;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return yyyymm;
    return DateFormat('MMM yyyy', l10n.intlLocale).format(DateTime(y, m));
  }

  int _groupValue(List<Order> list) =>
      list.fold<int>(0, (s, o) => s + _orderAmount(o));

  int _bucketValue(_GroupBucket b, AnalyticsBlockConfig block) {
    if (block.groupBy == AnalyticsGroupBy.serviceCategory &&
        b.extraKopecks != null) {
      final denom = block.periodMonths <= 0
          ? 1
          : math.max(1, block.periodMonths);
      return switch (block.metric) {
        AnalyticsValueMetric.totalSpend => b.extraKopecks!,
        AnalyticsValueMetric.orderCount => b.lineCount ?? 0,
        AnalyticsValueMetric.avgCheck =>
          (b.lineCount ?? 0) > 0 ? b.extraKopecks! ~/ (b.lineCount ?? 1) : 0,
        AnalyticsValueMetric.avgMonthlySpend => b.extraKopecks! ~/ denom,
      };
    }
    if (block.groupBy == AnalyticsGroupBy.expenseClass &&
        b.extraKopecks != null) {
      final denom = block.periodMonths <= 0
          ? 1
          : math.max(1, block.periodMonths);
      return switch (block.metric) {
        AnalyticsValueMetric.totalSpend => b.extraKopecks!,
        AnalyticsValueMetric.orderCount => b.lineCount ?? 0,
        AnalyticsValueMetric.avgCheck =>
          (b.lineCount ?? 0) > 0 ? b.extraKopecks! ~/ (b.lineCount ?? 1) : 0,
        AnalyticsValueMetric.avgMonthlySpend => b.extraKopecks! ~/ denom,
      };
    }
    final list = b.orders;
    final orderSum = list.fold<int>(0, (s, o) => s + _orderAmount(o));
    final sum = orderSum + b.additiveKopecks;
    if (sum <= 0 && list.isEmpty) return 0;
    final n = list.length + b.additiveCount;
    final denom = block.periodMonths <= 0 ? 1 : math.max(1, block.periodMonths);
    return switch (block.metric) {
      AnalyticsValueMetric.totalSpend => sum,
      AnalyticsValueMetric.orderCount => n,
      AnalyticsValueMetric.avgCheck => n > 0 ? sum ~/ n : 0,
      AnalyticsValueMetric.avgMonthlySpend => sum ~/ denom,
    };
  }

  Widget _buildMainVisual(
    BuildContext context,
    AppL10n l10n,
    Car car,
    List<Order> allOrders,
    List<_GroupBucket> groups,
    AnalyticsBlockConfig block,
    List<CatalogCategory> catalogCategories,
    List<CatalogServiceItem> catalogItems,
    List<MaintenanceRecord> maintAll,
    List<CarManualExpenseRecord> manualAll,
  ) {
    final palette = context.palette;

    switch (block.display) {
      case AnalyticsChartDisplay.fuelConsumptionLine:
        final statsPeriod = computeCarFuelRefuelStats(
          manualAll,
          car.id,
          fromInclusive: _rangeStartMonths(block.periodMonths),
        );
        final statsAll = computeCarFuelRefuelStats(
          manualAll,
          car.id,
          fromInclusive: null,
        );
        return _FuelConsumptionLineCard(
          l10n: l10n,
          palette: palette,
          stats: statsPeriod,
          lifetimeMeanL100: block.showLifetimeFuelAverageLine
              ? statsAll?.meanLPer100FromIntervals
              : null,
          periodMeanL100: statsPeriod?.meanLPer100FromIntervals,
        );
      case AnalyticsChartDisplay.tripCostScales:
        final stats = computeCarFuelRefuelStats(
          manualAll,
          car.id,
          fromInclusive: _rangeStartMonths(block.periodMonths),
        );
        return _TripCostScalesCard(l10n: l10n, palette: palette, stats: stats);
      case AnalyticsChartDisplay.monthCompareCategories:
        final financial = allOrders
            .where((o) => o.carId == car.id)
            .where(_countsFinancial)
            .toList();
        final maintCar = maintAll.where((r) => r.carId == car.id).toList();
        final manualCar = manualAll.where((r) => r.carId == car.id).toList();
        final now = DateTime.now();
        final cur = _categoryTotalsForCalendarMonth(
          l10n,
          financial,
          maintCar,
          manualCar,
          now.year,
          now.month,
          catalogCategories,
          catalogItems,
        );
        final prevMonth = DateTime(now.year, now.month - 1);
        final prev = _categoryTotalsForCalendarMonth(
          l10n,
          financial,
          maintCar,
          manualCar,
          prevMonth.year,
          prevMonth.month,
          catalogCategories,
          catalogItems,
        );
        return _MonthCompareCategoriesCard(
          l10n: l10n,
          palette: palette,
          thisMonthLabel: DateFormat('MMMM yyyy', l10n.intlLocale).format(now),
          prevMonthLabel: DateFormat(
            'MMMM yyyy',
            l10n.intlLocale,
          ).format(prevMonth),
          thisMonthTotals: cur,
          prevMonthTotals: prev,
        );
      case AnalyticsChartDisplay.bar:
      case AnalyticsChartDisplay.pie:
      case AnalyticsChartDisplay.table:
      case AnalyticsChartDisplay.spendingList:
        break;
    }

    final values = groups.map((g) => _bucketValue(g, block)).toList();
    final maxV = values.isEmpty ? 0 : values.reduce(math.max);
    final colors = [
      palette.primary,
      palette.info,
      palette.success,
      palette.warning,
      palette.error,
      palette.primary.withValues(alpha: 0.55),
    ];

    switch (block.display) {
      case AnalyticsChartDisplay.bar:
        final fuelAvgFoot = _fuelAvgForExpenseClassFooter(
          block,
          car,
          manualAll,
        );
        final barCore = block.groupBy == AnalyticsGroupBy.expenseClass
            ? _ExpenseClassHorizontalBars(
                labels: groups.map((g) => g.label).toList(),
                values: values,
                maxValue: maxV > 0 ? maxV : 1,
                valueLabel: _metricTitle(l10n, block),
                colors: colors,
                palette: palette,
              )
            : _BarHistogram(
                labels: groups.map((g) => g.label).toList(),
                values: values,
                maxValue: maxV > 0 ? maxV : 1,
                valueLabel: _metricTitle(l10n, block),
                colors: colors,
                palette: palette,
              );
        if (fuelAvgFoot == null) return barCore;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            barCore,
            const SizedBox(height: 8),
            Text(
              l10n.analyticsFuelIntervalAvgLegend(fuelAvgFoot),
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        );
      case AnalyticsChartDisplay.pie:
        final fuelAvgFoot = _fuelAvgForExpenseClassFooter(
          block,
          car,
          manualAll,
        );
        final slices = <_PieSlice>[];
        for (var i = 0; i < groups.length; i++) {
          final v = values[i];
          if (v <= 0) continue;
          slices.add(
            _PieSlice(
              label: groups[i].label,
              value: v.toDouble(),
              color: colors[i % colors.length],
            ),
          );
        }
        if (slices.isEmpty) {
          return Text(
            l10n.analyticsPieNoPositive,
            style: TextStyle(color: palette.textSecondary),
          );
        }
        final pieCore = _PieChartCard(
          slices: slices,
          palette: palette,
          holeColor: palette.background,
        );
        if (fuelAvgFoot == null) return pieCore;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pieCore,
            const SizedBox(height: 8),
            Text(
              l10n.analyticsFuelIntervalAvgLegend(fuelAvgFoot),
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        );
      case AnalyticsChartDisplay.table:
        final fuelAvgFootT = _fuelAvgForExpenseClassFooter(
          block,
          car,
          manualAll,
        );
        final tableCore = _AnalyticsDataTable(
          groups: groups,
          values: values,
          metricTitle: _metricTitle(l10n, block),
          groupColumnLabel: l10n.analyticsGroupColumn,
          valueIsMoney: block.metric != AnalyticsValueMetric.orderCount,
          palette: palette,
        );
        if (fuelAvgFootT == null) return tableCore;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tableCore,
            const SizedBox(height: 8),
            Text(
              l10n.analyticsFuelIntervalAvgLegend(fuelAvgFootT),
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        );
      case AnalyticsChartDisplay.spendingList:
        final fuelAvgFootS = _fuelAvgForExpenseClassFooter(
          block,
          car,
          manualAll,
        );
        final listCore = _SpendingListCard(
          groups: groups,
          values: values,
          metricTitle: _metricTitle(l10n, block),
          valueIsMoney: block.metric != AnalyticsValueMetric.orderCount,
          palette: palette,
        );
        if (fuelAvgFootS == null) return listCore;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            listCore,
            const SizedBox(height: 8),
            Text(
              l10n.analyticsFuelIntervalAvgLegend(fuelAvgFootS),
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        );
      case AnalyticsChartDisplay.fuelConsumptionLine:
      case AnalyticsChartDisplay.tripCostScales:
      case AnalyticsChartDisplay.monthCompareCategories:
        return const SizedBox.shrink();
    }
  }

  String _metricTitle(AppL10n l10n, AnalyticsBlockConfig block) {
    return switch (block.metric) {
      AnalyticsValueMetric.totalSpend => l10n.analyticsMetricShortSumRub,
      AnalyticsValueMetric.orderCount => l10n.analyticsMetricShortOrders,
      AnalyticsValueMetric.avgCheck => l10n.analyticsMetricShortAvgRub,
      AnalyticsValueMetric.avgMonthlySpend =>
        l10n.analyticsMetricShortAvgMonthly,
    };
  }

  String _periodExportDescription(AppL10n l10n, AnalyticsBlockConfig block) {
    if (block.periodMonths <= 0) return l10n.analyticsExportPeriodAll;
    return l10n.analyticsExportPeriodLastMonths(block.periodMonths);
  }

  String _groupByExportDescription(AppL10n l10n, AnalyticsBlockConfig block) {
    return switch (block.groupBy) {
      AnalyticsGroupBy.month => l10n.analyticsGroupByMonth,
      AnalyticsGroupBy.orgKind => l10n.analyticsGroupByOrgKind,
      AnalyticsGroupBy.serviceCategory =>
        l10n.analyticsGroupByServiceCategoryHint,
      AnalyticsGroupBy.expenseClass => l10n.analyticsGroupByExpenseClass,
    };
  }

  String _metricExportDescription(AppL10n l10n, AnalyticsBlockConfig block) {
    return switch (block.metric) {
      AnalyticsValueMetric.totalSpend => l10n.analyticsMetricTotalSpend,
      AnalyticsValueMetric.orderCount => l10n.analyticsMetricLongOrderLines,
      AnalyticsValueMetric.avgCheck => l10n.analyticsMetricAvgCheck,
      AnalyticsValueMetric.avgMonthlySpend =>
        l10n.analyticsMetricAvgMonthlyInGroup,
    };
  }

  String? _orgFilterExportDescription(
    AppL10n l10n,
    AnalyticsBlockConfig block,
  ) {
    final c = block.orgKindFilterCode;
    if (c == null || c.trim().isEmpty) return null;
    final label = OrgBusinessKind.labelForOrderSnapshot(c, english: l10n.isEn);
    return label.isEmpty ? c : label;
  }

  Future<void> _shareAnalyticsTable(
    BuildContext context,
    AppL10n l10n, {
    required String carLabel,
    required List<_GroupBucket> groups,
    required List<int> values,
    required AnalyticsBlockConfig block,
  }) async {
    if (groups.isEmpty || values.length != groups.length) return;
    try {
      await AnalyticsExport.shareTable(
        l10n: l10n,
        carLabel: carLabel,
        periodDescription: _periodExportDescription(l10n, block),
        groupByDescription: _groupByExportDescription(l10n, block),
        metricDescription: _metricExportDescription(l10n, block),
        orgFilterDescription: _orgFilterExportDescription(l10n, block),
        groupLabels: groups.map((g) => g.label).toList(),
        values: values,
        valueColumnTitle: _metricTitle(l10n, block),
        valueIsMoney: block.metric != AnalyticsValueMetric.orderCount,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.analyticsExportError(e))));
      }
    }
  }
}

class _GroupBucket {
  const _GroupBucket({
    required this.label,
    required this.sortKey,
    required this.orders,
    this.extraKopecks,
    this.lineCount,
    this.additiveKopecks = 0,
    this.additiveCount = 0,
  });

  final String label;
  final String sortKey;
  final List<Order> orders;
  final int? extraKopecks;

  /// Для группировки по категории: число позиций в каталоге.
  final int? lineCount;

  /// Ручные расходы (заправки и прочее) в bucket: сумма коп. и число операций.
  final int additiveKopecks;
  final int additiveCount;
}

/// Стабильный хэш полей блока графика: при смене любого из них пересобираем
/// [DropdownButtonFormField] с [initialValue], чтобы не использовать deprecated [value].
int _analyticsBlockFiltersRevision(AnalyticsBlockConfig block) => Object.hash(
  block.id,
  block.periodMonths,
  block.orgKindFilterCode ?? '',
  block.groupBy,
  block.metric,
  block.display,
  block.showLifetimeFuelAverageLine,
);

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.l10n,
    required this.block,
    this.catalogLoading = false,
    required this.kindCodes,
    required this.chartDisplayLabel,
    required this.onUpdate,
  });

  final AppL10n l10n;
  final AnalyticsBlockConfig block;
  final bool catalogLoading;
  final List<String> kindCodes;
  final String Function(AnalyticsChartDisplay value) chartDisplayLabel;
  final ValueChanged<AnalyticsBlockConfig> onUpdate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analyticsPeriodLabel,
            style: TextStyle(fontSize: 12, color: p.textTertiary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipSel(
                label: l10n.analyticsPeriodChipMonths(3),
                sel: block.periodMonths == 3,
                onTap: () => onUpdate(block.copyWith(periodMonths: 3)),
              ),
              _ChipSel(
                label: l10n.analyticsPeriodChipMonths(6),
                sel: block.periodMonths == 6,
                onTap: () => onUpdate(block.copyWith(periodMonths: 6)),
              ),
              _ChipSel(
                label: l10n.analyticsPeriodChipMonths(12),
                sel: block.periodMonths == 12,
                onTap: () => onUpdate(block.copyWith(periodMonths: 12)),
              ),
              _ChipSel(
                label: l10n.analyticsAllTimeChip,
                sel: block.periodMonths <= 0,
                onTap: () => onUpdate(block.copyWith(periodMonths: 0)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.analyticsOrgFilterLabel,
            style: TextStyle(fontSize: 12, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            key: ValueKey<String>(
              'org|${block.id}|${_analyticsBlockFiltersRevision(block)}',
            ),
            initialValue: block.orgKindFilterCode,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            hint: Text(l10n.analyticsAllOrgTypes),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.analyticsAllOrgTypes),
              ),
              ...kindCodes.map((c) {
                final label = OrgBusinessKind.labelForOrderSnapshot(
                  c,
                  english: l10n.isEn,
                );
                return DropdownMenuItem<String?>(
                  value: c,
                  child: Text(
                    label.isEmpty ? c : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (v) => onUpdate(
              block.copyWith(orgKindFilterCode: v, clearOrgFilter: v == null),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.analyticsGroupingLabel,
            style: TextStyle(fontSize: 12, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<AnalyticsGroupBy>(
            key: ValueKey<String>(
              'grp|${block.id}|${_analyticsBlockFiltersRevision(block)}',
            ),
            initialValue: block.groupBy,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: AnalyticsGroupBy.month,
                child: Text(
                  l10n.analyticsGroupByMonth,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: AnalyticsGroupBy.orgKind,
                child: Text(
                  l10n.analyticsGroupByOrgKind,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: AnalyticsGroupBy.serviceCategory,
                child: Text(
                  l10n.analyticsGroupByServiceCategory,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: AnalyticsGroupBy.expenseClass,
                child: Text(
                  l10n.analyticsGroupByExpenseClass,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) onUpdate(block.copyWith(groupBy: v));
            },
          ),
          if (catalogLoading &&
              block.groupBy == AnalyticsGroupBy.serviceCategory) ...[
            const SizedBox(height: 8),
            Text(
              l10n.analyticsCatalogLoading,
              style: TextStyle(fontSize: 12, color: p.textTertiary),
            ),
          ],
          if (block.groupBy == AnalyticsGroupBy.expenseClass) ...[
            const SizedBox(height: 8),
            Text(
              l10n.analyticsExpenseClassHistogramHint,
              style: TextStyle(
                fontSize: 12,
                color: p.textTertiary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            l10n.analyticsMetricLabel,
            style: TextStyle(fontSize: 12, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<AnalyticsValueMetric>(
            key: ValueKey<String>(
              'mtr|${block.id}|${_analyticsBlockFiltersRevision(block)}',
            ),
            initialValue: block.metric,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: AnalyticsValueMetric.totalSpend,
                child: Text(l10n.analyticsMetricTotalSpend),
              ),
              DropdownMenuItem(
                value: AnalyticsValueMetric.orderCount,
                child: Text(l10n.analyticsMetricOrderCount),
              ),
              DropdownMenuItem(
                value: AnalyticsValueMetric.avgCheck,
                child: Text(l10n.analyticsMetricAvgCheck),
              ),
              DropdownMenuItem(
                value: AnalyticsValueMetric.avgMonthlySpend,
                child: Text(l10n.analyticsMetricAvgMonthlyInGroup),
              ),
            ],
            onChanged: (v) {
              if (v != null) onUpdate(block.copyWith(metric: v));
            },
          ),
          const SizedBox(height: 14),
          Text(
            l10n.analyticsFormatLabel,
            style: TextStyle(fontSize: 12, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<AnalyticsChartDisplay>(
            key: ValueKey<String>(
              'dsp|${block.id}|${_analyticsBlockFiltersRevision(block)}',
            ),
            initialValue: block.display,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              for (final v in AnalyticsChartDisplay.values)
                DropdownMenuItem(
                  value: v,
                  child: Text(
                    chartDisplayLabel(v),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) onUpdate(block.copyWith(display: v));
            },
          ),
          if (block.display == AnalyticsChartDisplay.fuelConsumptionLine ||
              block.display == AnalyticsChartDisplay.tripCostScales) ...[
            const SizedBox(height: 8),
            Text(
              l10n.analyticsAdvancedFuelChartsHint,
              style: TextStyle(
                fontSize: 12,
                color: p.textTertiary,
                height: 1.35,
              ),
            ),
          ],
          if (block.display == AnalyticsChartDisplay.fuelConsumptionLine) ...[
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.analyticsOptionFuelAvgLine,
                style: TextStyle(fontSize: 14, color: p.textPrimary),
              ),
              subtitle: Text(
                l10n.analyticsOptionFuelAvgLineSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: p.textTertiary,
                  height: 1.35,
                ),
              ),
              value: block.showLifetimeFuelAverageLine,
              onChanged: (v) =>
                  onUpdate(block.copyWith(showLifetimeFuelAverageLine: v)),
            ),
          ],
          if (block.display ==
              AnalyticsChartDisplay.monthCompareCategories) ...[
            const SizedBox(height: 8),
            Text(
              l10n.analyticsMonthCompareHint,
              style: TextStyle(
                fontSize: 12,
                color: p.textTertiary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipSel extends StatelessWidget {
  const _ChipSel({required this.label, required this.sel, required this.onTap});

  final String label;
  final bool sel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: sel ? p.primary.withValues(alpha: 0.2) : p.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sel ? p.primary : p.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalMiniTile extends StatelessWidget {
  const _JournalMiniTile({required this.l10n, required this.entry});

  final AppL10n l10n;
  final AnalyticsExpenseEntry entry;

  String _sourceLabel() {
    return switch (entry.sourceType) {
      AnalyticsExpenseSourceType.order => l10n.analyticsSourceOrder,
      AnalyticsExpenseSourceType.manual => l10n.analyticsSourceManual,
      AnalyticsExpenseSourceType.fuel => l10n.analyticsSourceFuel,
      AnalyticsExpenseSourceType.maintenance => l10n.analyticsSourceMaintenance,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_sourceLabel()} · ${Formatters.dateShortYearRu(entry.date)}',
                    style: TextStyle(fontSize: 11, color: p.textTertiary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.analyticsTaxGroupTitle(entry.expenseGroupId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Formatters.money(entry.totalKopecks),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: p.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingListCard extends StatelessWidget {
  const _SpendingListCard({
    required this.groups,
    required this.values,
    required this.metricTitle,
    required this.valueIsMoney,
    required this.palette,
  });

  final List<_GroupBucket> groups;
  final List<int> values;
  final String metricTitle;
  final bool valueIsMoney;
  final ClientPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            metricTitle,
            style: TextStyle(fontSize: 12, color: palette.textTertiary),
          ),
          const SizedBox(height: 8),
          ...List.generate(groups.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      groups[i].label,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    valueIsMoney ? Formatters.money(values[i]) : '${values[i]}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ExpenseClassHorizontalBars extends StatelessWidget {
  const _ExpenseClassHorizontalBars({
    required this.labels,
    required this.values,
    required this.maxValue,
    required this.valueLabel,
    required this.colors,
    required this.palette,
  });

  final List<String> labels;
  final List<int> values;
  final int maxValue;
  final String valueLabel;
  final List<Color> colors;
  final ClientPalette palette;

  @override
  Widget build(BuildContext context) {
    final maxV = maxValue <= 0 ? 1 : maxValue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valueLabel,
            style: TextStyle(fontSize: 12, color: palette.textTertiary),
          ),
          const SizedBox(height: 14),
          ...List.generate(labels.length, (i) {
            final v = values[i];
            final w = (v / maxV).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.money(v),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final totalW = c.maxWidth;
                      return Stack(
                        children: [
                          Container(
                            height: 14,
                            width: totalW,
                            decoration: BoxDecoration(
                              color: palette.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          AnimatedContainer(
                            duration: Duration(milliseconds: 260 + i * 30),
                            height: 14,
                            width: math.max(4.0, totalW * w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                colors: [
                                  colors[i % colors.length],
                                  colors[i % colors.length].withValues(
                                    alpha: 0.55,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FuelConsumptionLineCard extends StatelessWidget {
  const _FuelConsumptionLineCard({
    required this.l10n,
    required this.palette,
    required this.stats,
    this.lifetimeMeanL100,
    this.periodMeanL100,
  });

  final AppL10n l10n;
  final ClientPalette palette;
  final CarFuelRefuelStats? stats;

  /// Среднее по всем интервалам (горизонтальная пунктирная линия).
  final double? lifetimeMeanL100;

  /// Среднее только по точкам на графике (выбранный период).
  final double? periodMeanL100;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    final spotDates = <DateTime>[];
    final spotIntervals =
        <
          ({
            CarManualExpenseRecord a,
            CarManualExpenseRecord b,
            double? lPer100,
            int? kopecksPerKm,
          })
        >[];
    if (stats != null) {
      var i = 0.0;
      for (final iv in stats!.intervals) {
        final y = iv.lPer100;
        if (y == null) continue;
        spots.add(FlSpot(i, y));
        spotDates.add(iv.b.date);
        spotIntervals.add(iv);
        i += 1;
      }
    }
    if (spots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          l10n.analyticsFuelChartEmpty,
          style: TextStyle(color: palette.textSecondary),
        ),
      );
    }
    final ys = spots.map((s) => s.y).toList();
    var yMin = ys.reduce(math.min);
    var yMax = ys.reduce(math.max);
    final pad = math.max(0.4, (yMax - yMin) * 0.12);
    yMin = (yMin - pad).clamp(0.0, 500.0);
    yMax = yMax + pad;
    final life = lifetimeMeanL100;
    if (life != null) {
      yMax = math.max(yMax, life + pad * 0.5);
      yMin = math.min(yMin, math.max(0.0, life - pad * 0.5));
    }
    final maxX = spots.map((s) => s.x).reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.analyticsFuelChartTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          if (periodMeanL100 != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.analyticsFuelIntervalAvgLegend(periodMeanL100!),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: math.max(1, maxX),
                minY: yMin,
                maxY: yMax,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (life != null)
                      HorizontalLine(
                        y: life,
                        color: palette.warning.withValues(alpha: 0.9),
                        strokeWidth: 2,
                        dashArray: [7, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 6, bottom: 4),
                          style: TextStyle(
                            fontSize: 10,
                            color: palette.warning,
                            fontWeight: FontWeight.w700,
                          ),
                          labelResolver: (line) =>
                              l10n.analyticsFuelLifetimeAvgLine(line.y),
                        ),
                      ),
                  ],
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(
                    0.5,
                    ((yMax - yMin) / 4).clamp(0.5, 50.0),
                  ),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: palette.border.withValues(alpha: 0.45),
                    strokeWidth: 1,
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final idx = s.x.round().clamp(
                          0,
                          spotIntervals.length - 1,
                        );
                        if (idx < 0 || idx >= spotIntervals.length) {
                          return null;
                        }
                        final iv = spotIntervals[idx];
                        final l100 = iv.lPer100;
                        if (l100 == null) return null;
                        final oa = iv.a.odometerKm;
                        final ob = iv.b.odometerKm;
                        final km = (oa != null && ob != null)
                            ? (ob - oa)
                            : null;
                        final body = km != null
                            ? '${l100.toStringAsFixed(1)} л/100 · $km км'
                            : '${l100.toStringAsFixed(1)} л/100';
                        return LineTooltipItem(
                          body,
                          TextStyle(
                            color: palette.cardBg,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, m) => Text(
                        v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1),
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, m) {
                        final idx = v.round();
                        if (idx < 0 || idx >= spotDates.length) {
                          return const SizedBox.shrink();
                        }
                        final dt = spotDates[idx];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('d.MM', l10n.intlLocale).format(dt),
                            style: TextStyle(
                              fontSize: 9,
                              color: palette.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: palette.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                        radius: 4,
                        color: palette.primary,
                        strokeWidth: 1.5,
                        strokeColor: palette.cardBg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.analyticsFuelChartAxisHint,
            style: TextStyle(
              fontSize: 11,
              color: palette.textTertiary,
              height: 1.3,
            ),
          ),
          if (life != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: palette.warning.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.analyticsFuelLifetimeAvgLine(life),
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.analyticsFuelChartTouchHint,
              style: TextStyle(
                fontSize: 11,
                color: palette.textTertiary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCostScalesCard extends StatelessWidget {
  const _TripCostScalesCard({
    required this.l10n,
    required this.palette,
    required this.stats,
  });

  final AppL10n l10n;
  final ClientPalette palette;
  final CarFuelRefuelStats? stats;

  @override
  Widget build(BuildContext context) {
    final kpk = stats?.medianKopecksPerKm;
    if (kpk == null || kpk <= 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          l10n.analyticsTripCostEmpty,
          style: TextStyle(color: palette.textSecondary),
        ),
      );
    }
    const scales = [1, 10, 100, 1000];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analyticsTripCostTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.analyticsTripCostSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: palette.textTertiary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...scales.map((km) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.analyticsTripCostForKm(km),
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.money(kpk * km),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MonthCompareCategoriesCard extends StatelessWidget {
  const _MonthCompareCategoriesCard({
    required this.l10n,
    required this.palette,
    required this.thisMonthLabel,
    required this.prevMonthLabel,
    required this.thisMonthTotals,
    required this.prevMonthTotals,
  });

  final AppL10n l10n;
  final ClientPalette palette;
  final String thisMonthLabel;
  final String prevMonthLabel;
  final Map<String, int> thisMonthTotals;
  final Map<String, int> prevMonthTotals;

  Widget _block(String title, Map<String, int> totals) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text(
                l10n.analyticsMonthCompareEmpty,
                style: TextStyle(fontSize: 12, color: palette.textTertiary),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              Text(
                                Formatters.money(e.value),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.analyticsMonthCompareTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _block(prevMonthLabel, prevMonthTotals),
                const SizedBox(width: 10),
                _block(thisMonthLabel, thisMonthTotals),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarHistogram extends StatelessWidget {
  const _BarHistogram({
    required this.labels,
    required this.values,
    required this.maxValue,
    required this.valueLabel,
    required this.colors,
    required this.palette,
  });

  final List<String> labels;
  final List<int> values;
  final int maxValue;
  final String valueLabel;
  final List<Color> colors;
  final ClientPalette palette;

  @override
  Widget build(BuildContext context) {
    final maxV = maxValue <= 0 ? 1 : maxValue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valueLabel,
            style: TextStyle(fontSize: 12, color: palette.textTertiary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (i) {
                final h = 140 * (values[i] / maxV);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${values[i]}',
                          style: TextStyle(
                            fontSize: 9,
                            color: palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300 + i * 20),
                          height: h.clamp(2.0, 140.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colors[i % colors.length],
                                colors[i % colors.length].withValues(
                                  alpha: 0.45,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(labels.length, (i) {
              return Expanded(
                child: Text(
                  labels[i],
                  style: TextStyle(fontSize: 9, color: palette.textTertiary),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PieSlice {
  const _PieSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({
    required this.slices,
    required this.palette,
    required this.holeColor,
  });

  final List<_PieSlice> slices;
  final ClientPalette palette;
  final Color holeColor;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, x) => s + x.value);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            width: 200,
            child: CustomPaint(
              painter: _PiePainter(
                slices: slices,
                total: total,
                holeColor: holeColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...slices.map((s) {
            final pct = total > 0 ? (s.value / total * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.slices,
    required this.total,
    required this.holeColor,
  });

  final List<_PieSlice> slices;
  final double total;
  final Color holeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = 2 * math.pi * (s.value / total);
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );
      start += sweep;
    }
    canvas.drawCircle(center, radius * 0.45, Paint()..color = holeColor);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.holeColor != holeColor;
}

class _AnalyticsDataTable extends StatelessWidget {
  const _AnalyticsDataTable({
    required this.groups,
    required this.values,
    required this.metricTitle,
    required this.groupColumnLabel,
    required this.valueIsMoney,
    required this.palette,
  });

  final List<_GroupBucket> groups;
  final List<int> values;
  final String metricTitle;
  final String groupColumnLabel;
  final bool valueIsMoney;
  final ClientPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            palette.background.withValues(alpha: 0.5),
          ),
          columns: [
            DataColumn(
              label: Text(
                groupColumnLabel,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                metricTitle,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          rows: List.generate(groups.length, (i) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    groups[i].label,
                    style: TextStyle(color: palette.textPrimary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(
                    valueIsMoney ? Formatters.money(values[i]) : '${values[i]}',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            );
          }),
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
    final l10n = L10nScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: order.status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.stoName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  order.items.map((i) => i.name).join(', '),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.money(order.totalKopecks),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              Text(
                Formatters.dateShortLocalized(order.dateTime, l10n.intlLocale),
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
