import '../../../../core/catalog/client_catalog_service_ids.dart';
import '../../../../core/settings/maintenance_reminders_provider.dart';

/// ID услуг каталога API для предзаполнения записи / фильтра поиска.
List<String> maintenanceBookingServiceIds(MaintenanceType type) {
  switch (type) {
    case MaintenanceType.oil:
      return [ClientCatalogServiceIds.oilEngine, ClientCatalogServiceIds.oilFilterOnly];
    case MaintenanceType.airFilter:
      return [ClientCatalogServiceIds.airFilter];
    case MaintenanceType.brakes:
      return [ClientCatalogServiceIds.brakePadsFront];
    case MaintenanceType.antifreeze:
      return [ClientCatalogServiceIds.coolant];
    case MaintenanceType.battery:
      return [ClientCatalogServiceIds.battery];
    case MaintenanceType.tires:
      return [ClientCatalogServiceIds.wheelAlignment];
    case MaintenanceType.inspection:
      return [ClientCatalogServiceIds.computerDiag];
    case MaintenanceType.timingBelt:
      return [ClientCatalogServiceIds.timingBelt];
    case MaintenanceType.suspension:
      return [ClientCatalogServiceIds.shockFront];
    case MaintenanceType.sparkPlugs:
      return [ClientCatalogServiceIds.sparkPlugs];
    case MaintenanceType.alignment:
      return [ClientCatalogServiceIds.wheelAlignment];
    case MaintenanceType.general:
      return [ClientCatalogServiceIds.oilEngine, ClientCatalogServiceIds.airFilter];
  }
}
