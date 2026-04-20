import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/org_business_kind.dart';
import '../analytics/analytics_catalog_helper.dart';
import '../analytics/analytics_dashboard_models.dart';
import '../analytics/analytics_export.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _lastCenteredCarId;
  bool _prefsLoaded = false;

  /// Каждый элемент — отдельная диаграмма со своими параметрами (сохраняется в [AnalyticsDashboardStorage]).
  List<AnalyticsBlockConfig> _blocks = [];

  Future<void> _loadPrefs() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!mounted) return;
    final blocks = await AnalyticsDashboardStorage.load(prefs);
    setState(() {
      _blocks = blocks.isEmpty ? [AnalyticsBlockConfig(id: 'default_1')] : blocks;
      _prefsLoaded = true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await AnalyticsDashboardStorage.save(prefs, _blocks);
  }

  DateTime? _rangeStartMonths(int periodMonths) {
    if (periodMonths <= 0) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month - periodMonths, now.day);
  }

  List<Order> _filteredOrders(List<Order> orders, String carId, AnalyticsBlockConfig block) {
    final start = _rangeStartMonths(block.periodMonths);
    var list = orders.where((o) => o.carId == carId).toList();
    if (start != null) {
      list = list.where((o) => !o.dateTime.isBefore(start)).toList();
    }
    if (block.orgKindFilterCode != null && block.orgKindFilterCode!.isNotEmpty) {
      final want = OrgBusinessKind.normalizeCode(block.orgKindFilterCode) ?? block.orgKindFilterCode;
      list = list.where((o) {
        final g = OrgBusinessKind.normalizeCode(o.organizationBusinessKind);
        return g == want;
      }).toList();
    }
    return list;
  }

  static bool _countsFinancial(Order o) => o.status != OrderStatus.cancelled;

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
          title: Text(l10n.analyticsTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
          title: Text(l10n.analyticsTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        body: Center(child: Text(l10n.analyticsAddCarToGarage, style: TextStyle(color: context.palette.textSecondary))),
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
    final primary = _blocks.first;
    final carOrders = _filteredOrders(orders, car.id, primary);
    final financial = carOrders.where(_countsFinancial).toList();

    final kindCodes = <String>{};
    for (final o in orders.where((o) => o.carId == car.id)) {
      final k = OrgBusinessKind.normalizeCode(o.organizationBusinessKind);
      if (k != null && k.isNotEmpty) kindCodes.add(k);
    }
    final kindList = kindCodes.toList()..sort();

    final totalKopecks = financial.fold<int>(0, (s, o) => s + _orderAmount(o));
    final orderCountFin = financial.length;
    final avgCheck = orderCountFin > 0 ? totalKopecks ~/ orderCountFin : 0;
    final monthsForAvg = primary.periodMonths <= 0
        ? (financial.isEmpty
            ? 1
            : math.max(
                1,
                financial.map((o) => '${o.dateTime.year}-${o.dateTime.month}').toSet().length,
              ))
        : math.max(1, primary.periodMonths);
    final avgMonthly = totalKopecks ~/ monthsForAvg;

    final catalogData = ref.watch(catalogServicesProvider(null));
    final catCategories = catalogData.valueOrNull?.categories ?? const <CatalogCategory>[];
    final catItems = catalogData.valueOrNull?.items ?? const <CatalogServiceItem>[];
    final primaryGroups = _buildGroups(
      l10n,
      financial,
      groupBy: primary.groupBy,
      catalogCategories: catCategories,
      catalogItems: catItems,
    );
    final primaryExportValues = primaryGroups.map((g) => _bucketValue(g, primary)).toList();

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text(l10n.analyticsTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (primaryGroups.isNotEmpty)
            IconButton(
              tooltip: l10n.analyticsExportTooltip,
              onPressed: () => _shareAnalyticsTable(
                    context,
                    l10n,
                    carLabel: '${car.brand} ${car.model}',
                    groups: primaryGroups,
                    values: primaryExportValues,
                    block: primary,
                  ),
              icon: Icon(Icons.ios_share_rounded, color: context.palette.textPrimary),
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
                  onTap: () => ref.read(selectedCarIdProvider.notifier).set(c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? context.palette.primary : context.palette.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isSelected ? context.palette.primary : context.palette.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${c.brand} ${c.model}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? context.palette.onAccent : context.palette.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _KpiRow(
            l10n: l10n,
            totalKopecks: totalKopecks,
            orderCount: orderCountFin,
            avgCheck: avgCheck,
            avgMonthly: avgMonthly,
            periodLabel: primary.periodMonths <= 0 ? l10n.analyticsKpiPeriodAll() : l10n.analyticsKpiPeriodMonths(primary.periodMonths),
          ),
          const SizedBox(height: 16),
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
              final financialB = _filteredOrders(orders, car.id, block).where(_countsFinancial).toList();
              final groupsB = _buildGroups(
                l10n,
                financialB,
                groupBy: block.groupBy,
                catalogCategories: catCategories,
                catalogItems: catItems,
              );
              final exportValsB = groupsB.map((g) => _bucketValue(g, block)).toList();
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
                              padding: const EdgeInsets.only(right: 4, top: 2),
                              child: Icon(Icons.drag_handle_rounded, color: context.palette.textTertiary, size: 22),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _blocks.length > 1
                                  ? '${l10n.analyticsDataSection} · ${blockIndex + 1}'
                                  : l10n.analyticsDataSection,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
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
                              icon: Icon(Icons.ios_share_rounded, size: 22, color: context.palette.textPrimary),
                            ),
                          if (_blocks.length > 1)
                            IconButton(
                              tooltip: l10n.analyticsRemoveChartBlock,
                              onPressed: () {
                                setState(() => _blocks.removeAt(blockIndex));
                                _savePrefs();
                              },
                              icon: Icon(Icons.delete_outline_rounded, color: context.palette.textSecondary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _FiltersCard(
                        l10n: l10n,
                        block: block,
                        catalogLoading: catalogData.isLoading,
                        kindCodes: kindList,
                        onUpdate: (updated) {
                          setState(() => _blocks[blockIndex] = updated);
                          _savePrefs();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (groupsB.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.analyticsNoOrdersFiltered,
                            style: TextStyle(color: context.palette.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        _buildMainVisual(context, l10n, groupsB, block),
                    ],
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _blocks.add(
                    AnalyticsBlockConfig(
                      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
                      periodMonths: primary.periodMonths,
                      groupBy: primary.groupBy,
                      display: AnalyticsChartDisplay.pie,
                      metric: primary.metric,
                      orgKindFilterCode: primary.orgKindFilterCode,
                    ),
                  );
                });
                _savePrefs();
              },
              icon: Icon(Icons.add_chart_rounded, color: context.palette.primary),
              label: Text(l10n.analyticsAddChartBlock, style: TextStyle(color: context.palette.primary)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.analyticsOrdersSection,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.palette.textPrimary),
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
  }) {
    switch (groupBy) {
      case AnalyticsGroupBy.month:
        final map = <String, List<Order>>{};
        for (final o in financial) {
          final k = '${o.dateTime.year}-${o.dateTime.month.toString().padLeft(2, '0')}';
          map.putIfAbsent(k, () => []).add(o);
        }
        final keys = map.keys.toList()..sort();
        return keys
            .map((k) => _GroupBucket(
                  label: _monthLabel(k, l10n),
                  sortKey: k,
                  orders: map[k]!,
                ))
            .toList();
      case AnalyticsGroupBy.orgKind:
        final map = <String, List<Order>>{};
        for (final o in financial) {
          final raw = o.organizationBusinessKind;
          final code = (raw != null && raw.trim().isNotEmpty) ? raw.trim().toLowerCase().replaceAll('-', '_') : '';
          final label = code.isEmpty
              ? l10n.analyticsOrgKindUnknown
              : (OrgBusinessKind.labelForOrderSnapshot(code, english: l10n.isEn).isEmpty
                  ? code
                  : OrgBusinessKind.labelForOrderSnapshot(code, english: l10n.isEn));
          map.putIfAbsent(label, () => []).add(o);
        }
        final entries = map.entries.toList()..sort((a, b) => _groupValue(b.value).compareTo(_groupValue(a.value)));
        return entries
            .map((e) => _GroupBucket(
                  label: e.key,
                  sortKey: e.key,
                  orders: e.value,
                ))
            .toList();
      case AnalyticsGroupBy.serviceCategory:
        final map = <String, int>{};
        final counts = <String, int>{};
        for (final o in financial) {
          for (final item in o.itemsForDisplay.where((i) => i.isApproved && !i.isRejected)) {
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
        final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return entries
            .map((e) => _GroupBucket(
                  label: e.key,
                  sortKey: e.key,
                  orders: const [],
                  extraKopecks: e.value,
                  lineCount: counts[e.key] ?? 0,
                ))
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

  int _groupValue(List<Order> list) => list.fold<int>(0, (s, o) => s + _orderAmount(o));

  int _bucketValue(_GroupBucket b, AnalyticsBlockConfig block) {
    if (block.groupBy == AnalyticsGroupBy.serviceCategory && b.extraKopecks != null) {
      final denom = block.periodMonths <= 0 ? 1 : math.max(1, block.periodMonths);
      return switch (block.metric) {
        AnalyticsValueMetric.totalSpend => b.extraKopecks!,
        AnalyticsValueMetric.orderCount => b.lineCount ?? 0,
        AnalyticsValueMetric.avgCheck =>
          (b.lineCount ?? 0) > 0 ? b.extraKopecks! ~/ (b.lineCount ?? 1) : 0,
        AnalyticsValueMetric.avgMonthlySpend => b.extraKopecks! ~/ denom,
      };
    }
    final list = b.orders;
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(0, (s, o) => s + _orderAmount(o));
    final denom = block.periodMonths <= 0 ? 1 : math.max(1, block.periodMonths);
    return switch (block.metric) {
      AnalyticsValueMetric.totalSpend => sum,
      AnalyticsValueMetric.orderCount => list.length,
      AnalyticsValueMetric.avgCheck => sum ~/ list.length,
      AnalyticsValueMetric.avgMonthlySpend => sum ~/ denom,
    };
  }

  Widget _buildMainVisual(BuildContext context, AppL10n l10n, List<_GroupBucket> groups, AnalyticsBlockConfig block) {
    final values = groups.map((g) => _bucketValue(g, block)).toList();
    final maxV = values.isEmpty ? 0 : values.reduce(math.max);
    final palette = context.palette;
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
        return _BarHistogram(
          labels: groups.map((g) => g.label).toList(),
          values: values,
          maxValue: maxV > 0 ? maxV : 1,
          valueLabel: _metricTitle(l10n, block),
          colors: colors,
          palette: palette,
        );
      case AnalyticsChartDisplay.pie:
        final slices = <_PieSlice>[];
        for (var i = 0; i < groups.length; i++) {
          final v = values[i];
          if (v <= 0) continue;
          slices.add(_PieSlice(label: groups[i].label, value: v.toDouble(), color: colors[i % colors.length]));
        }
        if (slices.isEmpty) {
          return Text(l10n.analyticsPieNoPositive, style: TextStyle(color: palette.textSecondary));
        }
        return _PieChartCard(slices: slices, palette: palette, holeColor: palette.background);
      case AnalyticsChartDisplay.table:
        return _AnalyticsDataTable(
          groups: groups,
          values: values,
          metricTitle: _metricTitle(l10n, block),
          groupColumnLabel: l10n.analyticsGroupColumn,
          valueIsMoney: block.metric != AnalyticsValueMetric.orderCount,
          palette: palette,
        );
    }
  }

  String _metricTitle(AppL10n l10n, AnalyticsBlockConfig block) {
    return switch (block.metric) {
      AnalyticsValueMetric.totalSpend => l10n.analyticsMetricShortSumRub,
      AnalyticsValueMetric.orderCount => l10n.analyticsMetricShortOrders,
      AnalyticsValueMetric.avgCheck => l10n.analyticsMetricShortAvgRub,
      AnalyticsValueMetric.avgMonthlySpend => l10n.analyticsMetricShortAvgMonthly,
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
      AnalyticsGroupBy.serviceCategory => l10n.analyticsGroupByServiceCategoryHint,
    };
  }

  String _metricExportDescription(AppL10n l10n, AnalyticsBlockConfig block) {
    return switch (block.metric) {
      AnalyticsValueMetric.totalSpend => l10n.analyticsMetricTotalSpend,
      AnalyticsValueMetric.orderCount => l10n.analyticsMetricLongOrderLines,
      AnalyticsValueMetric.avgCheck => l10n.analyticsMetricAvgCheck,
      AnalyticsValueMetric.avgMonthlySpend => l10n.analyticsMetricAvgMonthlyInGroup,
    };
  }

  String? _orgFilterExportDescription(AppL10n l10n, AnalyticsBlockConfig block) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.analyticsExportError(e))),
        );
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
  });

  final String label;
  final String sortKey;
  final List<Order> orders;
  final int? extraKopecks;
  /// Для группировки по категории: число позиций в каталоге.
  final int? lineCount;
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.l10n,
    required this.block,
    this.catalogLoading = false,
    required this.kindCodes,
    required this.onUpdate,
  });

  final AppL10n l10n;
  final AnalyticsBlockConfig block;
  final bool catalogLoading;
  final List<String> kindCodes;
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
          Text(l10n.analyticsPeriodLabel, style: TextStyle(fontSize: 12, color: p.textTertiary)),
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
          Text(l10n.analyticsOrgFilterLabel, style: TextStyle(fontSize: 12, color: p.textTertiary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            value: block.orgKindFilterCode,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: Text(l10n.analyticsAllOrgTypes),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l10n.analyticsAllOrgTypes)),
              ...kindCodes.map((c) {
                final label = OrgBusinessKind.labelForOrderSnapshot(c, english: l10n.isEn);
                return DropdownMenuItem<String?>(
                  value: c,
                  child: Text(label.isEmpty ? c : label, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: (v) => onUpdate(block.copyWith(orgKindFilterCode: v, clearOrgFilter: v == null)),
          ),
          const SizedBox(height: 14),
          Text(l10n.analyticsGroupingLabel, style: TextStyle(fontSize: 12, color: p.textTertiary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<AnalyticsGroupBy>(
            value: block.groupBy,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              DropdownMenuItem(
                value: AnalyticsGroupBy.month,
                child: Text(l10n.analyticsGroupByMonth, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: AnalyticsGroupBy.orgKind,
                child: Text(l10n.analyticsGroupByOrgKind, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: AnalyticsGroupBy.serviceCategory,
                child: Text(l10n.analyticsGroupByServiceCategory, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
            onChanged: (v) {
              if (v != null) onUpdate(block.copyWith(groupBy: v));
            },
          ),
          if (catalogLoading && block.groupBy == AnalyticsGroupBy.serviceCategory) ...[
            const SizedBox(height: 8),
            Text(
              l10n.analyticsCatalogLoading,
              style: TextStyle(fontSize: 12, color: p.textTertiary),
            ),
          ],
          const SizedBox(height: 14),
          Text(l10n.analyticsMetricLabel, style: TextStyle(fontSize: 12, color: p.textTertiary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<AnalyticsValueMetric>(
            value: block.metric,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: p.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              DropdownMenuItem(value: AnalyticsValueMetric.totalSpend, child: Text(l10n.analyticsMetricTotalSpend)),
              DropdownMenuItem(value: AnalyticsValueMetric.orderCount, child: Text(l10n.analyticsMetricOrderCount)),
              DropdownMenuItem(value: AnalyticsValueMetric.avgCheck, child: Text(l10n.analyticsMetricAvgCheck)),
              DropdownMenuItem(value: AnalyticsValueMetric.avgMonthlySpend, child: Text(l10n.analyticsMetricAvgMonthlyInGroup)),
            ],
            onChanged: (v) {
              if (v != null) onUpdate(block.copyWith(metric: v));
            },
          ),
          const SizedBox(height: 14),
          Text(l10n.analyticsFormatLabel, style: TextStyle(fontSize: 12, color: p.textTertiary)),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 340;
              final segments = <ButtonSegment<AnalyticsChartDisplay>>[
                ButtonSegment<AnalyticsChartDisplay>(
                  value: AnalyticsChartDisplay.bar,
                  tooltip: l10n.analyticsChartBars,
                  label: Text(l10n.analyticsChartBarsShort),
                  icon: Icon(Icons.bar_chart_rounded, size: narrow ? 20 : 18),
                ),
                ButtonSegment<AnalyticsChartDisplay>(
                  value: AnalyticsChartDisplay.pie,
                  tooltip: l10n.analyticsChartPie,
                  label: Text(l10n.analyticsChartPieShort),
                  icon: Icon(Icons.pie_chart_rounded, size: narrow ? 20 : 18),
                ),
                ButtonSegment<AnalyticsChartDisplay>(
                  value: AnalyticsChartDisplay.table,
                  tooltip: l10n.analyticsChartTable,
                  label: Text(l10n.analyticsChartTableShort),
                  icon: Icon(Icons.table_rows_rounded, size: narrow ? 20 : 18),
                ),
              ];
              return SegmentedButton<AnalyticsChartDisplay>(
                showSelectedIcon: false,
                segments: segments,
                selected: {block.display},
                onSelectionChanged: (s) => onUpdate(block.copyWith(display: s.first)),
              );
            },
          ),
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

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.l10n,
    required this.totalKopecks,
    required this.orderCount,
    required this.avgCheck,
    required this.avgMonthly,
    required this.periodLabel,
  });

  final AppL10n l10n;
  final int totalKopecks;
  final int orderCount;
  final int avgCheck;
  final int avgMonthly;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.analyticsKpiSummaryPrefix} $periodLabel',
          style: TextStyle(fontSize: 13, color: context.palette.textTertiary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MiniKpi(title: l10n.analyticsKpiSpend, value: Formatters.money(totalKopecks))),
            const SizedBox(width: 8),
            Expanded(child: _MiniKpi(title: l10n.analyticsKpiOrders, value: '$orderCount')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MiniKpi(title: l10n.analyticsKpiAvgCheck, value: Formatters.money(avgCheck))),
            const SizedBox(width: 8),
            Expanded(child: _MiniKpi(title: l10n.analyticsKpiAvgPerMonth, value: Formatters.money(avgMonthly))),
          ],
        ),
      ],
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: p.textTertiary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary, fontFamily: 'monospace')),
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
          Text(valueLabel, style: TextStyle(fontSize: 12, color: palette.textTertiary)),
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
                          style: TextStyle(fontSize: 9, color: palette.textSecondary),
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
                              colors: [colors[i % colors.length], colors[i % colors.length].withValues(alpha: 0.45)],
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
  const _PieSlice({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({required this.slices, required this.palette, required this.holeColor});

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
              painter: _PiePainter(slices: slices, total: total, holeColor: holeColor),
            ),
          ),
          const SizedBox(height: 16),
          ...slices.map((s) {
            final pct = total > 0 ? (s.value / total * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      style: TextStyle(fontSize: 13, color: palette.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('$pct%', style: TextStyle(fontSize: 13, color: palette.textSecondary)),
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
  _PiePainter({required this.slices, required this.total, required this.holeColor});

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
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, paint);
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
          headingRowColor: WidgetStatePropertyAll(palette.background.withValues(alpha: 0.5)),
          columns: [
            DataColumn(
              label: Text(
                groupColumnLabel,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                metricTitle,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
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
                DataCell(Text(
                  valueIsMoney ? Formatters.money(values[i]) : '${values[i]}',
                  style: TextStyle(color: palette.textPrimary, fontFamily: 'monospace'),
                )),
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
            decoration: BoxDecoration(color: order.status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.stoName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
                Text(order.items.map((i) => i.name).join(', '), style: TextStyle(fontSize: 12, color: context.palette.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.money(order.totalKopecks), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
              Text(Formatters.dateShortLocalized(order.dateTime, l10n.intlLocale), style: TextStyle(fontSize: 12, color: context.palette.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
