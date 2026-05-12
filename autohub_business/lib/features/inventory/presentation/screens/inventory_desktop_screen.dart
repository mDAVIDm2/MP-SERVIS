import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../shared/models/inventory_models.dart';

String _fmtQty(double v) {
  if (v == v.roundToDouble()) return '${v.round()}';
  final s = v.toStringAsFixed(4);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Склад: остатки, журнал, низкие остатки — данные с API `/inventory/*`.
class InventoryDesktopScreen extends ConsumerStatefulWidget {
  const InventoryDesktopScreen({super.key});

  @override
  ConsumerState<InventoryDesktopScreen> createState() => _InventoryDesktopScreenState();
}

class _InventoryDesktopScreenState extends ConsumerState<InventoryDesktopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _showAddItem() async {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    final qtyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая позиция'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Название'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Единица (pcs, l, m2…)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Начальный остаток (необязательно)',
                  hintText: '0',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final unit = unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim();
    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final api = ref.read(inventoryApiServiceProvider);
    final r = await api.createItem(name: name, unit: unit, initialQuantity: q > 0 ? q : null);
    if (!mounted) return;
    r.when(
      success: (_) {
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(inventoryMovementsProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Позиция создана')));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final movAsync = ref.watch(inventoryMovementsProvider);

    final items = itemsAsync.valueOrNull ?? const <InventoryItemModel>[];
    final filtered = _query.isEmpty
        ? items
        : items
            .where((e) =>
                e.name.toLowerCase().contains(_query) ||
                (e.sku ?? '').toLowerCase().contains(_query) ||
                (e.article ?? '').toLowerCase().contains(_query))
            .toList();
    final low = items.where((e) => e.isBelowMinStock).toList();

    int estKopecks = 0;
    for (final e in items) {
      final p = e.purchasePriceKopecks;
      if (p != null && p > 0) {
        estKopecks += (p * e.quantityTotal).round();
      }
    }

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesktopDesignSystem.pagePadding,
                  DesktopDesignSystem.pagePadding,
                  DesktopDesignSystem.pagePadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Учёт материалов и запчастей',
                      style: DesktopDesignSystem.body.copyWith(
                        color: AppColorsDesktop.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: DesktopDesignSystem.blockSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            icon: Icons.category_outlined,
                            label: 'Позиций в справочнике',
                            value: itemsAsync.isLoading ? '…' : '${items.length}',
                            hint: 'активные позиции',
                          ),
                        ),
                        const SizedBox(width: DesktopDesignSystem.elementSpacing),
                        Expanded(
                          child: _MetricTile(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Оценка остатка',
                            value: itemsAsync.isLoading
                                ? '…'
                                : (estKopecks > 0 ? '${(estKopecks / 100).toStringAsFixed(0)} ₽' : '—'),
                            hint: 'по закупочным ценам',
                          ),
                        ),
                        const SizedBox(width: DesktopDesignSystem.elementSpacing),
                        Expanded(
                          child: _MetricTile(
                            icon: Icons.warning_amber_rounded,
                            label: 'Ниже минимума',
                            value: itemsAsync.isLoading ? '…' : '${low.length}',
                            hint: 'требуют закупки',
                          ),
                        ),
                      ],
                    ),
                    if (itemsAsync.hasError) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        'Не удалось загрузить склад: ${itemsAsync.error}',
                        style: DesktopDesignSystem.body.copyWith(color: AppColorsDesktop.error),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ref.invalidate(inventoryItemsProvider);
                          ref.invalidate(inventoryMovementsProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Повторить'),
                      ),
                    ],
                    const SizedBox(height: DesktopDesignSystem.blockSpacing),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Поиск по названию, SKU, артикулу…',
                        hintStyle: DesktopDesignSystem.body.copyWith(
                          color: AppColorsDesktop.textSecondary.withValues(alpha: 0.75),
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColorsDesktop.textSecondary),
                        filled: true,
                        fillColor: AppColorsDesktop.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                          borderSide: const BorderSide(color: AppColorsDesktop.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                          borderSide: const BorderSide(color: AppColorsDesktop.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                          borderSide: const BorderSide(color: AppColorsDesktop.primary, width: 1.2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: AppColorsDesktop.surface,
                child: TabBar(
                  controller: _tabs,
                  labelColor: AppColorsDesktop.primary,
                  unselectedLabelColor: AppColorsDesktop.textSecondary,
                  indicatorColor: AppColorsDesktop.primary,
                  indicatorWeight: 2.5,
                  labelStyle: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600),
                  unselectedLabelStyle: DesktopDesignSystem.body,
                  tabs: const [
                    Tab(text: 'Остатки'),
                    Tab(text: 'Журнал движений'),
                    Tab(text: 'Низкие остатки'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColorsDesktop.border),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _StockTab(itemsAsync: itemsAsync, filtered: filtered),
                    _MovementsTab(movAsync: movAsync),
                    _LowStockTab(itemsAsync: itemsAsync, low: low),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 28,
            bottom: 28,
            child: FloatingActionButton.extended(
              onPressed: itemsAsync.isLoading ? null : _showAddItem,
              backgroundColor: AppColorsDesktop.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Позиция', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockTab extends ConsumerWidget {
  const _StockTab({required this.itemsAsync, required this.filtered});

  final AsyncValue<List<InventoryItemModel>> itemsAsync;
  final List<InventoryItemModel> filtered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (itemsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          itemsAsync.hasValue && (itemsAsync.valueOrNull?.isEmpty ?? true)
              ? 'Пока нет позиций — нажмите «Позиция», чтобы добавить первую.'
              : 'Ничего не найдено по запросу.',
          style: DesktopDesignSystem.bodySecondary,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = filtered[i];
        return Material(
          color: AppColorsDesktop.surface,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
            onTap: () => _showReceiptSheet(context, ref, e),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name, style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          '${e.itemType} · ${e.unit} · доступно ${_fmtQty(e.quantityAvailable)} (всего ${_fmtQty(e.quantityTotal)}, резерв ${_fmtQty(e.quantityReserved)})',
                          style: DesktopDesignSystem.meta,
                        ),
                      ],
                    ),
                  ),
                  if (e.purchasePriceKopecks != null)
                    Text(
                      '${(e.purchasePriceKopecks! / 100).toStringAsFixed(0)} ₽',
                      style: DesktopDesignSystem.label.copyWith(color: AppColorsDesktop.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReceiptSheet(BuildContext context, WidgetRef ref, InventoryItemModel e) {
    final qtyCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColorsDesktop.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Поступление: ${e.name}', style: DesktopDesignSystem.sectionTitle),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Количество'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
                  if (q <= 0) return;
                  final api = ref.read(inventoryApiServiceProvider);
                  final r = await api.postReceipt(itemId: e.id, quantity: q);
                  if (!ctx.mounted) return;
                  r.when(
                    success: (_) {
                      ref.invalidate(inventoryItemsProvider);
                      ref.invalidate(inventoryMovementsProvider);
                      Navigator.pop(ctx);
                      messenger.showSnackBar(const SnackBar(content: Text('Остаток обновлён')));
                    },
                    failure: (err) => messenger.showSnackBar(SnackBar(content: Text(err.message))),
                  );
                },
                child: const Text('Записать поступление'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MovementsTab extends StatelessWidget {
  const _MovementsTab({required this.movAsync});

  final AsyncValue<List<InventoryMovementModel>> movAsync;

  @override
  Widget build(BuildContext context) {
    if (movAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (movAsync.hasError) {
      return Center(child: Text('${movAsync.error}', style: DesktopDesignSystem.bodySecondary));
    }
    final list = movAsync.valueOrNull ?? [];
    if (list.isEmpty) {
      return Center(
        child: Text('Движений пока нет.', style: DesktopDesignSystem.bodySecondary),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = list[i];
        final title = (m.itemName != null && m.itemName!.isNotEmpty) ? m.itemName! : m.inventoryItemId;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${m.movementType} · ${m.sourceType} · +${_fmtQty(m.quantity)} ${m.unit}',
            style: DesktopDesignSystem.meta,
          ),
          trailing: Text(
            m.createdAt.length >= 16 ? m.createdAt.substring(0, 16).replaceFirst('T', ' ') : m.createdAt,
            style: DesktopDesignSystem.meta,
          ),
        );
      },
    );
  }
}

class _LowStockTab extends StatelessWidget {
  const _LowStockTab({required this.itemsAsync, required this.low});

  final AsyncValue<List<InventoryItemModel>> itemsAsync;
  final List<InventoryItemModel> low;

  @override
  Widget build(BuildContext context) {
    if (itemsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (low.isEmpty) {
      return Center(
        child: Text(
          'Все позиции не ниже минимального запаса (или минимум = 0).',
          style: DesktopDesignSystem.bodySecondary,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
      itemCount: low.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = low[i];
        return ListTile(
          tileColor: AppColorsDesktop.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
            side: const BorderSide(color: AppColorsDesktop.border),
          ),
          title: Text(e.name, style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Доступно ${_fmtQty(e.quantityAvailable)}, минимум ${_fmtQty(e.minStock)} ${e.unit}',
            style: DesktopDesignSystem.meta,
          ),
          leading: Icon(Icons.warning_amber_rounded, color: AppColorsDesktop.primary),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.border),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColorsDesktop.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: DesktopDesignSystem.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: DesktopDesignSystem.meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
