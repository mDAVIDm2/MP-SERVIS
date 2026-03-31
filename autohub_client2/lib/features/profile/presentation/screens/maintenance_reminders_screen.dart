import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/settings/maintenance_warn_threshold_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../widgets/car_maintenance_reminders_section.dart';

/// Экран «Напоминания о ТО»: компактные карточки с полосой прогресса, деталь по нажатию.
class MaintenanceRemindersScreen extends ConsumerStatefulWidget {
  const MaintenanceRemindersScreen({super.key, this.initialCarId});

  final String? initialCarId;

  @override
  ConsumerState<MaintenanceRemindersScreen> createState() => _MaintenanceRemindersScreenState();
}

class _MaintenanceRemindersScreenState extends ConsumerState<MaintenanceRemindersScreen> {
  bool _showOtherCars = false;

  void _showWarnThresholdsDialog(BuildContext context, WidgetRef ref) {
    final kmCtrl = TextEditingController(text: '${ref.read(maintenanceWarnWithinKmProvider)}');
    final daysCtrl = TextEditingController(text: '${ref.read(maintenanceWarnWithinDaysProvider)}');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Когда показывать рекомендации', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Показывать блок, когда до замены осталось:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Километров (100–10 000)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Дней по сроку (1–90)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              final km = int.tryParse(kmCtrl.text.trim());
              final d = int.tryParse(daysCtrl.text.trim());
              if (km != null) await ref.read(maintenanceWarnWithinKmProvider.notifier).setKm(km);
              if (d != null) await ref.read(maintenanceWarnWithinDaysProvider.notifier).setDays(d);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Car _resolvePrimaryCar(List<Car> cars, String? selectedId) {
    if (cars.isEmpty) {
      throw StateError('cars empty');
    }
    final focus = widget.initialCarId;
    if (focus != null) {
      for (final c in cars) {
        if (c.id == focus) return c;
      }
    }
    if (selectedId != null) {
      for (final c in cars) {
        if (c.id == selectedId) return c;
      }
    }
    return cars.first;
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(carsProvider);
    final ordersAsync = ref.watch(ordersProvider);
    ref.watch(maintenanceRemindersProvider);
    final selectedId = ref.watch(selectedCarIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Напоминания о ТО',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Когда показывать напоминание',
            icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
            onPressed: () => _showWarnThresholdsDialog(context, ref),
          ),
        ],
      ),
      body: carsAsync.when(
        data: (cars) {
          if (cars.isEmpty) {
            return const Center(
              child: Text(
                'Добавьте автомобиль в Гараж',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            );
          }
          final orders = ordersAsync.valueOrNull ?? [];
          final notifier = ref.read(maintenanceRemindersProvider.notifier);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.syncFromOrders(orders, cars);
          });

          final primary = _resolvePrimaryCar(cars, selectedId);
          final otherCars = cars.where((c) => c.id != primary.id).toList();
          final types = ref.watch(availableMaintenanceTypesProvider);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Коротко',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Для каждого напоминания можно задать интервал по пробегу, по сроку или оба сразу.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'История подтягивается из завершённых заказов и может добавляться вручную.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                primary.displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              CarMaintenanceRemindersSection(
                car: primary,
                availableTypes: types,
              ),
              if (otherCars.isNotEmpty) ...[
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _showOtherCars = !_showOtherCars),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showOtherCars ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _showOtherCars
                                  ? 'Скрыть другие машины'
                                  : 'Показать другие машины (${otherCars.length})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showOtherCars) ...[
                  const SizedBox(height: 16),
                  ...otherCars.expand((car) => [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Text(
                            car.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        CarMaintenanceRemindersSection(car: car, availableTypes: types),
                      ]),
                ],
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}
