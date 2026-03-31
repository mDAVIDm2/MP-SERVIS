import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/scroll_center.dart';
import '../../../../shared/models/car_model.dart';

/// Нижняя панель: все автомобили, краткая информация, изменить / удалить, снизу — «Добавить».
Future<void> showGarageCarsManagementSheet(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() onAddCar,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.32,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return Consumer(
            builder: (context, ref, _) {
              final carsAsync = ref.watch(carsProvider);
              final cars = carsAsync.valueOrNull ?? [];
              final selectedId = ref.watch(selectedCarIdProvider);

              Future<void> afterDeleteReselect(String deletedId) async {
                final list = ref.read(carsProvider).valueOrNull ?? [];
                final wasSelected = ref.read(selectedCarIdProvider) == deletedId;
                if (!wasSelected) return;
                if (list.isEmpty) {
                  await ref.read(selectedCarIdProvider.notifier).set(null);
                } else {
                  await ref.read(selectedCarIdProvider.notifier).set(list.first.id);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text('Мои автомобили', style: AppTextStyles.screenTitle.copyWith(fontSize: 20)),
                  ),
                  Expanded(
                    child: carsAsync.isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : cars.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Пока нет автомобилей',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            : Stack(
                                children: [
                                  ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    itemCount: cars.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) {
                                      final car = cars[i];
                                      final isSelected = car.id == selectedId;
                                      return Material(
                                        key: GlobalObjectKey(car.id),
                                        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.nestedBg,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () async {
                                            await ref.read(selectedCarIdProvider.notifier).set(car.id);
                                            if (context.mounted) Navigator.pop(ctx);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.directions_car_rounded,
                                                      size: 22,
                                                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          if (car.nickname != null && car.nickname!.trim().isNotEmpty)
                                                            Text(
                                                              car.nickname!.trim(),
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.w600,
                                                                color: AppColors.gold1,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          Text(
                                                            car.displayName,
                                                            style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w600,
                                                              color: AppColors.textPrimary,
                                                              height: 1.25,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            [
                                                              '${car.year} г.',
                                                              Formatters.mileage(car.mileage),
                                                              if (car.plateNumber != null && car.plateNumber!.trim().isNotEmpty)
                                                                car.plateNumber!.trim(),
                                                            ].join(' · '),
                                                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    TextButton(
                                                      onPressed: () => _openEditCarDialog(context, car),
                                                      child: const Text('Изменить'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => _confirmDeleteCar(context, ref, car, afterDeleteReselect),
                                                      child: Text('Удалить', style: TextStyle(color: AppColors.error)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: _GarageSheetScrollSelectedLayer(
                                        cars: cars,
                                        selectedId: selectedId,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await onAddCar();
                          },
                          child: const Text('Добавить автомобиль'),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

class _GarageSheetScrollSelectedLayer extends StatefulWidget {
  const _GarageSheetScrollSelectedLayer({
    required this.cars,
    required this.selectedId,
  });

  final List<Car> cars;
  final String? selectedId;

  @override
  State<_GarageSheetScrollSelectedLayer> createState() => _GarageSheetScrollSelectedLayerState();
}

class _GarageSheetScrollSelectedLayerState extends State<_GarageSheetScrollSelectedLayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scroll());
  }

  static bool _sameCarIdsInOrder(List<Car> a, List<Car> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant _GarageSheetScrollSelectedLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId == oldWidget.selectedId &&
        _sameCarIdsInOrder(widget.cars, oldWidget.cars)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scroll());
  }

  void _scroll() {
    if (!mounted) return;
    final id = widget.selectedId;
    if (id == null) return;
    if (!widget.cars.any((c) => c.id == id)) return;
    scrollWidgetToViewportCenter(GlobalObjectKey(id).currentContext);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> _openEditCarDialog(BuildContext context, Car car) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _GarageCarEditDialog(car: car),
  );
}

class _GarageCarEditDialog extends ConsumerStatefulWidget {
  const _GarageCarEditDialog({required this.car});

  final Car car;

  @override
  ConsumerState<_GarageCarEditDialog> createState() => _GarageCarEditDialogState();
}

class _GarageCarEditDialogState extends ConsumerState<_GarageCarEditDialog> {
  late final TextEditingController _nickname;
  late final TextEditingController _plate;
  late final TextEditingController _mileage;
  late final TextEditingController _vin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.car;
    _nickname = TextEditingController(text: c.nickname ?? '');
    _plate = TextEditingController(text: c.plateNumber ?? '');
    _mileage = TextEditingController(text: '${c.mileage}');
    _vin = TextEditingController(text: c.vin ?? '');
  }

  @override
  void dispose() {
    _nickname.dispose();
    _plate.dispose();
    _mileage.dispose();
    _vin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final miles = int.tryParse(_mileage.text.trim().replaceAll(' ', ''));
    if (miles == null || miles < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите корректный пробег')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await ref.read(carsProvider.notifier).updateCarDetails(
          widget.car.id,
          nickname: _nickname.text.trim(),
          licensePlate: _plate.text.trim(),
          mileage: miles,
          vin: _vin.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      title: const Text('Данные автомобиля'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.car.displayName,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nickname,
              decoration: const InputDecoration(labelText: 'Название (необязательно)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plate,
              decoration: const InputDecoration(labelText: 'Госномер'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mileage,
              decoration: const InputDecoration(labelText: 'Пробег, км'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vin,
              decoration: const InputDecoration(labelText: 'VIN'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D0D0D)),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}

Future<void> _confirmDeleteCar(
  BuildContext context,
  WidgetRef ref,
  Car car,
  Future<void> Function(String deletedId) afterDelete,
) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardBg,
      title: const Text('Удалить автомобиль?'),
      content: Text(
        'Будет удалена карточка «${car.displayName}». История заказов в приложении сохранится, если она была привязана к этому авто.',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Удалить', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  final ok = await ref.read(carsProvider.notifier).deleteCar(car.id);
  if (!context.mounted) return;
  if (ok) {
    await afterDelete(car.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Автомобиль удалён')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось удалить')),
    );
  }
}
