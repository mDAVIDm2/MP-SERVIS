import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';
import '../utils/maintenance_booking_services.dart';

/// Для типа напоминания — ID услуг каталога API для экрана записи.
List<String> _serviceIdsForReminderType(ReminderType type) {
  switch (type) {
    case ReminderType.oil:
      return maintenanceBookingServiceIds(MaintenanceType.oil);
    case ReminderType.brakes:
      return maintenanceBookingServiceIds(MaintenanceType.brakes);
    case ReminderType.antifreeze:
      return maintenanceBookingServiceIds(MaintenanceType.antifreeze);
    case ReminderType.battery:
      return maintenanceBookingServiceIds(MaintenanceType.battery);
    case ReminderType.tires:
      return maintenanceBookingServiceIds(MaintenanceType.tires);
    case ReminderType.maintenance:
      return maintenanceBookingServiceIds(MaintenanceType.general);
    case ReminderType.inspection:
      return maintenanceBookingServiceIds(MaintenanceType.inspection);
    case ReminderType.osago:
      return [];
  }
}

class ReminderCard extends ConsumerWidget {
  final CarReminder reminder;

  const ReminderCard({super.key, required this.reminder});

  /// Цвет акцента карточки (подложка и кнопка)
  Color _statusColor(BuildContext context) {
    switch (reminder.status) {
      case ReminderStatus.overdue:
        return context.palette.error;
      case ReminderStatus.upcoming:
        return context.palette.warning;
      case ReminderStatus.ok:
        return context.palette.info;
    }
  }

  /// Одна короткая строка: остаток / просрочка по пробегу.
  String _subtitle(BuildContext context) {
    final l10n = L10nScope.of(context);
    if (reminder.recommendedMileage > 0) {
      final diff = reminder.recommendedMileage - reminder.currentMileage;
      if (reminder.status == ReminderStatus.overdue) {
        return l10n.reminderOverdueMileage(l10n.mileageValue(diff));
      }
      if (reminder.status == ReminderStatus.upcoming && diff > 0) {
        return l10n.reminderLeftMileage(l10n.mileageValue(diff));
      }
    }
    return reminder.statusText;
  }

  /// Светлый фон карточки в тон статуса (как на референсе)
  Color _cardBackground(BuildContext context) {
    switch (reminder.status) {
      case ReminderStatus.overdue:
        return context.palette.error.withValues(alpha: 0.12);
      case ReminderStatus.upcoming:
        return context.palette.warning.withValues(alpha: 0.15);
      case ReminderStatus.ok:
        return context.palette.info.withValues(alpha: 0.12);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteList = ref.watch(favoriteSTOsListProvider).valueOrNull ?? [];
    final linkedSto = favoriteList.isNotEmpty ? favoriteList.first : null;
    final initialServiceIds = _serviceIdsForReminderType(reminder.type);

    return Container(
      decoration: BoxDecoration(
        color: _cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor(context).withValues(alpha: 0.35), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusColor(context).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(reminder.icon, style: TextStyle(fontSize: 20))),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  _subtitle(context),
                  style: TextStyle(
                    fontSize: 13,
                    color: reminder.status == ReminderStatus.overdue
                        ? context.palette.error
                        : context.palette.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: linkedSto == null
                  ? null
                  : () {
                      pushStoDetailScreen(
                        context,
                        STODetailScreen(
                          sto: linkedSto,
                          initialServiceIds: initialServiceIds.isEmpty ? null : initialServiceIds,
                          mergeOilEngineWithFilter: false,
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: linkedSto == null ? context.palette.textTertiary : context.palette.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
