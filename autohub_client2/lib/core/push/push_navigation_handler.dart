import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_navigator_key.dart';
import '../navigation/shell_navigation_provider.dart';
import '../providers/app_providers.dart';
import '../settings/filter_by_car_setting.dart';
import '../../features/chats/presentation/screens/chat_detail_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import 'push_payload_codec.dart';

/// Открытие экрана по данным FCM / локального уведомления (корневой [Navigator]).
class PushNavigationHandler {
  PushNavigationHandler._();

  static String? _pick(Map<String, String> data, String key) {
    final v = data[key]?.trim();
    if (v != null && v.isNotEmpty) return v;
    return null;
  }

  static Future<void> openFromPayloadString(WidgetRef ref, String? payload) async {
    final map = PushPayloadCodec.decode(payload);
    if (map == null || map.isEmpty) return;
    await openFromStringMap(ref, map);
  }

  static Future<void> openFromFcmData(WidgetRef ref, Map<String, dynamic> data) async {
    final m = <String, String>{};
    for (final e in data.entries) {
      if (e.value == null) continue;
      final s = e.value.toString();
      if (s.isEmpty) continue;
      m[e.key] = s;
    }
    await openFromStringMap(ref, m);
  }

  static Future<void> openFromStringMap(WidgetRef ref, Map<String, String> data) async {
    final ctx = appRootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    void push(Widget page) {
      final c = appRootNavigatorKey.currentContext;
      if (c == null || !c.mounted) return;
      Navigator.of(c, rootNavigator: true).push(CupertinoPageRoute<void>(builder: (_) => page));
    }

    void snack(String msg) {
      final c = appRootNavigatorKey.currentContext;
      if (c == null || !c.mounted) return;
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));
    }

    final targetType = (_pick(data, 'target_type') ?? '').toLowerCase();
    final targetId = _pick(data, 'target_id');
    var chatId = _pick(data, 'chat_id');
    var orderId = _pick(data, 'order_id');
    if (chatId == null && targetType == 'chat' && targetId != null) chatId = targetId;
    if (orderId == null && targetType == 'order' && targetId != null) orderId = targetId;

    if (chatId != null) {
      ref.read(shellTargetTabProvider.notifier).state = 3;
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!ctx.mounted) return;
      final chatRes = await ref.read(chatRepositoryProvider).getChatById(chatId);
      if (!ctx.mounted) return;
      if (chatRes.dataOrNull != null) {
        push(ChatDetailScreen(chat: chatRes.dataOrNull!, currentOrderId: orderId));
        return;
      }
      snack('Не удалось открыть чат');
      return;
    }

    if (orderId != null) {
      ref.read(shellTargetTabProvider.notifier).state = 0;
      await Future<void>.delayed(const Duration(milliseconds: 320));
      if (!ctx.mounted) return;
      final orderRes = await ref.read(orderRepositoryProvider).getOrderById(orderId);
      if (!ctx.mounted) return;
      if (orderRes.dataOrNull != null) {
        push(OrderDetailScreen(order: orderRes.dataOrNull!));
        return;
      }
      snack('Не удалось открыть заказ');
      return;
    }

    if (_pick(data, 'notification_id') != null) {
      push(NotificationsScreen(initialCarId: ref.read(selectedCarIdProvider)));
    }
  }
}
