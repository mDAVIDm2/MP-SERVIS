import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Тот же хост по умолчанию, что в `autohub_business`, чтобы панель и Business смотрели на один API без `--dart-define`.
  /// Локальная сеть по умолчанию: `192.168.1.186` (можно переопределить через `--dart-define=AUTOHUB_API_HOST=...`).
  static const String _apiHostFromEnv = String.fromEnvironment(
    'AUTOHUB_API_HOST',
    defaultValue: '192.168.1.186',
  );
  static String get apiHost {
    if (_apiHostFromEnv.isNotEmpty) return _apiHostFromEnv;
    if (kIsWeb) return '192.168.1.186';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return '127.0.0.1';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return '192.168.1.186';
      default:
        return '192.168.1.186';
    }
  }

  static const int apiPort = 3000;
  static const String apiPath = '/api/v1';

  static const String environment = String.fromEnvironment(
    'AUTOHUB_ENV',
    defaultValue: 'dev',
  );

  /// Base URL с завершающим слэшем для корректной склейки путей в Dio.
  static String get baseUrl => 'http://$apiHost:$apiPort$apiPath/';
}
