/// Конфигурация приложения. URL бэкенда — `--dart-define=AUTOHUB_API_HOST=...` при сборке/запуске.
///
/// **Android 9+** блокирует HTTP без HTTPS, если не включён cleartext в манифесте (`usesCleartextTraffic`).
/// На **реальном телефоне** `localhost` — не ваш ПК; нужен **LAN IP**. Эмулятор Android: часто `10.0.2.2`.
///
/// Пример: `flutter run --dart-define=AUTOHUB_API_HOST=192.168.1.186`
class AppConfig {
  AppConfig._();

  static const String apiHost = String.fromEnvironment(
    'AUTOHUB_API_HOST',
    defaultValue: '192.168.1.186',
  );
  static const int apiPort = 3000;
  static const String apiPath = '/api/v1';
  static const String wsPath = '/ws';

  /// WebSocket опционален: при false обновления заказов только через REST. Для dev: --dart-define=AUTOHUB_ENABLE_WS=false
  static const bool enableWs = bool.fromEnvironment(
    'AUTOHUB_ENABLE_WS',
    defaultValue: false,
  );

  static String get baseUrl => 'http://$apiHost:$apiPort$apiPath';
  static String get wsUrl => 'ws://$apiHost:$apiPort$wsPath';
}
