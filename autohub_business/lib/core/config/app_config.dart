import 'package:flutter/foundation.dart';

/// Конфигурация приложения. URL бэкенда: `--dart-define=MP_SERVIS_API_HOST=...` / `MP_SERVIS_API_BASE_URL=...`.
///
/// **Desktop (Windows / macOS / Linux)** без dart-define ходит на прод `https://api.mp-servis.ru/api/v1`
/// — как клиентское приложение и release-сборки на телефонах. Локальный Nest на этом ПК:
/// `--dart-define=MP_SERVIS_API_BASE_URL=http://127.0.0.1:3001/api/v1` или `MP_SERVIS_API_HOST=127.0.0.1`
/// (порт по умолчанию **3001**; свой: `--dart-define=MP_SERVIS_API_PORT=3000`).
///
/// **Почему на телефоне «нет сети», а на ПК всё ок**
/// - **Android 9+** и cleartext: в манифесте `android:usesCleartextTraffic="true"` (в проекте включено).
/// - **`127.0.0.1` на физическом телефоне** — это сам телефон, не ПК с Nest; для Android без
///   `dart-define` используется LAN-хост ниже; иначе задайте IP ПК вручную.
/// - **Эмулятор Android** к хосту часто удобнее `10.0.2.2`:  
///   `flutter run --dart-define=MP_SERVIS_API_HOST=10.0.2.2`
/// - **USB + adb reverse**: `adb reverse tcp:3001 tcp:3001` и тогда можно  
///   `--dart-define=MP_SERVIS_API_HOST=127.0.0.1`
/// - **Брандмауэр Windows**: входящий TCP на порт API (часто **3001**, см. `PORT` в `backend/.env`).
///
/// Пример LAN (офисный ПК с API): `flutter run --dart-define=MP_SERVIS_API_HOST=192.168.1.145`
///
/// **Релиз Android/iOS** без `MP_SERVIS_API_BASE_URL` и без `MP_SERVIS_API_HOST` → прод (см. ниже).
/// Для LAN-сборки на телефоне задайте хост явно.
class AppConfig {
  AppConfig._();

  /// Прод-API по умолчанию для **release** мобильных сборок (см. [_releaseMobileUsesProdDefault]).
  static const String _kDefaultProdApiBase = 'https://api.mp-servis.ru/api/v1';

  /// Явно заданный хост (пусто = взять платформенное умолчание).
  static const String _apiHostFromEnv = String.fromEnvironment(
    'MP_SERVIS_API_HOST',
    defaultValue: '',
  );

  /// LAN IP машины с Nest для **мобильных** сборок без `MP_SERVIS_API_HOST` (Android / iOS).
  /// Переопределение: `--dart-define=MP_SERVIS_DEFAULT_LAN_HOST=…` или полный хост через `MP_SERVIS_API_HOST`.
  static const String _defaultMobileLanHost = String.fromEnvironment(
    'MP_SERVIS_DEFAULT_LAN_HOST',
    defaultValue: '10.0.2.2',
  );

  /// Полный базовый URL API (прод). Если задан — LAN-хост и порт не используются.
  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'MP_SERVIS_API_BASE_URL',
    defaultValue: '',
  );

  /// Release APK/AAB с телефона без dart-define → прод, а не LAN.
  static bool get _releaseMobileUsesProdDefault {
    if (!kReleaseMode) return false;
    if (kIsWeb) return false;
    if (_apiBaseUrlFromEnv.trim().isNotEmpty) return false;
    if (_apiHostFromEnv.isNotEmpty) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  /// Desktop без dart-define → прод (удалённый VPS / домен), как у клиента MP-Servis.
  static bool get _desktopUsesProdDefault {
    if (kIsWeb) return false;
    if (_apiBaseUrlFromEnv.trim().isNotEmpty) return false;
    if (_apiHostFromEnv.isNotEmpty) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  static String _normalizeApiBaseUrl(String raw) {
    var u = raw.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/api/v1')) {
      u = '$u/api/v1';
    }
    return u;
  }

  static bool get apiHostFromDartDefine =>
      _apiHostFromEnv.isNotEmpty || _apiBaseUrlFromEnv.trim().isNotEmpty;

  /// Хост API (без схемы).
  static String get apiHost {
    if (_apiHostFromEnv.isNotEmpty) return _apiHostFromEnv;
    if (kIsWeb) return _defaultMobileLanHost;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        // Используется только если задан dart-define или при отключённом [_desktopUsesProdDefault].
        return '127.0.0.1';
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _defaultMobileLanHost;
      default:
        return _defaultMobileLanHost;
    }
  }

  static const int apiPort = int.fromEnvironment('MP_SERVIS_API_PORT', defaultValue: 3001);
  static const String apiPath = '/api/v1';
  static const String wsPath = '/ws';

  /// WebSocket опционален: при false чаты работают через REST refetch. Для dev: --dart-define=MP_SERVIS_ENABLE_WS=false
  static const bool enableWs = bool.fromEnvironment(
    'MP_SERVIS_ENABLE_WS',
    defaultValue: false,
  );

  static String get baseUrl {
    final raw = _apiBaseUrlFromEnv.trim();
    if (raw.isNotEmpty) {
      return _normalizeApiBaseUrl(raw);
    }
    if (_releaseMobileUsesProdDefault) {
      return _kDefaultProdApiBase;
    }
    if (_desktopUsesProdDefault) {
      return _kDefaultProdApiBase;
    }
    return 'http://$apiHost:$apiPort$apiPath';
  }

  /// Всегда согласован с [baseUrl] (https → wss, LAN http → ws).
  static String get wsUrl {
    final b = Uri.parse(baseUrl);
    final wsScheme = b.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: b.host,
      port: b.hasPort ? b.port : null,
      path: wsPath,
    ).toString();
  }

  /// Схема + хост + порт без суффикса `/api/v1` (для сборки URL медиа).
  static String get apiOrigin {
    final b = baseUrl;
    const marker = '/api/v1';
    final i = b.indexOf(marker);
    if (i < 0) {
      return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    }
    return b.substring(0, i);
  }

  /// URL картинок из ответа API часто собран с `localhost` или другим хостом сервера.
  /// Для загрузки с телефона/другого ПК подставляем хост и порт из [baseUrl].
  static String? resolveApiMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    final app = Uri.parse(baseUrl);

    // Только путь: `/api/v1/...` или `/uploads/...` — собираем с origin текущего приложения.
    if (trimmed.startsWith('/') && !trimmed.startsWith('//')) {
      return Uri.parse(apiOrigin).resolve(trimmed).toString();
    }

    final u = Uri.tryParse(trimmed);
    if (u == null) return trimmed;

    if (!u.hasScheme || (u.scheme != 'http' && u.scheme != 'https')) {
      return app.resolve(trimmed).toString();
    }

    final host = u.host.toLowerCase();
    final loopback = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '::1' ||
        host == '10.0.2.2';

    // Ссылка с ПК разработчика / эмулятора — подменяем на хост API из настроек приложения.
    if (loopback) {
      return Uri(
        scheme: app.scheme,
        host: app.host,
        port: app.hasPort ? app.port : null,
        path: u.path,
        query: u.hasQuery ? u.query : null,
      ).toString();
    }

    return trimmed;
  }

  /// Фото точки (как у клиента): путь без `/api/v1` в БД.
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

  /// Фото авто клиента: `/profile/cars/.../photo-file/...` в `car_photo_url` заказа.
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

  /// Нормализация `car_photo_url` и аналогичных ссылок перед [resolveApiMediaUrl].
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
