import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/order_model.dart';

bool _refOk(bool Function()? refValid) => refValid == null || refValid();

/// Извлекает список позиций из сообщения согласования.
List<ApprovalItem> _itemsFromApprovalMessage(ChatMessage m) {
  final list = <ApprovalItem>[];
  if (m.originalApprovalItems != null) list.addAll(m.originalApprovalItems!);
  if (m.editedApprovalItems != null) {
    for (final e in m.editedApprovalItems!) {
      list.add(ApprovalItem(name: e.name, priceKopecks: e.priceKopecks, estimatedMinutes: e.estimatedMinutes));
    }
  }
  if (m.newApprovalItems != null) list.addAll(m.newApprovalItems!);
  if (m.approvalItems != null && list.isEmpty) list.addAll(m.approvalItems!);
  return list;
}

/// Подставляет состав заказа из чата в state, если у заказа пустой items. Возвращает true, если состав был подставлен.
Future<bool> ensureOrderItemsFromChat(
  WidgetRef ref,
  String orderId, {
  bool Function()? refValid,
}) async {
  if (!_refOk(refValid)) return false;
  final order = ref.read(orderByIdProvider(orderId));
  if (order == null || order.items.isNotEmpty) return false;
  final orderApi = ref.read(orderApiServiceProvider);
  final chatRes = await orderApi.getChatForOrder(orderId);
  if (!_refOk(refValid)) return false;
  final chatId = chatRes.dataOrNull;
  if (chatId == null || chatId.isEmpty) return false;
  await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(chatId);
  if (!_refOk(refValid)) return false;
  final chatState = ref.read(chatRepositoryProvider);
  final messages = (chatState.messages[chatId] ?? [])..sort((a, b) => a.at.compareTo(b.at));
  ChatMessage? latest;
  for (final m in messages) {
    if (!m.isApprovalCard || m.orderId != orderId) continue;
    if (latest == null || m.at.isAfter(latest.at)) latest = m;
  }
  if (latest == null) return false;
  final approvalItems = _itemsFromApprovalMessage(latest);
  if (approvalItems.isEmpty) return false;
  final orderItems = approvalItems.asMap().entries.map((e) {
    final a = e.value;
    return OrderItem(
      id: a.id ?? 'fb_${e.key}_${a.name.hashCode.abs()}',
      name: a.name,
      priceKopecks: a.priceKopecks,
      estimatedMinutes: a.estimatedMinutes,
      isCompleted: false,
      isAdditional: false,
    );
  }).toList();
  ref.read(orderRepositoryProvider.notifier).setOrderItemsIfEmpty(orderId, orderItems);
  return true;
}

/// Для всех заказов с пустым составом (лимит 25) подставляет состав из чата. Вызывать после loadFromApi.
Future<void> ensureAllEmptyOrdersLoaded(
  WidgetRef ref, {
  bool Function()? refValid,
}) async {
  if (!_refOk(refValid)) return;
  final orders = ref.read(orderRepositoryProvider);
  final empty = orders.where((o) => o.items.isEmpty).toList();
  const limit = 25;
  for (var i = 0; i < empty.length && i < limit; i++) {
    if (!_refOk(refValid)) return;
    await ensureOrderItemsFromChat(ref, empty[i].id, refValid: refValid);
  }
}
