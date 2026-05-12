/// Ключи локального хранилища и полей JSON `users.client_app_state` на сервере.
abstract final class ClientAppStateSchema {
  /// Префикс ключа SharedPreferences для JSON-списка заметок (`profile_notes_v1_<userId>`).
  static const String profileNotesPrefix = 'profile_notes_v1_';

  /// Поле в объекте payload на сервере: строка режима темы (`dark` / `light` / `system`).
  static const String serverKeyThemeMode = 'theme_mode';

  /// Поле в payload: JSON-строка массива заметок (как в prefs).
  static const String serverKeyProfileNotes = 'profile_notes_json';

  // --- История ТО / напоминания (те же строки, что в [MaintenanceRemindersNotifier]) ---

  static String prefsMaintenanceConfigKey(String userId) => 'maintenance_reminder_config_$userId';
  static String prefsMaintenanceRecordsKey(String userId) => 'maintenance_records_$userId';
  static String prefsMaintenanceSyncedOrderIdsKey(String userId) => 'maintenance_synced_order_ids_$userId';

  /// JSON-массив конфигов интервалов (как в prefs).
  static const String serverKeyMaintenanceConfigsJson = 'maintenance_reminder_configs_json';
  /// JSON-массив записей замен (в т.ч. вручную).
  static const String serverKeyMaintenanceRecordsJson = 'maintenance_reminder_records_json';
  /// JSON-массив id заказов, уже учтённых при автосинхроне из заказов.
  static const String serverKeyMaintenanceSyncedOrderIdsJson = 'maintenance_synced_order_ids_json';

  /// JSON-массив id избранных СТО (как `favorite_sto_ids_<userId>`).
  static const String serverKeyFavoriteStoGlobalJson = 'favorite_sto_global_ids_json';
  /// JSON-объект `carId -> [stoId]` (как `per_car_favorite_sto_ids_<userId>`).
  static const String serverKeyFavoriteStoPerCarJson = 'favorite_sto_per_car_ids_json';
}
