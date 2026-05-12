import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/l10n/maintenance_type_l10n.dart';
import '../../../../core/theme/client_palette.dart';
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
    final l10n = L10nScope.of(context);

    final subtitle = _buildSubtitle(config, snap, l10n);
    final progress = snap.remindEnabled ? snap.progress01 : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: context.palette.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: snap.overdue ? context.palette.error.withValues(alpha: 0.35) : context.palette.border,
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
                        color: context.palette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(emojiFor(type), style: TextStyle(fontSize: 20)),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.localizedTitle(l10n),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: snap.overdue ? context.palette.error : context.palette.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.palette.textSecondary.withValues(alpha: 0.7)),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: context.palette.border.withValues(alpha: 0.45),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    snap.overdue ? context.palette.error : context.palette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _buildSubtitle(MaintenanceConfig? config, MaintenanceDueSnapshot snap, AppL10n l) {
    if (config == null) return l.configureIntervals;
    if (!config.remindEnabled) return l.reminderDisabled;
    if (snap.lastRecord == null) return l.addReplacementDate;

    final sep = NumberFormat.decimalPattern(l.intlLocale);
    final parts = <String>[];
    if (config.useKmInterval && snap.kmRemaining != null) {
      if (snap.overdueByKm) {
        parts.add(l.maintShortKmOverdue(sep.format(snap.kmRemaining!)));
      } else {
        parts.add(l.maintShortKmLeft(sep.format(snap.kmRemaining!)));
      }
    }
    if (config.useMonthsInterval && snap.daysRemaining != null) {
      if (snap.overdueByDate) {
        final d = snap.daysRemaining!;
        if (d < 0) {
          parts.add(l.maintShortDaysOverdue(sep.format(d)));
        } else {
          parts.add(l.maintUrgentDateOverdueLine);
        }
      } else {
        parts.add(l.maintShortDaysLeft(snap.daysRemaining!));
      }
    }
    if (parts.isEmpty) return l.openCard;
    return parts.join(' · ');
  }
}
