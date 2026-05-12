import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/l10n/maintenance_type_l10n.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/shell_navigation_provider.dart';
import '../../../../core/settings/favorite_sto_ids_provider.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/catalog/client_catalog_service_ids.dart';
import 'maintenance_booking_services.dart';
import '../../../search/presentation/screens/sto_detail_screen.dart';

/// Строка текста в карточке срочной рекомендации (цвет по [accentError]).
class MaintenanceUrgentLine {
  const MaintenanceUrgentLine(this.text, {this.accentError = false});

  final String text;
  final bool accentError;
}

/// Позиция ТО, попадающая под порог предупреждения (км / дни).
class MaintenanceUrgentSuggestion {
  const MaintenanceUrgentSuggestion({
    required this.type,
    required this.title,
    required this.bodyLines,
    required this.serviceIds,
    this.urgencyProgress = 0,
  });

  final MaintenanceType type;
  final String title;
  final List<MaintenanceUrgentLine> bodyLines;
  final List<String> serviceIds;

  /// 0…1: чем выше, тем ближе к плановой замене (см. [MaintenanceDueSnapshot.progress01]).
  final double urgencyProgress;
}

/// Срочные рекомендации по напоминаниям ТО для [carId] при текущем [mileage].
List<MaintenanceUrgentSuggestion> listUrgentMaintenanceSuggestions({
  required AppL10n l10n,
  required MaintenanceRemindersNotifier notifier,
  required String carId,
  required int mileage,
  required int warnKm,
  required int warnDays,
}) {
  final df = DateFormat('dd.MM.yyyy', l10n.locale.languageCode);
  final sep = NumberFormat.decimalPattern(l10n.intlLocale);
  final urgent = <MaintenanceUrgentSuggestion>[];

  for (final t in MaintenanceType.values) {
    final cfg = notifier.getConfig(carId, t.name);
    if (cfg == null || !cfg.remindEnabled) continue;
    final snap = notifier.computeDue(carId, t.name, mileage);
    if (snap.lastRecord == null) continue;

    var hit = false;
    final lines = <MaintenanceUrgentLine>[];
    if (cfg.useKmInterval && snap.kmRemaining != null) {
      if (snap.kmRemaining! <= warnKm) {
        hit = true;
        if (snap.overdueByKm) {
          lines.add(
            MaintenanceUrgentLine(
              l10n.maintUrgentKmOverdue(sep.format(snap.kmRemaining!)),
              accentError: true,
            ),
          );
        } else {
          lines.add(
            MaintenanceUrgentLine(
              l10n.maintUrgentKmLeft(sep.format(snap.kmRemaining!)),
            ),
          );
        }
        if (snap.nextDueKm != null) {
          lines.add(MaintenanceUrgentLine(l10n.maintUrgentNextKm(sep.format(snap.nextDueKm!))));
        }
      }
    }
    if (cfg.useMonthsInterval && snap.daysRemaining != null) {
      if (snap.daysRemaining! <= warnDays) {
        hit = true;
        if (snap.overdueByDate) {
          final d = snap.daysRemaining!;
          if (d < 0) {
            lines.add(
              MaintenanceUrgentLine(
                l10n.maintUrgentDateOverdueByDays(sep.format(d)),
                accentError: true,
              ),
            );
          } else {
            lines.add(
              MaintenanceUrgentLine(
                l10n.maintUrgentDateOverdueLine,
                accentError: true,
              ),
            );
          }
        } else {
          lines.add(
            MaintenanceUrgentLine(
              l10n.maintUrgentDateLeftLine(snap.daysRemaining!),
            ),
          );
        }
        if (snap.nextDueDate != null) {
          lines.add(MaintenanceUrgentLine(l10n.maintUrgentPlanUntil(df.format(snap.nextDueDate!))));
        }
      }
    }
    if (!hit) continue;

    urgent.add(MaintenanceUrgentSuggestion(
      type: t,
      title: t.localizedTitle(l10n),
      bodyLines: lines,
      serviceIds: maintenanceBookingServiceIds(t),
      urgencyProgress: snap.progress01,
    ));
  }

  urgent.sort((a, b) => b.urgencyProgress.compareTo(a.urgencyProgress));
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
    await pushStoDetailScreen<void>(
      context,
      STODetailScreen(
        sto: list.first,
        initialServiceIds: serviceIds.isNotEmpty ? serviceIds : null,
        mergeOilEngineWithFilter: false,
      ),
    );
  } else {
    final ids = serviceIds.isNotEmpty
        ? serviceIds
        : [ClientCatalogServiceIds.oilEngine];
    ref.read(openSearchWithServicesProvider.notifier).state = List<String>.from(ids);
  }
}
