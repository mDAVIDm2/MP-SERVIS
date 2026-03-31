import 'package:flutter/foundation.dart';

/// Конфигурация приложения. URL бэкенда: `--dart-define=AUTOHUB_API_HOST=...` или умолчание по платформе.
///
/// **Почему на телефоне «нет сети», а на ПК всё ок**
/// - **Android 9+** и cleartext: в манифесте `android:usesCleartextTraffic="true"` (в проекте включено).
/// - **`127.0.0.1` на физическом телефоне** — это сам телефон, не ПК с Nest; для Android без
///   `dart-define` используется LAN-хост ниже; иначе задайте IP ПК вручную.
/// - **Эмулятор Android** к хосту часто удобнее `10.0.2.2`:  
///   `flutter run --dart-define=AUTOHUB_API_HOST=10.0.2.2`
/// - **USB + adb reverse**: `adb reverse tcp:3000 tcp:3000` и тогда можно  
///   `--dart-define=AUTOHUB_API_HOST=127.0.0.1`
/// - **Брандмауэр Windows**: входящий TCP на порт Nest (часто 3000).
///
/// Пример: `flutter run --dart-define=AUTOHUB_API_HOST=192.168.1.186`
class AppConfig {
  AppConfig._();

  /// Явно заданный хост (пусто = взять платформенное умолчание).
  static const String _apiHostFromEnv = String.fromEnvironment(
    'AUTOHUB_API_HOST',
    defaultValue: '',
  );

  /// LAN IP машины с Nest для **мобильных** сборок без `AUTOHUB_API_HOST` (Android / iOS).
  /// Переопределение: `--dart-define=AUTOHUB_DEFAULT_LAN_HOST=…` или полный хост через `AUTOHUB_API_HOST`.
  static const String _defaultMobileLanHost = String.fromEnvironment(
    'AUTOHUB_DEFAULT_LAN_HOST',
    defaultValue: '192.168.1.186',
  );

  static bool get apiHostFromDartDefine => _apiHostFromEnv.isNotEmpty;

  /// Хост API (без схемы).
  static String get apiHost {
    if (_apiHostFromEnv.isNotEmpty) return _apiHostFromEnv;
    if (kIsWeb) return _defaultMobileLanHost;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        // На desktop API и БД часто подняты на этом же ПК.
        return '127.0.0.1';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _defaultMobileLanHost;
      default:
        return _defaultMobileLanHost;
    }
  }

  static const int apiPort = 3000;
  static const String apiPath = '/api/v1';
  static const String wsPath = '/ws';

  /// WebSocket опционален: при false чаты работают через REST refetch. Для dev: --dart-define=AUTOHUB_ENABLE_WS=false
  static const bool enableWs = bool.fromEnvironment(
    'AUTOHUB_ENABLE_WS',
    defaultValue: false,
  );

  static String get baseUrl => 'http://$apiHost:$apiPort$apiPath';
  static String get wsUrl => 'ws://$apiHost:$apiPort$wsPath';
}
