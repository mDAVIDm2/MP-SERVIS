import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';

/// Для типа напоминания — ID услуг, которые подставлять в экран записи.
List<String> _serviceIdsForReminderType(ReminderType type) {
  switch (type) {
    case ReminderType.oil: return ['s1', 's2'];
    case ReminderType.brakes: return ['s6'];
    case ReminderType.antifreeze: return ['s8'];
    case ReminderType.battery: return ['s5'];
    case ReminderType.tires: return ['s10'];
    case ReminderType.maintenance: return ['s1', 's2', 's3'];
    case ReminderType.inspection: return ['s5'];
    case ReminderType.osago: return [];
  }
}

class ReminderCard extends ConsumerWidget {
  final CarReminder reminder;

  const ReminderCard({super.key, required this.reminder});

  /// Цвет акцента карточки (подложка и кнопка)
  Color get _statusColor {
    switch (reminder.status) {
      case ReminderStatus.overdue: return AppColors.error;
      case ReminderStatus.upcoming: return AppColors.warning;
      case ReminderStatus.ok: return AppColors.info;
    }
  }

  /// Одна короткая строка: «Осталось ~1200 км» / «Просрочено на 2 850 км» (Formatters.mileage уже добавляет «км»)
  String get _subtitle {
    if (reminder.recommendedMileage > 0) {
      final diff = reminder.recommendedMileage - reminder.currentMileage;
      if (reminder.status == ReminderStatus.overdue) {
        return 'Просрочено на ${Formatters.mileage(-diff)}';
      }
      if (reminder.status == ReminderStatus.upcoming && diff > 0) {
        return 'Осталось ~${Formatters.mileage(diff)}';
      }
    }
    return reminder.statusText;
  }

  /// Светлый фон карточки в тон статуса (как на референсе)
  Color get _cardBackground {
    switch (reminder.status) {
      case ReminderStatus.overdue:
        return AppColors.error.withValues(alpha: 0.12);
      case ReminderStatus.upcoming:
        return AppColors.warning.withValues(alpha: 0.15);
      case ReminderStatus.ok:
        return AppColors.info.withValues(alpha: 0.12);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteList = ref.watch(favoriteSTOsListProvider).valueOrNull ?? [];
    final linkedSto = favoriteList.isNotEmpty ? favoriteList.first : null;
    final initialServiceIds = _serviceIdsForReminderType(reminder.type);

    return Container(
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withValues(alpha: 0.35), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(reminder.icon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  reminder.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: linkedSto == null
                  ? null
                  : () {
                      pushCupertino(
                        context,
                        STODetailScreen(
                          sto: linkedSto,
                          initialServiceIds: initialServiceIds.isEmpty ? null : initialServiceIds,
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: linkedSto == null ? AppColors.textTertiary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
