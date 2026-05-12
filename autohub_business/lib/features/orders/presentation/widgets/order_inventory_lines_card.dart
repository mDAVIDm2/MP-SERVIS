import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../shared/models/inventory_models.dart';
import '../../../../shared/models/order_model.dart';

String _inventoryLineStatusRu(String s) {
  switch (s) {
    case 'planned':
      return 'план';
    case 'reserved':
      return 'в резерве';
    case 'not_enough_stock':
      return 'не хватает на складе';
    case 'released':
      return 'резерв снят';
    case 'written_off':
      return 'списано';
    case 'cancelled':
      return 'отменено';
    default:
      return s;
  }
}

/// Материалы склада по заказу (десктоп-панель). Мастеру не показывается.
class OrderInventoryLinesCard extends ConsumerWidget {
  const OrderInventoryLinesCard({
    super.key,
    required this.orderId,
    required this.order,
  });

  final String orderId;
  final Order order;

  static String _trimQty(double q) {
    if (q == q.roundToDouble()) return '${q.toInt()}';
    return q.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    await ref.read(inventoryItemsProvider.future).catchError((_) => <InventoryItemModel>[]);
    if (!context.mounted) return;
    final loaded = ref.read(inventoryItemsProvider).valueOrNull ?? const <InventoryItemModel>[];
    if (loaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте позиции на складе (раздел «Склад»).')),
      );
      return;
    }

    final picked = ValueNotifier<String>(loaded.first.id);
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return ValueListenableBuilder<String>(
          valueListenable: picked,
          builder: (ctx, pid, _) {
            return AlertDialog(
              title: const Text('Материал к заказу'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Позиция склада', style: TextStyle(fontSize: 12, color: AppColorsDesktop.textSecondary)),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: pid,
                      items: loaded
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) picked.value = v;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Количество',
                        hintText: 'Например 1 или 0.5',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Единица (необязательно)',
                        hintText: 'pcs, л, кг…',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );
    final chosenId = picked.value;
    picked.dispose();
    if (ok != true || !context.mounted) return;

    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите количество больше нуля')),
      );
      return;
    }
    final unit = unitCtrl.text.trim();
    final res = await ref.read(orderRepositoryProvider.notifier).addOrderInventoryLine(
          orderId,
          inventoryItemId: chosenId,
          quantity: qty,
          unit: unit.isEmpty ? null : unit,
        );
    if (!context.mounted) return;
    res.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Материал добавлен'))),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColorsDesktop.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role;
    if (role == BusinessRole.master) return const SizedBox.shrink();

    final lines = order.inventoryLines;
    final canAdd = order.status != OrderStatus.done && order.status != OrderStatus.cancelled;
    final invAsync = ref.watch(inventoryItemsProvider);
    final nameById = <String, String>{
      for (final it in invAsync.valueOrNull ?? const <InventoryItemModel>[]) it.id: it.name,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsDesktop.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: AppColorsDesktop.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Материалы склада',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColorsDesktop.textPrimary,
                ),
              ),
              const Spacer(),
              if (canAdd)
                TextButton.icon(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить'),
                ),
            ],
          ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Нет привязанных материалов. После добавления резерв создаётся при подтверждении заказа (если включено в настройках).',
                style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColorsDesktop.textSecondary),
              ),
            )
          else ...[
            const SizedBox(height: DesktopDesignSystem.blockSpacing * 0.5),
            ...lines.map((l) {
              final title = nameById[l.inventoryItemId] ?? l.inventoryItemId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(fontSize: 12.5, color: AppColorsDesktop.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_trimQty(l.quantityPlanned)} ${l.unit}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColorsDesktop.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColorsDesktop.nestedBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _inventoryLineStatusRu(l.status),
                        style: TextStyle(fontSize: 11.5, color: AppColorsDesktop.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
