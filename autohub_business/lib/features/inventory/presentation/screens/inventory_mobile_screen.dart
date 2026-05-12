import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/inventory_models.dart';

String _fmtQty(double v) {
  if (v == v.roundToDouble()) return '${v.round()}';
  final s = v.toStringAsFixed(4);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Склад из профиля — те же данные, что и на десктопе.
class InventoryMobileScreen extends ConsumerStatefulWidget {
  const InventoryMobileScreen({super.key});

  @override
  ConsumerState<InventoryMobileScreen> createState() => _InventoryMobileScreenState();
}

class _InventoryMobileScreenState extends ConsumerState<InventoryMobileScreen>
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

  Future<void> _refresh() async {
    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(inventoryMovementsProvider);
    await ref.read(inventoryItemsProvider.future);
  }

  Future<void> _showAdd() async {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    final qtyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая позиция'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название'), autofocus: true),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Единица')),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Начальный остаток (необязательно)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final unit = unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim();
    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final r = await ref.read(inventoryApiServiceProvider).createItem(
          name: name,
          unit: unit,
          initialQuantity: q > 0 ? q : null,
        );
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
      if (p != null && p > 0) estKopecks += (p * e.quantityTotal).round();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Склад'),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: itemsAsync.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Остатки'),
            Tab(text: 'Движения'),
            Tab(text: 'Мин.'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: itemsAsync.isLoading ? null : _showAdd,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _MiniStat(label: 'Позиций', value: '${items.length}')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: 'Оценка',
                        value: estKopecks > 0 ? '${(estKopecks / 100).round()} ₽' : '—',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniStat(label: 'Ниже нормы', value: '${low.length}')),
                  ],
                ),
                if (itemsAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${itemsAsync.error}',
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Поиск…',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _MobileStockList(itemsAsync: itemsAsync, filtered: filtered),
                _MobileMovList(movAsync: movAsync),
                _MobileLowList(itemsAsync: itemsAsync, low: low),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MobileStockList extends ConsumerWidget {
  const _MobileStockList({required this.itemsAsync, required this.filtered});

  final AsyncValue<List<InventoryItemModel>> itemsAsync;
  final List<InventoryItemModel> filtered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (itemsAsync.isLoading) {
      return ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())]);
    }
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              itemsAsync.hasValue && (itemsAsync.valueOrNull?.isEmpty ?? true)
                  ? 'Нет позиций. Нажмите +.'
                  : 'Ничего не найдено.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = filtered[i];
        return Material(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'дост. ${_fmtQty(e.quantityAvailable)} · всего ${_fmtQty(e.quantityTotal)} ${e.unit}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            onTap: () => _receipt(context, ref, e),
          ),
        );
      },
    );
  }

  void _receipt(BuildContext context, WidgetRef ref, InventoryItemModel e) {
    final c = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Поступление: ${e.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Количество')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final q = double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
                if (q <= 0) return;
                final r = await ref.read(inventoryApiServiceProvider).postReceipt(itemId: e.id, quantity: q);
                if (!ctx.mounted) return;
                r.when(
                  success: (_) {
                    ref.invalidate(inventoryItemsProvider);
                    ref.invalidate(inventoryMovementsProvider);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Готово')));
                  },
                  failure: (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message))),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileMovList extends StatelessWidget {
  const _MobileMovList({required this.movAsync});

  final AsyncValue<List<InventoryMovementModel>> movAsync;

  @override
  Widget build(BuildContext context) {
    if (movAsync.isLoading) {
      return ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())]);
    }
    if (movAsync.hasError) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [Padding(padding: const EdgeInsets.all(24), child: Text('${movAsync.error}'))],
      );
    }
    final list = movAsync.valueOrNull ?? [];
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Движений нет', style: TextStyle(color: AppColors.textSecondary))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = list[i];
        final title = (m.itemName != null && m.itemName!.isNotEmpty) ? m.itemName! : m.inventoryItemId;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('+${_fmtQty(m.quantity)} ${m.unit} · ${m.movementType}', style: const TextStyle(fontSize: 13)),
        );
      },
    );
  }
}

class _MobileLowList extends StatelessWidget {
  const _MobileLowList({required this.itemsAsync, required this.low});

  final AsyncValue<List<InventoryItemModel>> itemsAsync;
  final List<InventoryItemModel> low;

  @override
  Widget build(BuildContext context) {
    if (itemsAsync.isLoading) {
      return ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())]);
    }
    if (low.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Нет позиций ниже минимума', style: TextStyle(color: AppColors.textSecondary))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: low.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = low[i];
        return ListTile(
          tileColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.warning_amber_rounded, color: AppColors.primary),
          title: Text(e.name),
          subtitle: Text('дост. ${_fmtQty(e.quantityAvailable)}, мин. ${_fmtQty(e.minStock)} ${e.unit}'),
        );
      },
    );
  }
}
