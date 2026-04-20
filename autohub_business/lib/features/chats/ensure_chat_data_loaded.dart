import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/chat_repository.dart';
import '../../core/repositories/order_repository.dart';

const bool _kEnsureChatDebug = kDebugMode;

void _ensureChatLog(String scene, String message, [Map<String, Object?>? data]) {
  if (!_kEnsureChatDebug) return;
  final sb = StringBuffer('[ChatOrderDebug] $scene | $message');
  if (data != null && data.isNotEmpty) {
    sb.write(' | ');
    sb.write(data.entries.map((e) => '${e.key}=${e.value}').join(', '));
  }
  debugPrint(sb.toString());
}

/// Загружает чаты, заказы и сообщения чата перед открытием экрана. Вызывать перед push/показом ChatDetailScreen,
/// чтобы лента (ссылки на заказы, карточки) строилась из актуальных данных с первого кадра.
///
/// [refValid] — после каждого await не обращаться к [ref], если виджет уже снят с дерева (иначе Riverpod бросает).
Future<void> ensureChatDataLoaded(
  WidgetRef ref,
  String chatId, {
  bool Function()? refValid,
}) async {
  bool ok() => refValid == null || refValid();
  _ensureChatLog('ensureChatDataLoaded', 'START', {'chatId': chatId});
  await ref.read(chatRepositoryProvider.notifier).loadFromApi();
  if (!ok()) return;
  final chatState = ref.read(chatRepositoryProvider);
  _ensureChatLog('ensureChatDataLoaded', 'after loadFromApi chats', {'chatsCount': chatState.chats.length});
  await ref.read(orderRepositoryProvider.notifier).loadFromApi();
  if (!ok()) return;
  final ordersCount = ref.read(orderRepositoryProvider).length;
  _ensureChatLog('ensureChatDataLoaded', 'after loadFromApi orders', {'ordersCount': ordersCount});
  await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(chatId);
  if (!ok()) return;
  final msgs = ref.read(chatRepositoryProvider).messages[chatId] ?? [];
  final orderIdsInMsgs = msgs.map((m) => m.orderId?.trim()).whereType<String>().where((s) => s.isNotEmpty).toSet();
  _ensureChatLog('ensureChatDataLoaded', 'END', {
    'chatId': chatId,
    'messagesCount': msgs.length,
    'uniqueOrderIdsInMessages': orderIdsInMsgs.length,
    'orderIds': orderIdsInMsgs.take(5).join(';'),
  });
}
