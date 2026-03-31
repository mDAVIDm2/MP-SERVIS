import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/settings/maintenance_warn_threshold_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../profile/presentation/screens/maintenance_reminder_detail_screen.dart';
import '../../../profile/presentation/widgets/compact_maintenance_reminder_tile.dart';
import '../utils/maintenance_after_mileage.dart';

/// Блок «Рекомендации»: срочные позиции из напоминаний о ТО (порог км/дней) + запись.
class GarageMaintenanceRecommendationsBlock extends ConsumerWidget {
  const GarageMaintenanceRecommendationsBlock({super.key, required this.car});

  final Car car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (car.id.isEmpty) return const SizedBox.shrink();

    ref.watch(maintenanceRemindersProvider);
    final notifier = ref.read(maintenanceRemindersProvider.notifier);
    final warnKm = ref.watch(maintenanceWarnWithinKmProvider);
    final warnDays = ref.watch(maintenanceWarnWithinDaysProvider);

    final urgent = listUrgentMaintenanceSuggestions(
      notifier: notifier,
      carId: car.id,
      mileage: car.mileage,
      warnKm: warnKm,
      warnDays: warnDays,
    );

    if (urgent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppDesignSystem.blockSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Рекомендации', compact: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.pagePaddingH),
            child: Column(
              children: urgent.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UrgentRecommendationCard(
                      suggestion: u,
                      car: car,
                    ),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentRecommendationCard extends ConsumerWidget {
  const _UrgentRecommendationCard({
    required this.suggestion,
    required this.car,
  });

  final MaintenanceUrgentSuggestion suggestion;
  final Car car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = CompactMaintenanceReminderTile.emojiFor(suggestion.type);
    final visibleLines = suggestion.bodyLines.take(2).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
        border: Border.all(color: AppColors.strokeGold.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...visibleLines.map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          l,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (suggestion.bodyLines.length > visibleLines.length)
                      const Text(
                        'Подробнее в карточке',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MaintenanceReminderDetailScreen(
                          car: car,
                          type: suggestion.type,
                        ),
                      ),
                    );
                  },
                  child: const Text('Подробнее'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => openMaintenanceBookingForServices(
                    context,
                    ref,
                    suggestion.serviceIds,
                  ),
                  child: const Text('Записаться'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
