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
import 'core/navigation/subscription_tariff_route.dart';
import 'features/profile/presentation/screens/subscription_tariff_screen.dart';

bool _isWsError(Object e) =>
    e is WebSocketChannelException || (e is Exception && e.toString().contains('WebSocket'));

void main() {
  registerSubscriptionTariffFactory(() => const SubscriptionTariffScreen());
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
    debugPrint('[MP-Servis Business] API baseUrl=${AppConfig.baseUrl}');
    if (!AppConfig.apiHostFromDartDefine) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          debugPrint(
            '[MP-Servis Business] Локальный Nest на телефоне/эмуляторе: '
            '--dart-define=MP_SERVIS_API_HOST=<IP> (эмулятор Android: часто 10.0.2.2). '
            'LAN по умолчанию: --dart-define=MP_SERVIS_DEFAULT_LAN_HOST=<IP>.',
          );
          break;
        default:
          debugPrint(
            '[MP-Servis Business] Локальный Nest на этом ПК: '
            '--dart-define=MP_SERVIS_API_BASE_URL=http://127.0.0.1:3001/api/v1 '
            'или MP_SERVIS_API_HOST=127.0.0.1 (порт: MP_SERVIS_API_PORT, по умолчанию 3001)',
          );
          break;
      }
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
      child: const MpServisBusinessApp(),
    ),
  );
}

class MpServisBusinessApp extends ConsumerStatefulWidget {
  const MpServisBusinessApp({super.key});

  @override
  ConsumerState<MpServisBusinessApp> createState() => _MpServisBusinessAppState();
}

class _MpServisBusinessAppState extends ConsumerState<MpServisBusinessApp> {
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
      title: 'MP-Servis Business',
      debugShowCheckedModeBanner: false,
      theme: useDesktopTheme ? AppTheme.desktop : AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => PushRegistrationListener(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
