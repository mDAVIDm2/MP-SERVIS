import '../../../../core/settings/maintenance_reminders_provider.dart';

/// ID услуг каталога для предзаполнения записи / фильтра поиска.
List<String> maintenanceBookingServiceIds(MaintenanceType type) {
  switch (type) {
    case MaintenanceType.oil:
      return ['s1', 's2'];
    case MaintenanceType.brakes:
      return ['s6'];
    case MaintenanceType.antifreeze:
      return ['s8'];
    case MaintenanceType.battery:
      return ['s5'];
    case MaintenanceType.tires:
      return ['s10'];
    case MaintenanceType.inspection:
      return ['s5'];
    case MaintenanceType.general:
      return ['s1', 's2', 's3'];
    default:
      return ['s1'];
  }
}
