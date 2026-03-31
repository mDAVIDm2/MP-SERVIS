import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../settings/client_notification_prefs_provider.dart';
import 'firebase_bootstrap.dart';
import 'push_navigation_handler.dart';
import 'push_payload_codec.dart';

const _androidChannelId = 'autohub_messages';
const _androidChannelName = 'Сообщения и заказы';

/// Фоновый обработчик FCM (должен быть top-level, регистрируется до runApp).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final ok = await ensureFirebaseAppInitialized();
  if (!ok) return;
  if (kDebugMode) {
    debugPrint('[Push][bg] ${message.messageId} ${message.notification?.title}');
  }
}

/// Инициализация FCM, локальных уведомлений и регистрация токена на бэкенде.
class ClientPushService {
  ClientPushService._();
  static final ClientPushService instance = ClientPushService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _started = false;
  WidgetRef? _ref;

  /// Сообщение, из-за которого приложение открылось с холодного старта (обработать после входа в shell).
  static RemoteMessage? pendingInitialMessage;

  static void storeInitialMessage(RemoteMessage? message) {
    pendingInitialMessage = message;
  }

  Future<void> ensureStarted(WidgetRef ref) async {
    if (_started) return;
    _ref = ref;
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (Firebase.apps.isEmpty) {
      final ok = await ensureFirebaseAppInitialized();
      if (!ok) {
        if (kDebugMode) {
          debugPrint(
            '[Push] Firebase не инициализирован — FCM-токен не регистрируется '
            '(dart-define или android/app/google-services.json). См. autohub_firebase_options.dart',
          );
        }
        return;
      }
    }

    await _initLocalNotifications();
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      if (kDebugMode) debugPrint('[Push] Разрешение на уведомления отклонено');
    }

    if (Platform.isAndroid) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(ref, token);

    FirebaseMessaging.instance.onTokenRefresh.listen((t) => _registerToken(ref, t));

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) => _onForeground(ref, msg));

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      final wRef = _ref;
      if (wRef == null) return;
      PushNavigationHandler.openFromFcmData(wRef, msg.data);
    });

    await _flushPendingInitialMessage(ref);

    _started = true;
  }

  Future<void> _flushPendingInitialMessage(WidgetRef ref) async {
    final m = pendingInitialMessage;
    pendingInitialMessage = null;
    if (m == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await PushNavigationHandler.openFromFcmData(ref, m.data);
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      settings: InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final wRef = _ref;
        if (wRef == null) return;
        if (r.payload == null || r.payload!.isEmpty) return;
        if (kDebugMode) debugPrint('[Push] tap payload=${r.payload}');
        PushNavigationHandler.openFromPayloadString(wRef, r.payload);
      },
    );

    final androidImpl = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Новые сообщения, запись на сервис, согласования с сервисом',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        vibrationPattern: Int64List.fromList([0, 450, 200, 450]),
      ),
    );
    // Android 13+: явный запрос разрешения на уведомления (в т.ч. когда FCM приходит в фоне).
    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> _registerToken(WidgetRef ref, String token) async {
    final repo = ref.read(notificationRepositoryProvider);
    final platform = Platform.isIOS ? 'ios' : 'android';
    final r = await repo.registerPushToken(token, platform: platform);
    if (r.errorOrNull != null && kDebugMode) {
      debugPrint('[Push] register-device на сервере не удалось: ${r.errorOrNull}');
    }
  }

  Future<void> _onForeground(WidgetRef ref, RemoteMessage msg) async {
    final notifier = ref.read(clientNotificationPrefsProvider.notifier);
    final type = msg.data['type']?.toString();
    if (!notifier.allowsBackendType(type)) return;

    final prefs = ref.read(clientNotificationPrefsProvider).valueOrNull;
    final title = msg.notification?.title ?? msg.data['title']?.toString() ?? 'AutoHub';
    final body = msg.notification?.body ?? msg.data['body']?.toString() ?? '';

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: prefs?.sound ?? true,
      enableVibration: prefs?.vibration ?? true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payloadMap = <String, String>{};
    for (final e in msg.data.entries) {
      if (e.value.isEmpty) continue;
      payloadMap[e.key] = e.value;
    }

    await _local.show(
      id: msg.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payloadMap.isEmpty ? null : PushPayloadCodec.encodeFromStringMap(payloadMap),
    );
  }
}
