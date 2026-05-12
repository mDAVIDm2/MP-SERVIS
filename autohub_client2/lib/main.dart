import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/onboarding/garage_first_car_tutorial_layer.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'core/navigation/app_navigator_key.dart';
import 'core/push/client_push_service.dart';
import 'core/push/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/client_palette.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/app_lock_provider.dart';
import 'core/auth/post_auth_shell.dart';
import 'core/sync/client_app_state_push_bridge.dart';
import 'core/sync/client_app_state_sync.dart';
import 'core/settings/locale_provider.dart';
import 'core/settings/theme_mode_provider.dart';
import 'core/l10n/app_l10n.dart';
import 'core/l10n/l10n_scope.dart';
import 'features/auth/presentation/screens/auth_screens.dart';

bool _isWsError(Object e) =>
    e is WebSocketChannelException || (e is Exception && e.toString().contains('WebSocket'));

Brightness _effectiveBrightness(ThemeMode mode) {
  final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  return switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platform,
  };
}

void _applySystemUiForTheme(ThemeMode mode) {
  final isDark = _effectiveBrightness(mode) == Brightness.dark;
  final p = isDark ? ClientPalette.dark : ClientPalette.light;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: p.navBg,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  ));
}

void main() {
  runZonedGuarded(() async {
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
  await initializeDateFormatting('en_US', null);
  if (!kIsWeb) {
    final firebaseOk = await ensureFirebaseAppInitialized();
    if (firebaseOk) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      ClientPushService.storeInitialMessage(await FirebaseMessaging.instance.getInitialMessage());
    } else if (kDebugMode) {
      debugPrint(
        '[Firebase] Push недоступен: задайте FIREBASE_* (--dart-define) или положите '
        'android/app/google-services.json из консоли Firebase. См. mp_servis_firebase_options.dart',
      );
    }
  }
  final prefs = await SharedPreferences.getInstance();
  _applySystemUiForTheme(ThemeMode.dark);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
      ],
      child: const _RegisterAppStatePush(child: MpServisApp()),
    ),
  );
}

/// Регистрирует отложенный push `client-app-state` (см. [scheduleClientAppStatePush]).
class _RegisterAppStatePush extends ConsumerStatefulWidget {
  const _RegisterAppStatePush({required this.child});
  final Widget child;

  @override
  ConsumerState<_RegisterAppStatePush> createState() => _RegisterAppStatePushState();
}

class _RegisterAppStatePushState extends ConsumerState<_RegisterAppStatePush> {
  @override
  void initState() {
    super.initState();
    registerClientAppStatePush(() => ref.read(clientAppStateSyncServiceProvider).pushLocalToServer());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MpServisApp extends ConsumerStatefulWidget {
  const MpServisApp({super.key});

  @override
  ConsumerState<MpServisApp> createState() => _MpServisAppState();
}

class _MpServisAppState extends ConsumerState<MpServisApp> with WidgetsBindingObserver {
  bool _splashTimeout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      if (mounted) ref.read(authProvider.notifier).initialize(prefs);
    });
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
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (ref.read(themeModeProvider) == ThemeMode.system) {
      _applySystemUiForTheme(ThemeMode.system);
    }
  }

  MaterialApp _app({
    required Locale locale,
    required AppL10n l10n,
    required Widget home,
    bool showKey = false,
  }) {
    final themeMode = ref.watch(themeModeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySystemUiForTheme(themeMode);
    });
    return MaterialApp(
      title: 'MP-Servis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      navigatorKey: showKey ? appRootNavigatorKey : null,
      builder: (context, child) => L10nScope(
        l10n: l10n,
        child: Consumer(
          builder: (context, ref, _) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                child ?? const SizedBox.shrink(),
                const GarageFirstCarTutorialLayer(),
              ],
            );
          },
        ),
      ),
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final showMain = authState.status != AuthStatus.initial || _splashTimeout;
    final locale = ref.watch(localeProvider) ?? const Locale('ru');
    final l10n = AppL10n(locale);

    if (!showMain) {
      return _app(
        locale: locale,
        l10n: l10n,
        home: Builder(
          builder: (ctx) {
            final p = ctx.palette;
            return Scaffold(
              backgroundColor: p.background,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MP-Servis',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final showWelcomeFlow = authState.status == AuthStatus.unauthenticated ||
        (authState.status == AuthStatus.authenticating && !authState.isAuthenticated);
    if (showWelcomeFlow) {
      return _app(
        locale: locale,
        l10n: l10n,
        home: const WelcomeScreen(),
      );
    }
    return _app(
      locale: locale,
      l10n: l10n,
      showKey: true,
      home: const PostAuthShell(),
    );
  }
}
