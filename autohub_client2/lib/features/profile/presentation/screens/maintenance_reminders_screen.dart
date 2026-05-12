import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/filter_by_car_setting.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../core/settings/maintenance_warn_threshold_provider.dart';
import '../../../../shared/models/car_model.dart';
import '../../../../core/onboarding/garage_first_car_tutorial_provider.dart';
import '../../../../core/onboarding/garage_tutorial_target.dart';
import '../widgets/car_maintenance_reminders_section.dart';
import '../widgets/add_maintenance_record_sheet.dart';

/// Экран «Напоминания о ТО»: компактные карточки с полосой прогресса, деталь по нажатию.
class MaintenanceRemindersScreen extends ConsumerStatefulWidget {
  const MaintenanceRemindersScreen({super.key, this.initialCarId});

  final String? initialCarId;

  @override
  ConsumerState<MaintenanceRemindersScreen> createState() => _MaintenanceRemindersScreenState();
}

class _MaintenanceRemindersScreenState extends ConsumerState<MaintenanceRemindersScreen> {
  bool _showOtherCars = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = ref.read(garageFirstCarTutorialProvider);
      if (t.active && t.step == GarageFirstCarTutorialStep.garageReminders) {
        ref.read(garageFirstCarTutorialProvider.notifier).setStep(GarageFirstCarTutorialStep.maintenanceIntro);
      }
    });
  }

  void _showWarnThresholdsDialog(BuildContext context, WidgetRef ref) {
    final l10n = L10nScope.of(context);
    final kmCtrl = TextEditingController(text: '${ref.read(maintenanceWarnWithinKmProvider)}');
    final daysCtrl = TextEditingController(text: '${ref.read(maintenanceWarnWithinDaysProvider)}');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text(l10n.maintWhenShowRecTitle, style: TextStyle(color: context.palette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.maintWhenShowRecHint,
              style: TextStyle(fontSize: 13, color: context.palette.textSecondary, height: 1.35),
            ),
            SizedBox(height: 12),
            TextField(
              controller: kmCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.maintKmThresholdLabel,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.maintDaysThresholdLabel,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () async {
              final km = int.tryParse(kmCtrl.text.trim());
              final d = int.tryParse(daysCtrl.text.trim());
              if (km != null) await ref.read(maintenanceWarnWithinKmProvider.notifier).setKm(km);
              if (d != null) await ref.read(maintenanceWarnWithinDaysProvider.notifier).setDays(d);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.save, style: TextStyle(color: context.palette.primary)),
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
    final l10n = L10nScope.of(context);
    final carsAsync = ref.watch(carsProvider);
    final ordersAsync = ref.watch(ordersProvider);
    ref.watch(maintenanceRemindersProvider);
    final selectedId = ref.watch(selectedCarIdProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        title: Text(
          l10n.maintenanceReminders,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.maintWhenShowTooltip,
            icon: Icon(Icons.tune_rounded, color: context.palette.textSecondary),
            onPressed: () => _showWarnThresholdsDialog(context, ref),
          ),
        ],
      ),
      body: carsAsync.when(
        data: (cars) {
          if (cars.isEmpty) {
            return Center(
              child: Text(
                l10n.maintAddCarFirst,
                style: TextStyle(fontSize: 14, color: context.palette.textSecondary),
              ),
            );
          }
          final orders = ordersAsync.valueOrNull ?? [];
          final ordersFailed = ordersAsync.hasError;
          final notifier = ref.read(maintenanceRemindersProvider.notifier);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.syncFromOrders(orders, cars);
          });

          final primary = _resolvePrimaryCar(cars, selectedId);
          final otherCars = cars.where((c) => c.id != primary.id).toList();
          final types = ref.watch(availableMaintenanceTypesProvider);
          final hasManualHistory = ref.watch(
            maintenanceRemindersProvider.select(
              (s) => s.records.any((r) => r.carId == primary.id),
            ),
          );

          void openLogSheet() => showAddMaintenanceRecordSheet(
                context,
                ref,
                cars: cars,
                initialCar: primary,
              );

          final logCard = hasManualHistory
              ? Material(
                  color: context.palette.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: openLogSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.palette.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.post_add_rounded, color: context.palette.primary, size: 24),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.maintLogDoneTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.palette.textPrimary.withValues(alpha: 0.96),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  l10n.maintLogDoneSubtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.textSecondary.withValues(alpha: 0.92),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: context.palette.textTertiary),
                        ],
                      ),
                    ),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: double.infinity,
                    height: 96,
                    child: FilledButton.tonal(
                      onPressed: openLogSheet,
                      style: FilledButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.palette.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.post_add_rounded, color: context.palette.primary, size: 26),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.maintLogDoneTitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.palette.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  l10n.maintLogDoneSubtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.textSecondary,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: context.palette.textTertiary),
                        ],
                      ),
                    ),
                  ),
                );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.palette.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.palette.primary.withValues(alpha: 0.15)),
                ),
                child: Text(
                  l10n.maintIntroOneLine,
                  style: TextStyle(fontSize: 13, color: context.palette.textSecondary, height: 1.35),
                ),
              ),
              if (ordersFailed) ...[
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.palette.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.warning.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    l10n.maintOrdersLoadFailedHint,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 14),
              GarageTutorialTarget(
                highlightStep: GarageFirstCarTutorialStep.maintenanceHistory,
                child: logCard,
              ),
              SizedBox(height: 20),
              Text(
                primary.displayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              GarageTutorialTarget(
                highlightStep: GarageFirstCarTutorialStep.maintenanceIntro,
                child: CarMaintenanceRemindersSection(
                  car: primary,
                  availableTypes: types,
                ),
              ),
              if (otherCars.isNotEmpty) ...[
                SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _showOtherCars = !_showOtherCars),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.palette.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showOtherCars ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: context.palette.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _showOtherCars
                                  ? l10n.maintHideOtherCars
                                  : l10n.maintShowOtherCars(otherCars.length),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.palette.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showOtherCars) ...[
                  SizedBox(height: 16),
                  ...otherCars.expand((car) => [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Text(
                            car.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.palette.textSecondary,
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
        loading: () => Center(child: CircularProgressIndicator(color: context.palette.primary)),
        error: (e, _) => Center(child: Text(l10n.errorColon(e), style: TextStyle(color: context.palette.error))),
      ),
    );
  }
}
