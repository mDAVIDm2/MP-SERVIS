import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../screens/maintenance_reminder_detail_screen.dart';
import 'compact_maintenance_reminder_tile.dart';

/// Секция напоминаний ТО для одной машины: плитки + «Добавить напоминание».
class CarMaintenanceRemindersSection extends ConsumerWidget {
  const CarMaintenanceRemindersSection({
    super.key,
    required this.car,
    required this.availableTypes,
  });

  final Car car;
  final List<MaintenanceType> availableTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maintenanceRemindersProvider);
    final configsForCar = state.configs.where((c) => c.carId == car.id).toList();
    final addedTypes = MaintenanceType.values
        .where((t) => configsForCar.any((c) => MaintenanceType.fromTypeKey(c.typeKey) == t))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...addedTypes.map(
          (type) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CompactMaintenanceReminderTile(
              car: car,
              type: type,
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MaintenanceReminderDetailScreen(car: car, type: type),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddSheet(context, ref, car, availableTypes),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Добавить напоминание'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, Car car, List<MaintenanceType> types) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final notifier = ref.read(maintenanceRemindersProvider.notifier);
          return _AddReminderSheet(car: car, notifier: notifier, availableTypes: types);
        },
      ),
    );
  }
}

class _AddReminderSheet extends ConsumerWidget {
  const _AddReminderSheet({
    required this.car,
    required this.notifier,
    required this.availableTypes,
  });

  final Car car;
  final MaintenanceRemindersNotifier notifier;
  final List<MaintenanceType> availableTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(maintenanceRemindersProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'Выберите услугу',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary.withValues(alpha: 0.95),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Для масла сразу задаются 8000 км и раз в год — можно изменить в карточке.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: availableTypes.length,
                itemBuilder: (context, index) {
                  final type = availableTypes[index];
                  final isAdded = notifier.getConfig(car.id, type.name) != null;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    title: Text(
                      type.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      type.subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: isAdded
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24)
                        : const Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: 24),
                    onTap: () {
                      if (!isAdded) {
                        notifier.setConfig(MaintenanceType.defaultConfigFor(car.id, type));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Добавлено: ${type.title}'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          Navigator.pop(context);
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MaintenanceReminderDetailScreen(car: car, type: type),
                            ),
                          );
                        }
                      } else {
                        Navigator.pop(context);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => MaintenanceReminderDetailScreen(car: car, type: type),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
