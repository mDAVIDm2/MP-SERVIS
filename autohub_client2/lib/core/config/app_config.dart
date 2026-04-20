/// Конфигурация приложения. URL бэкенда:
/// - прод: `--dart-define=MP_SERVIS_API_BASE_URL=https://api.example.ru/api/v1` (HTTPS, без :3000);
/// - LAN/dev: `--dart-define=MP_SERVIS_API_HOST=...` (порт 3000 по умолчанию).
///
/// **Android 9+** блокирует HTTP без HTTPS, если не включён cleartext в манифесте (`usesCleartextTraffic`).
/// На **реальном телефоне** `localhost` — не ваш ПК; нужен **LAN IP**. Эмулятор Android: часто `10.0.2.2`.
///
/// Пример: `flutter run --dart-define=MP_SERVIS_API_HOST=192.168.1.187`
class AppConfig {
  AppConfig._();

  static const String apiHost = String.fromEnvironment(
    'MP_SERVIS_API_HOST',
    defaultValue: '192.168.1.187',
  );
  static const int apiPort = 3000;
  static const String apiPath = '/api/v1';
  static const String wsPath = '/ws';

  /// Полный базовый URL API (прод). Если задан — [apiHost]/[apiPort] не используются.
  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'MP_SERVIS_API_BASE_URL',
    defaultValue: '',
  );

  /// WebSocket опционален: при false обновления заказов только через REST. Для dev: --dart-define=MP_SERVIS_ENABLE_WS=false
  static const bool enableWs = bool.fromEnvironment(
    'MP_SERVIS_ENABLE_WS',
    defaultValue: false,
  );

  static String get baseUrl {
    final raw = _apiBaseUrlFromEnv.trim();
    if (raw.isEmpty) {
      return 'http://$apiHost:$apiPort$apiPath';
    }
    var u = raw;
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/api/v1')) {
      u = '$u/api/v1';
    }
    return u;
  }

  static String get wsUrl {
    if (_apiBaseUrlFromEnv.trim().isEmpty) {
      return 'ws://$apiHost:$apiPort$wsPath';
    }
    final b = Uri.parse(baseUrl);
    final wsScheme = b.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: b.host,
      port: b.hasPort ? b.port : null,
      path: wsPath,
    ).toString();
  }

  /// Схема + хост + порт без суффикса `/api/v1` (для сборки URL публичных файлов).
  static String get apiOrigin {
    final b = baseUrl;
    const marker = '/api/v1';
    final i = b.indexOf(marker);
    if (i < 0) {
      return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    }
    return b.substring(0, i);
  }

  /// Фото точки в каталоге: на сервере в БД часто лежит `http://localhost:.../api/v1/organizations/.../photos/...`.
  /// Клиент должен запрашивать свой [baseUrl], иначе картинки не грузятся.
  static String resolveOrganizationPhotoUrl(String raw) {
    if (raw.isEmpty) return raw;
    final trimmed = raw.trim();
    if (trimmed.startsWith('/')) {
      var p = trimmed;
      if (p.contains('/organizations/') && p.contains('/photos/')) {
        if (!p.startsWith('/api/v1')) {
          p = p.startsWith('/organizations/') ? '/api/v1$p' : p;
        }
        return '$apiOrigin$p';
      }
      return raw;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return raw;
    final path = uri.path;
    if (!path.contains('/organizations/') || !path.contains('/photos/')) return raw;
    var p = path;
    if (!p.startsWith('/api/v1') && p.startsWith('/organizations/')) {
      p = '/api/v1$p';
    }
    return '$apiOrigin$p';
  }

  /// URL аватара из профиля: в БД может быть `http://localhost:.../api/v1/profile/avatar/...`.
  static String resolveProfileAvatarUrl(String raw) {
    if (raw.isEmpty) return raw;
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return raw;
    final path = uri.path;
    if (!path.contains('/profile/avatar/')) return raw;
    var p = path;
    if (!p.startsWith('/api/v1') && p.startsWith('/profile/')) {
      p = '/api/v1$p';
    }
    return '$apiOrigin$p';
  }

  /// Фото авто из гаража: `.../api/v1/profile/cars/:id/photo-file/...`.
  static String resolveProfileCarPhotoUrl(String raw) {
    if (raw.isEmpty) return raw;
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return raw;
    final path = uri.path;
    if (!path.contains('/profile/cars/') || !path.contains('/photo-file/')) return raw;
    var p = path;
    if (!p.startsWith('/api/v1') && p.startsWith('/profile/')) {
      p = '/api/v1$p';
    }
    return '$apiOrigin$p${uri.hasQuery ? '?${uri.query}' : ''}';
  }

  /// Фото авто в заказе (`car_photo_url`) и в гараже: переписывает `localhost` и относительные `/api/v1/...` на текущий [apiOrigin].
  static String resolveCarOrOrderPhotoUrl(String raw) {
    if (raw.isEmpty) return raw;
    final trimmed = raw.trim();
    final o = resolveOrganizationPhotoUrl(trimmed);
    if (o != trimmed) return o;
    final garage = resolveProfileCarPhotoUrl(trimmed);
    if (garage != trimmed) return garage;
    final p = resolveProfileAvatarUrl(trimmed);
    if (p != trimmed) return p;
    if (trimmed.startsWith('/api/v1')) return '$apiOrigin$trimmed';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return trimmed;
      final path = uri.path;
      if (path.startsWith('/api/v1')) {
        return '$apiOrigin$path${uri.hasQuery ? '?${uri.query}' : ''}';
      }
      return trimmed;
    }
    return trimmed;
  }
}
