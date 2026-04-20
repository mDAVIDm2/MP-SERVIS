import 'dart:convert';

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
import '../router/root_navigator_key.dart';
import '../../features/chats/presentation/screens/chat_detail_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';

const _androidChannelId = 'mp_servis_business';

/// Ref из [PushRegistrationListener] — для колбэков FCM / локальных уведомлений вне виджета.
WidgetRef? _businessPushRef;

FlutterLocalNotificationsPlugin? _businessLocalNotifications;
bool _businessLocalNotificationsInitialized = false;

bool _businessPushDeepLinksAttached = false;

/// Тап по push: приглашение в организацию, заказ (клиент подтвердил/перенёс время и т.п.).
void attachOrganizationInviteDeepLinks(WidgetRef ref) {
  attachBusinessPushDeepLinks(ref);
}

void attachBusinessPushDeepLinks(WidgetRef ref) {
  if (!_isMobileNative) return;
  _businessPushRef = ref;
  if (_businessPushDeepLinksAttached) return;
  _businessPushDeepLinksAttached = true;

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationTap(ref, message.data);
  });
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationTap(ref, message.data);
    });
  });

  // Android: в foreground системная шторка часто не показывается — дублируем заказным пушем локальным уведомлением.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (message.data['type']?.toString() != 'order') return;
    _showAndroidForegroundOrderNotification(message);
  });
}

/// Открытие экрана после тапа (FCM, локальное уведомление). [ref] должен быть актуальным [WidgetRef].
void _handleNotificationTap(WidgetRef ref, Map<String, dynamic> data) {
  final t = data['type']?.toString() ?? '';
  if (t == 'organization_invite') {
    final router = ref.read(appRouterProvider);
    router.go('/invitations');
    return;
  }
  if (t == 'order') {
    final cid = data['chat_id']?.toString().trim() ?? '';
    final oid = data['order_id']?.toString().trim() ?? '';
    if (cid.isEmpty && oid.isEmpty) return;
    final router = ref.read(appRouterProvider);
    router.go('/app');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pushOrderOrChatFromNotification(ref, chatId: cid, orderId: oid);
      });
    });
    return;
  }
}

Future<void> _pushOrderOrChatFromNotification(
  WidgetRef ref, {
  required String chatId,
  required String orderId,
}) async {
  final nav = appRootNavigatorKey.currentState;
  if (nav == null) return;

  if (chatId.isNotEmpty) {
    await ensureChatDataLoaded(ref, chatId);
    if (!nav.mounted) return;
    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          currentOrderId: orderId.isNotEmpty ? orderId : null,
        ),
      ),
    );
    return;
  }

  if (orderId.isNotEmpty) {
    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(orderId: orderId),
      ),
    );
  }
}

Future<void> _showAndroidForegroundOrderNotification(RemoteMessage message) async {
  final ref = _businessPushRef;
  if (ref == null) return;
  await _ensureBusinessLocalNotifications(ref);
  final plugin = _businessLocalNotifications;
  if (plugin == null) return;

  final n = message.notification;
  var title = (n?.title ?? message.data['title']?.toString() ?? '').trim();
  if (title.isEmpty) title = 'Заказ';
  final body = (n?.body ?? message.data['body']?.toString() ?? '').trim();
  String payload;
  try {
    payload = jsonEncode(message.data);
  } catch (_) {
    payload = jsonEncode(<String, String>{
      'type': message.data['type']?.toString() ?? 'order',
      'order_id': message.data['order_id']?.toString() ?? '',
      'chat_id': message.data['chat_id']?.toString() ?? '',
    });
  }

  const androidDetails = AndroidNotificationDetails(
    _androidChannelId,
    'Бизнес: уведомления',
    channelDescription: 'Сообщения клиентов, заказы',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  final id = _foregroundNotificationId(message);
  await plugin.show(
    id: id,
    title: title,
    body: body.isNotEmpty ? body : 'Обновление по записи',
    notificationDetails: const NotificationDetails(android: androidDetails),
    payload: payload,
  );
}

int _foregroundNotificationId(RemoteMessage message) {
  final mid = message.messageId;
  if (mid != null && mid.isNotEmpty) {
    return mid.hashCode.abs() % 0x7fffffff;
  }
  final oid = message.data['order_id']?.toString() ?? '';
  if (oid.isNotEmpty) return oid.hashCode.abs() % 0x7fffffff;
  return DateTime.now().millisecondsSinceEpoch % 0x7fffffff;
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

Future<void> _ensureBusinessLocalNotifications(WidgetRef ref) async {
  _businessPushRef = ref;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  if (_businessLocalNotificationsInitialized && _businessLocalNotifications != null) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await plugin.initialize(
    settings: const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final r = _businessPushRef;
      if (r == null) return;
      final p = response.payload;
      if (p == null || p.isEmpty) return;
      try {
        final decoded = jsonDecode(p);
        if (decoded is Map<String, dynamic>) {
          _handleNotificationTap(r, decoded);
        }
      } catch (_) {}
    },
  );
  _businessLocalNotifications = plugin;
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
  _businessLocalNotificationsInitialized = true;
}

bool _refStillValid(bool Function()? refValid) => refValid == null || refValid();

/// Регистрация FCM после входа (только телефон). На десктопе/web — пропуск.
Future<void> registerBusinessFcmIfNeeded(
  WidgetRef ref, {
  bool Function()? refValid,
}) async {
  if (!_isMobileNative) return;

  await _ensureBusinessLocalNotifications(ref);
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
