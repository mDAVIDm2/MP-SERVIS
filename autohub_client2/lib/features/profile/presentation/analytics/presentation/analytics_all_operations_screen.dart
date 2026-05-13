import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/app_l10n.dart';
import '../../../../../core/l10n/l10n_scope.dart';
import '../../../../../core/navigation/app_routes.dart';
import '../../../../../core/providers/app_providers.dart';
import '../../../../../core/settings/car_manual_expenses_provider.dart';
import '../../../../../core/theme/client_palette.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/models/car_model.dart';
import '../../../../../shared/models/order_model.dart';
import '../../../../orders/presentation/screens/order_detail_screen.dart';
import '../../widgets/add_car_manual_expense_sheet.dart';
import 'analytics_hub_widgets.dart';
import '../analytics_export.dart';
import '../data/analytics_taxonomy_l10n.dart';
import '../domain/analytics_expense_entry.dart';

enum _OpsFilter { all, orders, manual, fuel, maintenance }

/// Плоский список всех операций за период (журнал).
class AnalyticsAllOperationsScreen extends ConsumerStatefulWidget {
  const AnalyticsAllOperationsScreen({
    super.key,
    required this.car,
    required this.entries,
    required this.periodDescription,
  });

  final Car car;
  final List<AnalyticsExpenseEntry> entries;
  final String periodDescription;

  @override
  ConsumerState<AnalyticsAllOperationsScreen> createState() =>
      _AnalyticsAllOperationsScreenState();
}

class _AnalyticsAllOperationsScreenState
    extends ConsumerState<AnalyticsAllOperationsScreen> {
  final TextEditingController _search = TextEditingController();
  _OpsFilter _filter = _OpsFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesFilter(AnalyticsExpenseEntry e) {
    switch (_filter) {
      case _OpsFilter.all:
        return true;
      case _OpsFilter.orders:
        return e.sourceType == AnalyticsExpenseSourceType.order;
      case _OpsFilter.manual:
        return e.sourceType == AnalyticsExpenseSourceType.manual;
      case _OpsFilter.fuel:
        return e.sourceType == AnalyticsExpenseSourceType.fuel;
      case _OpsFilter.maintenance:
        return e.sourceType == AnalyticsExpenseSourceType.maintenance;
    }
  }

  bool _matchesSearch(AnalyticsExpenseEntry e, String q, AppL10n l10n) {
    if (q.isEmpty) return true;
    final t = q.toLowerCase();
    final title = e.title.toLowerCase();
    final place = (e.organizationName ?? e.placeName ?? '').toLowerCase();
    final note = (e.comment ?? '').toLowerCase();
    final cat = e.expenseCategoryTitle.toLowerCase();
    final grp = l10n.analyticsTaxGroupTitle(e.expenseGroupId).toLowerCase();
    final op = e.operationType.name.toLowerCase();
    final src = switch (e.sourceType) {
      AnalyticsExpenseSourceType.order => l10n.analyticsSourceOrder,
      AnalyticsExpenseSourceType.manual => l10n.analyticsSourceManual,
      AnalyticsExpenseSourceType.fuel => l10n.analyticsSourceFuel,
      AnalyticsExpenseSourceType.maintenance => l10n.analyticsSourceMaintenance,
    }.toLowerCase();
    return title.contains(t) ||
        place.contains(t) ||
        note.contains(t) ||
        cat.contains(t) ||
        grp.contains(t) ||
        op.contains(t) ||
        src.contains(t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
    final q = _search.text.trim().toLowerCase();
    final sorted = [...widget.entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    final filtered = sorted
        .where(_matchesFilter)
        .where((e) => _matchesSearch(e, q, l10n))
        .toList();
    final hasAnyFuel = widget.entries.any(
      (e) => e.sourceType == AnalyticsExpenseSourceType.fuel,
    );

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Text(
          l10n.analyticsAllOperationsTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        ),
        actions: [
          if (filtered.isNotEmpty || hasAnyFuel)
            PopupMenuButton<String>(
              icon: Icon(Icons.ios_share_rounded, color: p.textPrimary),
              onSelected: (v) async {
                if (v == 'journal' && filtered.isNotEmpty) {
                  await AnalyticsExport.shareJournal(
                    l10n: l10n,
                    carLabel: '${widget.car.brand} ${widget.car.model}',
                    periodDescription: widget.periodDescription,
                    entries: filtered,
                  );
                } else if (v == 'groups' && filtered.isNotEmpty) {
                  await AnalyticsExport.shareGroupSummary(
                    l10n: l10n,
                    carLabel: '${widget.car.brand} ${widget.car.model}',
                    periodDescription: widget.periodDescription,
                    entries: filtered,
                  );
                } else if (v == 'cats' && filtered.isNotEmpty) {
                  await AnalyticsExport.shareCategorySummary(
                    l10n: l10n,
                    carLabel: '${widget.car.brand} ${widget.car.model}',
                    periodDescription: widget.periodDescription,
                    entries: filtered,
                  );
                } else if (v == 'fuel' && hasAnyFuel) {
                  await AnalyticsExport.shareFuel(
                    l10n: l10n,
                    carLabel: '${widget.car.brand} ${widget.car.model}',
                    periodDescription: widget.periodDescription,
                    entries: widget.entries,
                  );
                }
              },
              itemBuilder: (ctx) => [
                if (filtered.isNotEmpty)
                  PopupMenuItem(
                    value: 'journal',
                    child: Text(l10n.analyticsExportAllOperations),
                  ),
                if (filtered.isNotEmpty)
                  PopupMenuItem(
                    value: 'groups',
                    child: Text(l10n.analyticsExportGroups),
                  ),
                if (filtered.isNotEmpty)
                  PopupMenuItem(
                    value: 'cats',
                    child: Text(l10n.analyticsExportCategories),
                  ),
                if (hasAnyFuel)
                  PopupMenuItem(
                    value: 'fuel',
                    child: Text(l10n.analyticsExportFuel),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.analyticsAllOperationsSearchHint,
                prefixIcon: Icon(Icons.search_rounded, color: p.textSecondary),
                filled: true,
                fillColor: p.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  p: p,
                  label: l10n.analyticsAllOperationsFilterAll,
                  sel: _filter == _OpsFilter.all,
                  onTap: () => setState(() => _filter = _OpsFilter.all),
                ),
                _FilterChip(
                  p: p,
                  label: l10n.analyticsAllOperationsFilterOrders,
                  sel: _filter == _OpsFilter.orders,
                  onTap: () => setState(() => _filter = _OpsFilter.orders),
                ),
                _FilterChip(
                  p: p,
                  label: l10n.analyticsAllOperationsFilterManual,
                  sel: _filter == _OpsFilter.manual,
                  onTap: () => setState(() => _filter = _OpsFilter.manual),
                ),
                _FilterChip(
                  p: p,
                  label: l10n.analyticsAllOperationsFilterFuel,
                  sel: _filter == _OpsFilter.fuel,
                  onTap: () => setState(() => _filter = _OpsFilter.fuel),
                ),
                _FilterChip(
                  p: p,
                  label: l10n.analyticsAllOperationsFilterMaintenance,
                  sel: _filter == _OpsFilter.maintenance,
                  onTap: () => setState(() => _filter = _OpsFilter.maintenance),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      AnalyticsEmptyState(
                        palette: p,
                        icon: Icons.receipt_long_outlined,
                        title: l10n.analyticsAllOpsEmptyTitle,
                        subtitle: l10n.analyticsAllOpsEmptySubtitle,
                        primaryLabel: l10n.analyticsQuickExpense,
                        onPrimary: () => showAddCarManualExpenseSheet(
                          context,
                          ref,
                          car: widget.car,
                          startWithFuel: false,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final e = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EntryTile(
                          ref: ref,
                          l10n: l10n,
                          p: p,
                          car: widget.car,
                          e: e,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.p,
    required this.label,
    required this.sel,
    required this.onTap,
  });

  final ClientPalette p;
  final String label;
  final bool sel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: sel ? p.primary.withValues(alpha: 0.2) : p.cardBg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? p.primary : p.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.ref,
    required this.l10n,
    required this.p,
    required this.car,
    required this.e,
  });

  final WidgetRef ref;
  final AppL10n l10n;
  final ClientPalette p;
  final Car car;
  final AnalyticsExpenseEntry e;

  String _src() {
    return switch (e.sourceType) {
      AnalyticsExpenseSourceType.order => l10n.analyticsSourceOrder,
      AnalyticsExpenseSourceType.manual => l10n.analyticsSourceManual,
      AnalyticsExpenseSourceType.fuel => l10n.analyticsSourceFuel,
      AnalyticsExpenseSourceType.maintenance => l10n.analyticsSourceMaintenance,
    };
  }

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
    final place = e.organizationName ?? e.placeName;
    final canOrderTap =
        e.sourceType == AnalyticsExpenseSourceType.order && e.sourceId != null;
    return Material(
      color: p.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canOrderTap
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
          child: Row(
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.sourceType == AnalyticsExpenseSourceType.order)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
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
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Chip(
                          label: Text(
                            _src(),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.analyticsTaxGroupTitle(e.expenseGroupId),
                      style: TextStyle(
                        fontSize: 12,
                        color: p.textTertiary,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      e.expenseCategoryTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.textTertiary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      e.operationType.name,
                      style: TextStyle(fontSize: 11, color: p.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.dateShortYearRu(e.date),
                      style: TextStyle(fontSize: 11, color: p.textTertiary),
                    ),
                    if (place != null && place.trim().isNotEmpty)
                      Text(
                        place.trim(),
                        style: TextStyle(fontSize: 12, color: p.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (e.odometerKm != null)
                      Text(
                        '${l10n.analyticsManualOdometerKm}: ${e.odometerKm}',
                        style: TextStyle(fontSize: 11, color: p.textTertiary),
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
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
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
                        e.manualSyncStatus == CarManualExpenseSyncStatus.failed
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
                    const SizedBox(height: 4),
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
        ),
      ),
    );
  }
}
