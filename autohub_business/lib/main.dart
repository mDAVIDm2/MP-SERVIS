import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'core/config/app_config.dart';
import 'core/config/platform_utils.dart';
import 'core/push/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/auth/auth_provider.dart';
import 'core/repositories/organization_repository.dart';
import 'core/push/push_registration.dart';
import 'core/router/app_router.dart';

bool _isWsError(Object e) =>
    e is WebSocketChannelException || (e is Exception && e.toString().contains('WebSocket'));

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final rootOnError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_isWsError(error)) return true;
      return rootOnError?.call(error, stack) ?? false;
    };
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isWsError(details.exception)) return;
      FlutterError.presentError(details);
    };
    await _runApp();
  }, (Object error, StackTrace stack) {
    if (_isWsError(error)) return;
    FlutterError.presentError(FlutterErrorDetails(exception: error, stack: stack));
  });
}

Future<void> _runApp() async {
  if (kDebugMode) {
    debugPrint('[AutoHub Business] API baseUrl=${AppConfig.baseUrl}');
    if (!AppConfig.apiHostFromDartDefine) {
      debugPrint(
        '[AutoHub Business] Хост из умолчания платформы. Свой IP/эмулятор: '
        '--dart-define=AUTOHUB_API_HOST=<IP> (Android эмулятор: часто 10.0.2.2; iOS Simulator на Mac: 127.0.0.1). '
        'LAN по умолчанию для телефонов: --dart-define=AUTOHUB_DEFAULT_LAN_HOST=<IP>.',
      );
    }
  }
  await initializeDateFormatting('ru_RU', null);
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    final firebaseOk = await ensureFirebaseAppInitialized();
    if (firebaseOk) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } else if (kDebugMode) {
      debugPrint('[Business] Firebase не инициализирован — нужен android/app/google-services.json');
    }
  }
  final prefs = await SharedPreferences.getInstance();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDesktopPlatform ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: isDesktopPlatform ? const Color(0xFFF5F6F8) : AppColors.navBg,
    systemNavigationBarIconBrightness: isDesktopPlatform ? Brightness.dark : Brightness.light,
  ));

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        sharedPreferencesOrgProvider.overrideWith((ref) => Future.value(prefs)),
      ],
      child: const AutoHubBusinessApp(),
    ),
  );
}

class AutoHubBusinessApp extends ConsumerStatefulWidget {
  const AutoHubBusinessApp({super.key});

  @override
  ConsumerState<AutoHubBusinessApp> createState() => _AutoHubBusinessAppState();
}

class _AutoHubBusinessAppState extends ConsumerState<AutoHubBusinessApp> {
  @override
  void initState() {
    super.initState();
    // Инициализация авторизации (проверка токена в prefs) — без этого статус остаётся initial и крутится сплэш
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final useDesktopTheme = isDesktopPlatform;

    return MaterialApp.router(
      title: 'AutoHub Business',
      debugShowCheckedModeBanner: false,
      theme: useDesktopTheme ? AppTheme.desktop : AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => PushRegistrationListener(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
