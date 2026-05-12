import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Если задан полный [MP_SERVIS_API_BASE_URL], хост из окружения не используется.
  /// Иначе — хост локального Nest (для разработки без базового URL).
  static const String _apiHostFromEnv = String.fromEnvironment(
    'MP_SERVIS_API_HOST',
    defaultValue: '127.0.0.1',
  );
  static String get apiHost {
    if (_apiHostFromEnv.isNotEmpty) return _apiHostFromEnv;
    if (kIsWeb) return '127.0.0.1';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return '127.0.0.1';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return '10.0.2.2';
      default:
        return '127.0.0.1';
    }
  }

  static const int apiPort = int.fromEnvironment('MP_SERVIS_API_PORT', defaultValue: 3001);
  static const String apiPath = '/api/v1';

  static const String environment = String.fromEnvironment(
    'MP_SERVIS_ENV',
    defaultValue: 'dev',
  );

  /// По умолчанию продакшен MP-Servis. Для локального Nest: `--dart-define=MP_SERVIS_API_BASE_URL=http://127.0.0.1:3001/api/v1`
  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'MP_SERVIS_API_BASE_URL',
    defaultValue: 'https://api.mp-servis.ru',
  );

  /// Base URL с завершающим слэшем для корректной склейки путей в Dio.
  static String get baseUrl {
    final raw = _apiBaseUrlFromEnv.trim();
    if (raw.isEmpty) {
      return 'http://$apiHost:$apiPort$apiPath/';
    }
    var u = raw;
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/api/v1')) {
      u = '$u/api/v1';
    }
    return '$u/';
  }
}
