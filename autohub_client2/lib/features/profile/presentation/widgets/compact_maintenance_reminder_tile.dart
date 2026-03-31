import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../shared/models/car_model.dart';

/// Компактная карточка напоминания ТО (список экрана и гараж).
class CompactMaintenanceReminderTile extends ConsumerWidget {
  const CompactMaintenanceReminderTile({
    super.key,
    required this.car,
    required this.type,
    required this.onTap,
  });

  final Car car;
  final MaintenanceType type;
  final VoidCallback onTap;

  static String emojiFor(MaintenanceType t) {
    switch (t) {
      case MaintenanceType.oil:
        return '🛢';
      case MaintenanceType.tires:
        return '🛞';
      case MaintenanceType.battery:
        return '🔋';
      case MaintenanceType.antifreeze:
        return '❄️';
      case MaintenanceType.brakes:
        return '🔧';
      case MaintenanceType.inspection:
        return '🔍';
      default:
        return '⚙️';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(maintenanceRemindersProvider);
    final notifier = ref.read(maintenanceRemindersProvider.notifier);
    final config = notifier.getConfig(car.id, type.name);
    final snap = notifier.computeDue(car.id, type.name, car.mileage);

    final subtitle = _buildSubtitle(config, snap);
    final progress = snap.remindEnabled ? snap.progress01 : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: snap.overdue ? AppColors.error.withValues(alpha: 0.35) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(emojiFor(type), style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: snap.overdue ? AppColors.error : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: AppColors.border.withValues(alpha: 0.45),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    snap.overdue ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _buildSubtitle(MaintenanceConfig? config, MaintenanceDueSnapshot snap) {
    if (config == null) return 'Настройте интервалы';
    if (!config.remindEnabled) return 'Напоминание выключено';
    if (snap.lastRecord == null) return 'Добавьте дату замены — появится счётчик';

    final parts = <String>[];
    if (config.useKmInterval && snap.kmRemaining != null) {
      if (snap.overdueByKm) {
        parts.add('Пробег: просрочено');
      } else {
        final sep = NumberFormat.decimalPattern('ru_RU');
        parts.add('≈ ${sep.format(snap.kmRemaining)} км');
      }
    }
    if (config.useMonthsInterval && snap.daysRemaining != null) {
      if (snap.overdueByDate) {
        parts.add('Срок: просрочено');
      } else {
        parts.add('≈ ${snap.daysRemaining} дн.');
      }
    }
    if (parts.isEmpty) return 'Откройте карточку';
    return parts.join(' · ');
  }
}
