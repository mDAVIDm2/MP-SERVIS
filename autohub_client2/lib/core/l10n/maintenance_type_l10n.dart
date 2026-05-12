import '../settings/maintenance_reminders_provider.dart';
import 'app_l10n.dart';

/// Секции списка видов ТО (листы выбора и записи).
List<({String title, List<MaintenanceType> types})> maintenanceTypeSections(AppL10n l) => [
      (
        title: l.maintSectionEngine,
        types: [
          MaintenanceType.oil,
          MaintenanceType.airFilter,
          MaintenanceType.antifreeze,
          MaintenanceType.brakeFluid,
          MaintenanceType.atf,
          MaintenanceType.timingBelt,
          MaintenanceType.sparkPlugs,
        ],
      ),
      (
        title: l.maintSectionFilters,
        types: [
          MaintenanceType.cabinFilter,
          MaintenanceType.fuelFilter,
        ],
      ),
      (
        title: l.maintSectionBrakes,
        types: [
          MaintenanceType.brakes,
          MaintenanceType.tires,
          MaintenanceType.alignment,
          MaintenanceType.suspension,
        ],
      ),
      (
        title: l.maintSectionElectric,
        types: [
          MaintenanceType.battery,
          MaintenanceType.inspection,
          MaintenanceType.wiperBlades,
          MaintenanceType.general,
        ],
      ),
    ];

/// Локализованные названия видов работ (в enum хранятся русские строки для сопоставления с заказами).
extension MaintenanceTypeL10n on MaintenanceType {
  String localizedTitle(AppL10n l) {
    if (!l.isEn) return title;
    switch (this) {
      case MaintenanceType.oil:
        return 'Engine oil and oil filter';
      case MaintenanceType.airFilter:
        return 'Air filter replacement';
      case MaintenanceType.antifreeze:
        return 'Coolant (antifreeze) replacement';
      case MaintenanceType.brakes:
        return 'Brake pads / discs';
      case MaintenanceType.tires:
        return 'Tires (seasonal change)';
      case MaintenanceType.battery:
        return 'Battery';
      case MaintenanceType.inspection:
        return 'Vehicle inspection';
      case MaintenanceType.timingBelt:
        return 'Timing belt';
      case MaintenanceType.suspension:
        return 'Suspension / shock absorbers';
      case MaintenanceType.sparkPlugs:
        return 'Spark plugs';
      case MaintenanceType.alignment:
        return 'Wheel alignment';
      case MaintenanceType.general:
        return 'General maintenance';
      case MaintenanceType.cabinFilter:
        return 'Cabin air filter';
      case MaintenanceType.fuelFilter:
        return 'Fuel filter replacement';
      case MaintenanceType.brakeFluid:
        return 'Brake fluid replacement';
      case MaintenanceType.atf:
        return 'Automatic transmission fluid (ATF) replacement';
      case MaintenanceType.wiperBlades:
        return 'Wiper blades replacement';
    }
  }

  String localizedSubtitle(AppL10n l) {
    if (!l.isEn) return subtitle;
    switch (this) {
      case MaintenanceType.oil:
        return 'Two catalog services, done together; one interval';
      case MaintenanceType.airFilter:
      case MaintenanceType.antifreeze:
      case MaintenanceType.timingBelt:
      case MaintenanceType.sparkPlugs:
      case MaintenanceType.cabinFilter:
      case MaintenanceType.fuelFilter:
      case MaintenanceType.brakeFluid:
      case MaintenanceType.atf:
      case MaintenanceType.general:
        return 'Per manufacturer schedule';
      case MaintenanceType.brakes:
      case MaintenanceType.suspension:
        return 'Based on wear';
      case MaintenanceType.tires:
        return 'Seasonal';
      case MaintenanceType.battery:
        return 'Based on condition';
      case MaintenanceType.inspection:
        return 'Annual';
      case MaintenanceType.alignment:
        return 'After tires or suspension work';
      case MaintenanceType.wiperBlades:
        return 'Wear and season';
    }
  }
}
