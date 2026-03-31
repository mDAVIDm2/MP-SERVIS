import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../core/repositories/order_repository.dart';

/// Экран «Доп. работы» по заказу: список дополнительных работ и добавление новых.
class OrderExtraWorkScreen extends ConsumerWidget {
  final String orderId;

  const OrderExtraWorkScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Доп. работы')),
        body: const Center(
          child: Text('Заказ не найден', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final additionalItems = order.items.where((i) => i.isAdditional).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Доп. работы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddExtraWorkDialog(context, ref, order),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            order.orderNumber,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.carInfo,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          if (additionalItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'Дополнительных работ пока нет. Нажмите «Добавить» для согласования с клиентом.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...additionalItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 22,
                        color: item.isCompleted ? AppColors.success : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (item.estimatedMinutes > 0)
                        Text(
                          item.durationLabel,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                )),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showAddExtraWorkDialog(context, ref, order),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: const Text('Добавить доп. работу'),
          ),
        ],
      ),
    );
  }

  static void _showAddExtraWorkDialog(BuildContext screenContext, WidgetRef ref, Order order) {
    showDialog(
      context: screenContext,
      builder: (ctx) => _AddExtraWorkDialog(
        order: order,
        onAdd: (name, minutes, newPlannedEndTime) {
          Navigator.pop(ctx);
          _addExtraWork(screenContext, ref, order, name, minutes, newPlannedEndTime);
        },
      ),
    );
  }

  static Future<void> _addExtraWork(
    BuildContext screenContext,
    WidgetRef ref,
    Order order,
    String name,
    int minutes, [
    DateTime? newPlannedEndTime,
  ]) async {
    final repo = ref.read(orderRepositoryProvider.notifier);
    final ok = await repo.addExtraWorkItem(order.id, name, minutes);
    if (!screenContext.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        const SnackBar(
          content: Text('Не удалось добавить. Проверьте сеть.'),
          backgroundColor: AppColors.cardBg,
        ),
      );
      return;
    }
    if (newPlannedEndTime != null) {
      final res = await repo.updateOrderTime(order.id, plannedEndTime: newPlannedEndTime);
      if (!screenContext.mounted) return;
      res.when(
        success: (_) {
          ScaffoldMessenger.of(screenContext).showSnackBar(
            const SnackBar(
              content: Text('Доп. работа и новое время завершения сохранены'),
              backgroundColor: AppColors.cardBg,
            ),
          );
        },
        failure: (_) {
          ScaffoldMessenger.of(screenContext).showSnackBar(
            const SnackBar(
              content: Text('Доп. работа добавлена; время завершения не обновлено. Проверьте сеть.'),
              backgroundColor: AppColors.cardBg,
            ),
          );
        },
      );
    } else {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        const SnackBar(
          content: Text('Доп. работа добавлена'),
          backgroundColor: AppColors.cardBg,
        ),
      );
    }
  }
}

class _AddExtraWorkDialog extends StatefulWidget {
  final Order order;
  final void Function(String name, int minutes, DateTime? newPlannedEndTime) onAdd;

  const _AddExtraWorkDialog({required this.order, required this.onAdd});

  @override
  State<_AddExtraWorkDialog> createState() => _AddExtraWorkDialogState();
}

class _AddExtraWorkDialogState extends State<_AddExtraWorkDialog> {
  final _nameController = TextEditingController();
  int _minutes = 30;
  bool _changeEndTime = false;
  DateTime? _newPlannedEndTime;

  DateTime get _defaultNewEnd {
    final base = widget.order.plannedEndTime ?? widget.order.effectiveDateTime;
    return base.add(Duration(minutes: _minutes));
  }

  @override
  void initState() {
    super.initState();
    _newPlannedEndTime = _defaultNewEnd;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickNewEndTime() async {
    final initial = _newPlannedEndTime ?? _defaultNewEnd;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() => _newPlannedEndTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Доп. работа'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название работы',
                hintText: 'Например: Замена колодок',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _minutes,
              decoration: const InputDecoration(labelText: 'Примерное время'),
              items: [15, 30, 45, 60, 90, 120]
                  .map((m) => DropdownMenuItem(value: m, child: Text('$m мин')))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _minutes = v ?? 30;
                  if (_changeEndTime) _newPlannedEndTime = _defaultNewEnd;
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _changeEndTime,
                  onChanged: (v) => setState(() {
                    _changeEndTime = v ?? false;
                    if (_changeEndTime && _newPlannedEndTime == null) _newPlannedEndTime = _defaultNewEnd;
                  }),
                ),
                const Expanded(
                  child: Text(
                    'Указать новое время завершения заказа',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            if (_changeEndTime) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickNewEndTime,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  _newPlannedEndTime != null
                      ? '${_newPlannedEndTime!.day}.${_newPlannedEndTime!.month.toString().padLeft(2, '0')} ${_newPlannedEndTime!.hour.toString().padLeft(2, '0')}:${_newPlannedEndTime!.minute.toString().padLeft(2, '0')}'
                      : 'Выбрать время',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            widget.onAdd(name, _minutes, _changeEndTime ? _newPlannedEndTime : null);
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
