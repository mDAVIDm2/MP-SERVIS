import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/app_l10n.dart';
import '../../../../../core/l10n/l10n_scope.dart';
import '../../../../../core/navigation/app_routes.dart';
import '../../../../../core/providers/app_providers.dart';
import '../../../../../core/theme/client_palette.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/models/car_model.dart';
import '../../../../../shared/models/order_model.dart';
import '../../../../orders/presentation/screens/order_detail_screen.dart';
import '../data/analytics_expense_aggregator.dart';
import '../data/analytics_taxonomy_l10n.dart';
import '../domain/analytics_expense_entry.dart';
import '../domain/analytics_global_period.dart';
import '../analytics_export.dart';
import '../../../../../core/settings/maintenance_reminders_provider.dart';
import '../../widgets/add_car_manual_expense_sheet.dart';
import '../../../../../core/settings/car_manual_expenses_provider.dart';

/// Список групп расходов (верхний уровень иерархии).
class AnalyticsExpenseGroupsScreen extends StatelessWidget {
  const AnalyticsExpenseGroupsScreen({
    super.key,
    required this.car,
    required this.entries,
    this.periodDescription = '',
  });

  final Car car;
  final List<AnalyticsExpenseEntry> entries;
  final String periodDescription;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
    final total = entries.fold<int>(0, (s, e) => s + e.totalKopecks);
    final byGroup = <String, int>{};
    final countByGroup = <String, int>{};
    for (final e in entries) {
      byGroup[e.expenseGroupId] =
          (byGroup[e.expenseGroupId] ?? 0) + e.totalKopecks;
      countByGroup[e.expenseGroupId] =
          (countByGroup[e.expenseGroupId] ?? 0) + 1;
    }

    final gids =
        byGroup.entries
            .where((e) => (e.value > 0) || ((countByGroup[e.key] ?? 0) > 0))
            .map((e) => e.key)
            .toList()
          ..sort((a, b) {
            final sa = byGroup[a] ?? 0;
            final sb = byGroup[b] ?? 0;
            return sb.compareTo(sa);
          });

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsDrilldownGroupsTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            Text(
              '${car.brand} ${car.model}',
              style: TextStyle(fontSize: 12, color: p.textTertiary),
            ),
          ],
        ),
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.analyticsEmptyPeriodHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary, height: 1.4),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${l10n.analyticsDrilldownTotalLabel}: ${Formatters.money(total)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ...gids.map((gid) {
                  final sum = byGroup[gid] ?? 0;
                  final n = countByGroup[gid] ?? 0;
                  if (sum <= 0 && n <= 0) return const SizedBox.shrink();
                  final pct = total > 0 ? (sum / total * 100).round() : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DrillTile(
                      palette: p,
                      title: l10n.analyticsTaxGroupTitle(gid),
                      subtitle:
                          '${l10n.analyticsDrilldownOperationsCount(n)} · $pct%',
                      trailingMoney: sum > 0 ? Formatters.money(sum) : null,
                      onTap: n > 0
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AnalyticsExpenseCategoriesScreen(
                                        car: car,
                                        entries: entries,
                                        groupId: gid,
                                        periodDescription: periodDescription,
                                      ),
                                ),
                              );
                            }
                          : null,
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

/// Подкатегории внутри выбранной группы.
class AnalyticsExpenseCategoriesScreen extends StatelessWidget {
  const AnalyticsExpenseCategoriesScreen({
    super.key,
    required this.car,
    required this.entries,
    required this.groupId,
    this.periodDescription = '',
  });

  final Car car;
  final List<AnalyticsExpenseEntry> entries;
  final String groupId;
  final String periodDescription;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
    final scoped = entries.where((e) => e.expenseGroupId == groupId).toList();
    final total = scoped.fold<int>(0, (s, e) => s + e.totalKopecks);
    final periodGrand = entries.fold<int>(0, (s, e) => s + e.totalKopecks);

    final byCat = <String, ({String title, int sum, int count})>{};
    for (final e in scoped) {
      final cid = e.expenseCategoryId;
      final cur = byCat[cid];
      if (cur == null) {
        byCat[cid] = (
          title: e.expenseCategoryTitle,
          sum: e.totalKopecks,
          count: 1,
        );
      } else {
        byCat[cid] = (
          title: cur.title,
          sum: cur.sum + e.totalKopecks,
          count: cur.count + 1,
        );
      }
    }
    final keys = byCat.keys.toList()
      ..sort((a, b) => (byCat[b]!.sum).compareTo(byCat[a]!.sum));

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.analyticsTaxGroupTitle(groupId),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            Text(
              '${car.brand} ${car.model}',
              style: TextStyle(fontSize: 12, color: p.textTertiary),
            ),
          ],
        ),
      ),
      body: scoped.isEmpty
          ? Center(
              child: Text(
                l10n.analyticsEmptyPeriodHint,
                style: TextStyle(color: p.textSecondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${l10n.analyticsDrilldownTotalLabel}: ${Formatters.money(total)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                ...keys.map((cid) {
                  final row = byCat[cid]!;
                  final pct = periodGrand > 0
                      ? (row.sum / periodGrand * 100).round()
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DrillTile(
                      palette: p,
                      title: row.title,
                      subtitle:
                          '${l10n.analyticsDrilldownOperationsCount(row.count)} · $pct%',
                      trailingMoney: Formatters.money(row.sum),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AnalyticsExpenseItemsScreen(
                              car: car,
                              entries: entries,
                              groupId: groupId,
                              categoryId: cid,
                              periodDescription: periodDescription,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

/// Пункты (одинаковые названия операций) внутри категории.
class AnalyticsExpenseItemsScreen extends StatelessWidget {
  const AnalyticsExpenseItemsScreen({
    super.key,
    required this.car,
    required this.entries,
    required this.groupId,
    required this.categoryId,
    this.periodDescription = '',
  });

  final Car car;
  final List<AnalyticsExpenseEntry> entries;
  final String groupId;
  final String categoryId;
  final String periodDescription;

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
    final scoped = entries
        .where(
          (e) =>
              e.expenseGroupId == groupId && e.expenseCategoryId == categoryId,
        )
        .toList();
    final total = scoped.fold<int>(0, (s, e) => s + e.totalKopecks);
    final periodGrand = entries.fold<int>(0, (s, e) => s + e.totalKopecks);
    final catTitle = scoped.isNotEmpty
        ? scoped.first.expenseCategoryTitle
        : l10n.analyticsTaxCategoryTitle(categoryId);

    final byItem = <String, ({int sum, int count})>{};
    for (final e in scoped) {
      final key = e.expenseItemTitle.trim().isEmpty
          ? e.title
          : e.expenseItemTitle.trim();
      final cur = byItem[key];
      if (cur == null) {
        byItem[key] = (sum: e.totalKopecks, count: 1);
      } else {
        byItem[key] = (sum: cur.sum + e.totalKopecks, count: cur.count + 1);
      }
    }
    final itemKeys = byItem.keys.toList()
      ..sort((a, b) => (byItem[b]!.sum).compareTo(byItem[a]!.sum));

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              catTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            Text(
              '${l10n.analyticsTaxGroupTitle(groupId)} · ${car.brand} ${car.model}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: p.textTertiary),
            ),
          ],
        ),
      ),
      body: scoped.isEmpty
          ? Center(
              child: Text(
                l10n.analyticsEmptyPeriodHint,
                style: TextStyle(color: p.textSecondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${l10n.analyticsDrilldownTotalLabel}: ${Formatters.money(total)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                ...itemKeys.map((itemTitle) {
                  final row = byItem[itemTitle]!;
                  final pct = periodGrand > 0
                      ? (row.sum / periodGrand * 100).round()
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DrillTile(
                      palette: p,
                      title: itemTitle,
                      subtitle:
                          '${l10n.analyticsDrilldownOperationsCount(row.count)} · $pct%',
                      trailingMoney: Formatters.money(row.sum),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AnalyticsExpenseItemHistoryScreen(
                              car: car,
                              entries: entries,
                              groupId: groupId,
                              categoryId: categoryId,
                              itemTitle: itemTitle,
                              periodDescription: periodDescription,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

/// История операций по конкретному пункту.
class AnalyticsExpenseItemHistoryScreen extends ConsumerStatefulWidget {
  const AnalyticsExpenseItemHistoryScreen({
    super.key,
    required this.car,
    required this.entries,
    required this.groupId,
    required this.categoryId,
    required this.itemTitle,
    this.periodDescription = '',
  });

  final Car car;
  final List<AnalyticsExpenseEntry> entries;
  final String groupId;
  final String categoryId;
  final String itemTitle;
  final String periodDescription;

  @override
  ConsumerState<AnalyticsExpenseItemHistoryScreen> createState() =>
      _AnalyticsExpenseItemHistoryScreenState();
}

class _AnalyticsExpenseItemHistoryScreenState
    extends ConsumerState<AnalyticsExpenseItemHistoryScreen> {
  bool _allTime = false;

  List<AnalyticsExpenseEntry> _allTimeJournal(AppL10n l10n) {
    final catalogData = ref.watch(catalogServicesProvider(null));
    final now = DateTime.now();
    return AnalyticsExpenseAggregator.build(
      l10n: l10n,
      carId: widget.car.id,
      period: const AnalyticsGlobalPeriod(
        preset: AnalyticsPeriodPreset.allTime,
      ),
      orders: ref.watch(ordersProvider).valueOrNull ?? const [],
      manual: visibleCarManualExpenses(ref.watch(carManualExpensesProvider)),
      maintenance: ref.watch(maintenanceRemindersProvider).records,
      catalogCategories: catalogData.valueOrNull?.categories ?? const [],
      catalogItems: catalogData.valueOrNull?.items ?? const [],
      now: now,
    );
  }

  List<AnalyticsExpenseEntry> _baseList(AppL10n l10n) =>
      _allTime ? _allTimeJournal(l10n) : widget.entries;

  List<AnalyticsExpenseEntry> _scoped(List<AnalyticsExpenseEntry> base) {
    return base.where((e) {
      if (e.expenseGroupId != widget.groupId ||
          e.expenseCategoryId != widget.categoryId) {
        return false;
      }
      final it = e.expenseItemTitle.trim().isEmpty
          ? e.title.trim()
          : e.expenseItemTitle.trim();
      return it == widget.itemTitle;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _export(AppL10n l10n, List<AnalyticsExpenseEntry> base) async {
    final scopeNote = _allTime
        ? l10n.analyticsDrilldownScopeAllTime
        : l10n.analyticsDrilldownScopePeriod;
    final pd = widget.periodDescription.trim().isEmpty
        ? scopeNote
        : '${widget.periodDescription} · $scopeNote';
    await AnalyticsExport.shareItemHistory(
      l10n: l10n,
      carLabel: '${widget.car.brand} ${widget.car.model}',
      periodDescription: pd,
      entries: base,
      groupId: widget.groupId,
      categoryId: widget.categoryId,
      itemTitle: widget.itemTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
    final base = _baseList(l10n);
    final scoped = _scoped(base);
    final grandTotal = base.fold<int>(0, (s, e) => s + e.totalKopecks);
    final total = scoped.fold<int>(0, (s, e) => s + e.totalKopecks);
    final avg = scoped.isNotEmpty ? total ~/ scoped.length : 0;
    final amounts = scoped.map((e) => e.totalKopecks).toList()..sort();
    final minK = scoped.isEmpty ? null : amounts.first;
    final maxK = scoped.isEmpty ? null : amounts.last;
    final last = scoped.isNotEmpty ? scoped.first : null;
    AnalyticsExpenseEntry? lastWithOdo;
    for (final e in scoped) {
      if (e.odometerKm != null) {
        lastWithOdo = e;
        break;
      }
    }
    final pctGrand = grandTotal > 0 ? (total * 100 / grandTotal).round() : 0;
    final catTitle = scoped.isNotEmpty ? scoped.first.expenseCategoryTitle : '';

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.itemTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            Text(
              '${l10n.analyticsTaxGroupTitle(widget.groupId)} · $catTitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: p.textTertiary),
            ),
          ],
        ),
        actions: [
          if (scoped.isNotEmpty)
            IconButton(
              tooltip: l10n.analyticsDrilldownExportItemCsv,
              onPressed: () => _export(l10n, base),
              icon: Icon(Icons.ios_share_rounded, color: p.textPrimary),
            ),
        ],
      ),
      body: scoped.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.analyticsEmptyPeriodHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary, height: 1.4),
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.analyticsDrilldownScopePeriod),
                          selected: !_allTime,
                          onSelected: (_) => setState(() => _allTime = false),
                        ),
                        ChoiceChip(
                          label: Text(l10n.analyticsDrilldownScopeAllTime),
                          selected: _allTime,
                          onSelected: (_) => setState(() => _allTime = true),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.analyticsDrilldownItemStatsLine(
                              Formatters.money(total),
                              scoped.length,
                              Formatters.money(avg),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: p.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              l10n.analyticsDrilldownPctOfPeriod(pctGrand),
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textTertiary,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (minK != null && maxK != null && scoped.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                l10n.analyticsDrilldownMinMaxLine(
                                  Formatters.money(minK),
                                  Formatters.money(maxK),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.textTertiary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          if (last != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n.analyticsDrilldownLastOp(
                                Formatters.dateShortYearRu(last.date),
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: p.textPrimary,
                              ),
                            ),
                          ],
                          if (lastWithOdo?.odometerKm != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                l10n.analyticsDrilldownLastOdometerLine(
                                  lastWithOdo!.odometerKm!,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.textTertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      l10n.analyticsDrilldownHistoryTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final e = scoped[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HistoryEntryCard(
                          ref: ref,
                          l10n: l10n,
                          p: p,
                          e: e,
                          car: widget.car,
                        ),
                      );
                    }, childCount: scoped.length),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DrillTile extends StatelessWidget {
  const _DrillTile({
    required this.palette,
    required this.title,
    required this.subtitle,
    this.trailingMoney,
    this.onTap,
  });

  final ClientPalette palette;
  final String title;
  final String subtitle;
  final String? trailingMoney;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingMoney != null)
                Text(
                  trailingMoney!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: palette.textPrimary,
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({
    required this.ref,
    required this.l10n,
    required this.p,
    required this.e,
    required this.car,
  });

  final WidgetRef ref;
  final AppL10n l10n;
  final ClientPalette p;
  final AnalyticsExpenseEntry e;
  final Car car;

  Future<void> _openEdit(BuildContext context) async {
    final sid = e.sourceId;
    if (sid == null || sid.isEmpty) return;
    final all = visibleCarManualExpenses(ref.read(carManualExpensesProvider));
    CarManualExpenseRecord? rec;
    for (final r in all) {
      if (r.id == sid) {
        rec = r;
        break;
      }
    }
    if (rec == null) return;
    await showAddCarManualExpenseSheet(
      context,
      ref,
      car: car,
      startWithFuel: rec.isFuel,
      existingRecord: rec,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final sid = e.sourceId;
    if (sid == null || sid.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.analyticsDeleteExpenseTitle),
        content: Text(l10n.analyticsDeleteExpenseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.analyticsManualCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.analyticsManualDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(carManualExpensesProvider.notifier).remove(sid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = switch (e.sourceType) {
      AnalyticsExpenseSourceType.order => l10n.analyticsSourceOrder,
      AnalyticsExpenseSourceType.manual => l10n.analyticsSourceManual,
      AnalyticsExpenseSourceType.fuel => l10n.analyticsSourceFuel,
      AnalyticsExpenseSourceType.maintenance => l10n.analyticsSourceMaintenance,
    };
    final place = e.organizationName ?? e.placeName;
    final canTapOrder =
        e.sourceType == AnalyticsExpenseSourceType.order && e.sourceId != null;
    return Material(
      color: p.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canTapOrder
            ? () {
                final orders = ref.read(ordersProvider).valueOrNull ?? [];
                Order? found;
                for (final o in orders) {
                  if (o.id == e.sourceId) {
                    found = o;
                    break;
                  }
                }
                if (found != null) {
                  pushCupertino(context, OrderDetailScreen(order: found));
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (e.sourceType) {
                      AnalyticsExpenseSourceType.fuel =>
                        Icons.local_gas_station_outlined,
                      AnalyticsExpenseSourceType.order => Icons.build_outlined,
                      AnalyticsExpenseSourceType.maintenance =>
                        Icons.handyman_outlined,
                      _ => Icons.payments_outlined,
                    },
                    color: p.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.sourceType == AnalyticsExpenseSourceType.order)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Chip(
                              label: Text(
                                l10n.analyticsBadgeFromOrder,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Chip(
                              label: Text(
                                src,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        Text(
                          e.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.dateShortYearRu(e.date),
                          style: TextStyle(fontSize: 12, color: p.textTertiary),
                        ),
                        if (e.odometerKm != null)
                          Text(
                            '${l10n.analyticsManualOdometerKm}: ${e.odometerKm}',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.textTertiary,
                            ),
                          ),
                        if (place != null && place.trim().isNotEmpty)
                          Text(
                            place.trim(),
                            style: TextStyle(
                              fontSize: 13,
                              color: p.textSecondary,
                            ),
                          ),
                        if (e.materialKopecks != null || e.laborKopecks != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              l10n.analyticsDrilldownMaterialLaborLine(
                                e.materialKopecks != null
                                    ? Formatters.money(e.materialKopecks!)
                                    : '—',
                                e.laborKopecks != null
                                    ? Formatters.money(e.laborKopecks!)
                                    : '—',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textTertiary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        if (e.comment != null && e.comment!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              e.comment!.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                color: p.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        if (e.sourceType == AnalyticsExpenseSourceType.order)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.analyticsDrilldownOrderAutoHint,
                              style: TextStyle(
                                fontSize: 11,
                                color: p.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.money(e.totalKopecks),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (e.manualSyncStatus != null) ...[
                        const SizedBox(height: 2),
                        Tooltip(
                          message:
                              e.manualSyncStatus ==
                                  CarManualExpenseSyncStatus.failed
                              ? l10n.analyticsSyncFailed
                              : l10n.analyticsSyncOfflineHint,
                          child: Icon(
                            e.manualSyncStatus ==
                                    CarManualExpenseSyncStatus.failed
                                ? Icons.error_outline_rounded
                                : Icons.cloud_upload_outlined,
                            size: 16,
                            color:
                                e.manualSyncStatus ==
                                    CarManualExpenseSyncStatus.failed
                                ? p.error
                                : p.textTertiary,
                          ),
                        ),
                      ],
                      if (e.isEditable) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.analyticsManualActionEdit,
                              onPressed: () => _openEdit(context),
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: p.textSecondary,
                              ),
                            ),
                            if (e.isDeletable)
                              IconButton(
                                tooltip: l10n.analyticsManualDelete,
                                onPressed: () => _confirmDelete(context),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: p.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
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
