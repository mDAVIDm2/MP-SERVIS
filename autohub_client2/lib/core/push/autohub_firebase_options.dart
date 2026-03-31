import 'package:firebase_core/firebase_core.dart';

/// Опции Firebase для клиента.
///
/// **Вариант A — dart-define** (удобно для CI):
/// `flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=...`
/// (остальные ключи см. ниже в [currentPlatform]).
///
/// Или один файл: положите `google-services.json` в `android/app/`, выполните
/// `dart run tool/google_services_to_dart_define.dart android/app/google-services.json`
/// → получите `config/firebase_define.json`, затем
/// `flutter run --dart-define-from-file=config/firebase_define.json`
/// (в VS Code: конфигурация «autohub_client2 (dart-define-from-file)»).
///
/// **Вариант B — нативный конфиг Android:** в Firebase зарегистрируйте Android-приложение
/// с **package name = applicationId** из `android/app/build.gradle.kts` (сейчас это
/// единственный источник package name для сборки). App nickname в консоли — любое имя;
/// SHA-1 для FCM обычно не нужен (добавляйте при Google Sign-In). Положите
/// `google-services.json` в `android/app/`. Плагин `com.google.gms.google-services`
/// подключается только если файл есть — без него сборка не ломается.
///
/// **Вариант C:** `dart run flutterfire_cli:flutterfire configure` — сгенерирует
/// `firebase_options.dart`; тогда можно импортировать его и подставить в код (или
/// продолжать использовать dart-define).
class AutohubFirebaseOptions {
  AutohubFirebaseOptions._();

  static FirebaseOptions? get currentPlatform {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    if (apiKey.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: ''),
      messagingSenderId: const String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: ''),
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
    );
  }
}
