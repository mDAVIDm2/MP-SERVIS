/// Ключи локального хранилища и полей JSON `users.client_app_state` на сервере.
abstract final class ClientAppStateSchema {
  /// Префикс ключа SharedPreferences для JSON-списка заметок (`profile_notes_v1_<userId>`).
  static const String profileNotesPrefix = 'profile_notes_v1_';

  /// Поле в объекте payload на сервере: строка режима темы (`dark` / `light` / `system`).
  static const String serverKeyThemeMode = 'theme_mode';

  /// Поле в payload: JSON-строка массива заметок (как в prefs).
  static const String serverKeyProfileNotes = 'profile_notes_json';
}
