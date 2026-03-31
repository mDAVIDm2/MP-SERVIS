import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/shell_navigation_provider.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import 'maintenance_booking_services.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';

/// Позиция ТО, попадающая под порог предупреждения (км / дни).
class MaintenanceUrgentSuggestion {
  const MaintenanceUrgentSuggestion({
    required this.type,
    required this.title,
    required this.bodyLines,
    required this.serviceIds,
  });

  final MaintenanceType type;
  final String title;
  final List<String> bodyLines;
  final List<String> serviceIds;
}

/// Срочные рекомендации по напоминаниям ТО для [carId] при текущем [mileage].
List<MaintenanceUrgentSuggestion> listUrgentMaintenanceSuggestions({
  required MaintenanceRemindersNotifier notifier,
  required String carId,
  required int mileage,
  required int warnKm,
  required int warnDays,
}) {
  final df = DateFormat('dd.MM.yyyy');
  final sep = NumberFormat.decimalPattern('ru_RU');
  final urgent = <MaintenanceUrgentSuggestion>[];

  for (final t in MaintenanceType.values) {
    final cfg = notifier.getConfig(carId, t.name);
    if (cfg == null || !cfg.remindEnabled) continue;
    final snap = notifier.computeDue(carId, t.name, mileage);
    if (snap.lastRecord == null) continue;

    var hit = false;
    final lines = <String>[];
    if (cfg.useKmInterval && snap.kmRemaining != null) {
      if (snap.kmRemaining! <= warnKm) {
        hit = true;
        if (snap.overdueByKm) {
          lines.add('По пробегу: просрочено на ${sep.format(-snap.kmRemaining!)} км');
        } else {
          lines.add('По пробегу: осталось ≈ ${sep.format(snap.kmRemaining!)} км');
        }
        if (snap.nextDueKm != null) {
          lines.add('Замена потребуется на ≈ ${sep.format(snap.nextDueKm!)} км');
        }
      }
    }
    if (cfg.useMonthsInterval && snap.daysRemaining != null) {
      if (snap.daysRemaining! <= warnDays) {
        hit = true;
        if (snap.overdueByDate) {
          lines.add('По сроку: просрочено');
        } else {
          lines.add('По сроку: осталось ≈ ${snap.daysRemaining} дн.');
        }
        if (snap.nextDueDate != null) {
          lines.add('Плановая дата: до ${df.format(snap.nextDueDate!)}');
        }
      }
    }
    if (!hit) continue;

    urgent.add(MaintenanceUrgentSuggestion(
      type: t,
      title: t.title,
      bodyLines: lines,
      serviceIds: maintenanceBookingServiceIds(t),
    ));
  }

  return urgent;
}

/// Запись: избранная точка с услугами или вкладка поиска с фильтром.
Future<void> openMaintenanceBookingForServices(
  BuildContext context,
  WidgetRef ref,
  List<String> serviceIds,
) async {
  final favAsync = ref.read(favoriteSTOsListProvider);
  var list = favAsync.valueOrNull ?? [];
  if (list.isEmpty && favAsync.isLoading) {
    try {
      list = await ref.read(favoriteSTOsListProvider.future);
    } catch (_) {
      list = [];
    }
  }

  if (!context.mounted) return;

  if (list.isNotEmpty) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => STODetailScreen(
          sto: list.first,
          initialServiceIds: serviceIds.isNotEmpty ? serviceIds : null,
        ),
      ),
    );
  } else {
    final ids = serviceIds.isNotEmpty ? serviceIds : ['s1', 's2'];
    ref.read(openSearchWithServicesProvider.notifier).state = List<String>.from(ids);
  }
}
