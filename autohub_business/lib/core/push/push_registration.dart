import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/services/api_services_providers.dart';
import '../auth/auth_provider.dart';
import '../config/platform_utils.dart';
import '../repositories/organization_repository.dart';
import '../router/app_router_provider.dart';

const _androidChannelId = 'autohub_business';

bool _organizationInviteDeepLinksAttached = false;

/// Открытие экрана приглашений по тапу на push (data.type = organization_invite).
void attachOrganizationInviteDeepLinks(WidgetRef ref) {
  if (!_isMobileNative) return;
  if (_organizationInviteDeepLinksAttached) return;
  _organizationInviteDeepLinksAttached = true;

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _navigateToInvitesIfNeeded(ref, message.data);
  });
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToInvitesIfNeeded(ref, message.data);
    });
  });
}

void _navigateToInvitesIfNeeded(WidgetRef ref, Map<String, dynamic> data) {
  final t = data['type']?.toString() ?? '';
  if (t != 'organization_invite') return;
  final router = ref.read(appRouterProvider);
  router.go('/invitations');
}

bool get _isMobileNative =>
    !kIsWeb &&
    !isDesktopPlatform &&
    (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

String _platform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return 'unknown';
  }
}

Future<void> _ensureAndroidNotificationChannel() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await plugin.initialize(
    settings: const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (_) {},
  );
  final androidImpl = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(
    const AndroidNotificationChannel(
      _androidChannelId,
      'Бизнес: уведомления',
      description: 'Сообщения клиентов, заказы',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ),
  );
  await androidImpl?.requestNotificationsPermission();
}

bool _refStillValid(bool Function()? refValid) => refValid == null || refValid();

/// Регистрация FCM после входа (только телефон). На десктопе/web — пропуск.
Future<void> registerBusinessFcmIfNeeded(
  WidgetRef ref, {
  bool Function()? refValid,
}) async {
  if (!_isMobileNative) return;

  await _ensureAndroidNotificationChannel();
  if (!_refStillValid(refValid)) return;

  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  if (!_refStillValid(refValid)) return;

  if (defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!_refStillValid(refValid)) return;
  }

  final token = await FirebaseMessaging.instance.getToken();
  if (!_refStillValid(refValid)) return;
  if (token == null || token.length < 8) {
    if (kDebugMode) debugPrint('[Business Push] FCM token недоступен');
    return;
  }

  final api = ref.read(notificationsApiServiceProvider);
  final r = await api.registerDevice(token, _platform(), fcmApp: 'business');
  if (!_refStillValid(refValid)) return;
  if (r.errorOrNull != null && kDebugMode) {
    debugPrint('[Business Push] register-device: ${r.errorOrNull}');
    return;
  }
  if (kDebugMode) debugPrint('[Business Push] FCM зарегистрирован на сервере');
}

/// @deprecated Используйте [registerBusinessFcmIfNeeded]. Оставлено для совместимости вызовов.
Future<String> getOrCreateDeviceId(SharedPreferences prefs) async {
  return '${DateTime.now().millisecondsSinceEpoch}_legacy';
}

/// Регистрирует push после входа (FCM на мобильных).
void registerPushTokenIfNeeded(
  WidgetRef ref, {
  required bool isAuthenticated,
  required SharedPreferences? prefs,
}) {
  if (!isAuthenticated || prefs == null) return;
  if (!_isMobileNative) return;
  registerBusinessFcmIfNeeded(ref);
}

class PushRegistrationListener extends ConsumerStatefulWidget {
  final Widget child;

  const PushRegistrationListener({super.key, required this.child});

  @override
  ConsumerState<PushRegistrationListener> createState() => _PushRegistrationListenerState();
}

class _PushRegistrationListenerState extends ConsumerState<PushRegistrationListener> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final prefs = ref.watch(sharedPreferencesOrgProvider).valueOrNull;
    if (!auth.isAuthenticated) {
      _started = false;
    } else if (!_started && prefs != null && _isMobileNative) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        attachOrganizationInviteDeepLinks(ref);
        registerBusinessFcmIfNeeded(ref, refValid: () => mounted);
      });
    }
    return widget.child;
  }
}
