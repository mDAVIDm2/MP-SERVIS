import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'core/navigation/app_navigator_key.dart';
import 'core/push/client_push_service.dart';
import 'core/push/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/app_lock_provider.dart';
import 'core/auth/post_auth_shell.dart';
import 'core/settings/locale_provider.dart';
import 'core/l10n/app_l10n.dart';
import 'core/l10n/l10n_scope.dart';
import 'features/auth/presentation/screens/auth_screens.dart';

bool _isWsError(Object e) =>
    e is WebSocketChannelException || (e is Exception && e.toString().contains('WebSocket'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final rootOnError = ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (_isWsError(error)) {
      if (kDebugMode) debugPrint('[Client] WS error (ignored): $error');
      return true;
    }
    return rootOnError?.call(error, stack) ?? false;
  };
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isWsError(details.exception)) {
      if (kDebugMode) debugPrint('[Client] WS FlutterError (ignored): ${details.exception}');
      return;
    }
    FlutterError.presentError(details);
  };
  runZonedGuarded(() async {
    await _runApp();
  }, (Object error, StackTrace stack) {
    if (_isWsError(error)) {
      if (kDebugMode) debugPrint('[Client] WS zone error (ignored): $error');
      return;
    }
    FlutterError.presentError(FlutterErrorDetails(exception: error, stack: stack));
  });
}

Future<void> _runApp() async {
  await initializeDateFormatting('ru_RU', null);
  if (!kIsWeb) {
    final firebaseOk = await ensureFirebaseAppInitialized();
    if (firebaseOk) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      ClientPushService.storeInitialMessage(await FirebaseMessaging.instance.getInitialMessage());
    } else if (kDebugMode) {
      debugPrint(
        '[Firebase] Push недоступен: задайте FIREBASE_* (--dart-define) или положите '
        'android/app/google-services.json из консоли Firebase. См. autohub_firebase_options.dart',
      );
    }
  }
  final prefs = await SharedPreferences.getInstance();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.navBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
      ],
      child: const AutoHubApp(),
    ),
  );
}

class AutoHubApp extends ConsumerStatefulWidget {
  const AutoHubApp({super.key});

  @override
  ConsumerState<AutoHubApp> createState() => _AutoHubAppState();
}

class _AutoHubAppState extends ConsumerState<AutoHubApp> with WidgetsBindingObserver {
  bool _splashTimeout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Инициализация с реальными prefs (уже загружены в main), чтобы токен восстановился
    Future.microtask(() async {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      if (mounted) ref.read(authProvider.notifier).initialize(prefs);
    });
    // Страховка: если авторизация не переключилась — через 1.5 с показываем главный экран
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !_splashTimeout) {
        setState(() => _splashTimeout = true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLockProvider.notifier).onLifecycleChange(state);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final showMain = authState.status != AuthStatus.initial || _splashTimeout;
    final locale = ref.watch(localeProvider) ?? const Locale('ru');
    final l10n = AppL10n(locale);
    if (!showMain) return MaterialApp(theme: AppTheme.dark, locale: locale, home: _buildSplash());
    // Пока вход не завершён, держим один MaterialApp с WelcomeScreen. Иначе при
    // AuthStatus.authenticating (send-code / verify-code) корень менялся на PostAuthShell,
    // Navigator с EmailInput / SmsCode сбрасывался — снова «Начать / Пропустить».
    final showWelcomeFlow = authState.status == AuthStatus.unauthenticated ||
        (authState.status == AuthStatus.authenticating && !authState.isAuthenticated);
    if (showWelcomeFlow) {
      return MaterialApp(
        title: 'AutoHub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: locale,
        home: L10nScope(l10n: l10n, child: const WelcomeScreen()),
      );
    }
    return MaterialApp(
      title: 'AutoHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: locale,
      navigatorKey: appRootNavigatorKey,
      home: L10nScope(
        l10n: l10n,
        child: const PostAuthShell(),
      ),
    );
  }

  Widget _buildSplash() {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AutoHub', style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1,
            )),
            SizedBox(height: 24),
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
