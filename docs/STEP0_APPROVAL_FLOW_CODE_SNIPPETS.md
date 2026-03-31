# ШАГ 0 — Фрагменты кода для анализа approval flow

Файл создан для анализа. Содержит выдержки из кода по пунктам 0.1–0.5.

---

## 0.1 Отправка approval request из Business

### ConfirmCorrectOrderScreen — вызов sendApprovalRequest (additionalWorksOnly и полная корректировка)

**Файл:** `autohub_business/lib/features/orders/presentation/screens/confirm_correct_order_screen.dart`

```dart
// Строки 186-232: ветка additionalWorksOnly
if (widget.additionalWorksOnly) {
  // ...
  final orderIdResult = await chatRepo.sendApprovalRequest(
    chatId,
    widget.orderId,
    editedItems: [],
    newItems: _newApprovalItems,
    proposedDateTime: _proposedDateTime,
    isInitialConfirm: false,
  );
  // ...
}

// Полная корректировка
final orderIdResult = await chatRepo.sendApprovalRequest(
  chatId,
  widget.orderId,
  editedItems: hasExisting ? _editedItems : null,
  newItems: hasNew ? _newApprovalItems : null,
  proposedDateTime: _proposedDateTime,
  isInitialConfirm: false,
);
```

### ChatApiService — тело запроса и endpoint

**Файл:** `autohub_business/lib/core/api/services/chat_api_service.dart` (строки 75-127)

```dart
Future<Result<ChatMessage>> sendApprovalRequest(
  String chatId,
  String orderId, {
  List<EditedApprovalItem>? editedItems,
  List<ApprovalItem>? newItems,
  List<ApprovalItem>? items,
  DateTime? proposedDateTime,
}) async {
  try {
    final Object approvalPayload;
    if ((editedItems != null && editedItems.isNotEmpty) || (newItems != null && newItems.isNotEmpty)) {
      approvalPayload = {
        'edited_items': (editedItems ?? []).map((i) => {
          'id': i.id,
          'name': i.name,
          'price_kopecks': i.priceKopecks,
          'estimated_minutes': i.estimatedMinutes,
        }).toList(),
        'new_items': (newItems ?? []).map((i) => {
          'name': i.name,
          'price_kopecks': i.priceKopecks,
          'estimated_minutes': i.estimatedMinutes,
        }).toList(),
      };
    } else {
      approvalPayload = (items ?? []).map((i) => { ... }).toList();
    }
    final body = {
      'order_id': orderId.isEmpty ? null : orderId,  // <-- может уйти null при пустом orderId
      'approval_items': approvalPayload,
      if (proposedDateTime != null) 'proposed_date_time': proposedDateTime.toUtc().toIso8601String(),
    };
    // ...
    final res = await _client.post(ApiEndpoints.chatMessages(chatId), data: body);
    // ...
  }
}
```

### ApiEndpoints — endpoint сообщений

**Файл:** `autohub_business/lib/core/api/api_endpoints.dart` (строки 33-36)

```dart
// Chats
static const String chats = '/chats';
static String chat(String id) => '/chats/$id';
static String chatMessages(String chatId) => '/chats/$chatId/messages';
```

**Итог:** вызывается **POST `/chats/:chatId/messages`** с полями `order_id`, `approval_items` (объект с `edited_items`/`new_items` или список).

### ChatRepository — sendApprovalRequest и подмена по ответу

**Файл:** `autohub_business/lib/core/repositories/chat_repository.dart` (строки 156-209)

```dart
Future<String?> sendApprovalRequest(
  String chatId,
  String orderId, {
  List<EditedApprovalItem>? editedItems,
  List<ApprovalItem>? newItems,
  List<ApprovalItem>? items,
  DateTime? proposedDateTime,
  bool isInitialConfirm = false,
}) async {
  // ...
  final tempMsg = ChatMessage(
    id: tempId,
    text: '',
    isFromClient: false,
    at: DateTime.now(),
    isText: false,
    approvalItems: items,
    editedApprovalItems: editedItems,
    newApprovalItems: newItems,
    approvalStatus: ApprovalStatus.pending,
    proposedDateTime: proposedDateTime,
    // orderId в tempMsg не задаётся — подставится из ответа API при _replaceMessage
  );
  _appendMessage(chatId, tempMsg, previewText: previewText);
  final result = await _api.sendApprovalRequest(chatId, orderId, ...);
  final msg = result.dataOrNull;
  if (msg != null) {
    _replaceMessage(chatId, tempId, msg);
    final effectiveOrderId = msg.orderId ?? orderId;
    return effectiveOrderId.isEmpty ? null : effectiveOrderId;
  }
  _removeMessage(chatId, tempId);
  return null;
}
```

### ApprovalRequestScreen — отправка с items (возможен пустой orderId)

**Файл:** `autohub_business/lib/features/chats/presentation/screens/approval_request_screen.dart` (строки 376-419)

```dart
Future<void> _send() async {
  // ...
  final effectiveOrderId = await chatRepo.sendApprovalRequest(
    widget.chatId,
    widget.orderId,   // может быть пустым при выборе «новый запрос»
    items: items,
    proposedDateTime: _proposedDateTime,
  );
  // ...
}
```

---

## 0.2 Парсинг ответа (Business) — ChatMessage.fromJson, order_id и approval_items

**Файл:** `autohub_business/lib/shared/models/chat_model.dart`

### isApprovalCard (строки 114-117)

```dart
bool get isApprovalCard =>
    (editedApprovalItems != null && editedApprovalItems!.isNotEmpty) ||
    (newApprovalItems != null && newApprovalItems!.isNotEmpty) ||
    (approvalItems != null && approvalItems!.isNotEmpty);
```

### fromJson (строки 171-211)

```dart
static ChatMessage fromJson(Map<String, dynamic> j) {
  final approvalItemsRaw = j['approval_items'] ?? j['approvalItems'];
  List<ApprovalItem>? approvalItemsLegacy;
  List<EditedApprovalItem>? editedApprovalItems;
  List<ApprovalItem>? newApprovalItems;

  if (approvalItemsRaw is List<dynamic>) {
    approvalItemsLegacy = _parseApprovalList(approvalItemsRaw);
  } else if (approvalItemsRaw is Map<String, dynamic>) {
    final editedRaw = approvalItemsRaw['edited_items'] ?? approvalItemsRaw['editedItems'];
    final newRaw = approvalItemsRaw['new_items'] ?? approvalItemsRaw['newItems'];
    editedApprovalItems = _parseEditedList(editedRaw as List<dynamic>?);
    newApprovalItems = _parseApprovalList(newRaw as List<dynamic>?);
  }

  final hasApproval = (approvalItemsLegacy != null && approvalItemsLegacy.isNotEmpty) ||
      (editedApprovalItems != null && editedApprovalItems.isNotEmpty) ||
      (newApprovalItems != null && newApprovalItems.isNotEmpty);
  // ...
  final orderId = j['order_id'] as String? ?? j['orderId'] as String?;
  // ...
  return ChatMessage(
    // ...
    orderId: orderId,
    isSystem: isSystem,
  );
}
```

Если бэкенд не вернёт в ответе POST (и не сохранит в БД) `order_id` и `approval_items` в нужном формате, карточка не соберётся и по GET сообщение не будет считаться approval с нужным orderId.

---

## 0.3 Условие «есть approval для orderId» и fallback

### Business — hasApprovalForOrder и fallback

**Файл:** `autohub_business/lib/features/chats/presentation/screens/chat_detail_screen.dart` (строки 283-327)

```dart
if (item.isOrder) {
  final order = item.order!;
  // ...
  final hasApprovalForOrder = messages.any((m) => m.isApprovalCard && (m.orderId ?? '') == order.id);
  if (order.status == OrderStatus.pendingApproval && !hasApprovalForOrder) {
    if (kDebugMode) {
      debugPrint('[ChatDetail] Ошибка состояния: orderId=${order.id} status=pending_approval, но в чате нет approval-сообщения по этому заказу');
    }
  }
  return Column(
    children: [
      // ...
      if (order.status == OrderStatus.pendingApproval && !hasApprovalForOrder)
        _ApprovalPendingFallbackCard(
          onRefresh: () async {
            await ref.read(chatRepositoryProvider.notifier).loadMessagesFor(widget.chatId);
            ref.read(orderRepositoryProvider.notifier).loadFromApi();
          },
        ),
    ],
  );
}
// Далее: отображение approval-сообщений (скрытие старых по orderId)
final m = item.message!;
if (m.isApprovalCard) {
  final msgOrderId = m.orderId ?? '';
  // ...
  final isPending = ...;
  final isLatest = latestApprovalIdPerOrder[msgOrderId] == m.id;
  if (!isPending || !isLatest) {
    return Column(..., children: [if (showDate) _DateSeparator(...)]);  // карточку не показываем
  }
}
return Column(
  children: [
    if (m.isSystem) _buildSystemMessageBubble(m.text)
    else if (m.isApprovalCard) _ApprovalCard(...)
    else _buildMessageBubble(context, m),
  ],
);
```

### Client — условие fallback и проверка approval по orderId

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chat_detail_screen.dart`

#### Условие показа fallback (строки 432-458)

```dart
final showApprovalFallback = item.isOrder &&
    _isOrderRelevantForContext(item.order!.id) &&
    item.order!.status == OrderStatus.pendingApproval &&
    !_messages.any((m) => m.type == MessageType.approval && (m.orderId ?? '') == item.order!.id);
// ...
if (showApprovalFallback)
  _ApprovalPendingFallbackCard(
    order: item.order!,
    onRefresh: () async {
      await ref.read(ordersProvider.notifier).loadOrders();
      if (mounted) _loadMessages();
    },
  ),
```

#### _shouldShowApprovalCard и _hasApprovalMessageForOrder (строки 243-278)

```dart
bool _isOrderRelevantForContext(String? orderId) {
  if (orderId == null || orderId.isEmpty) return true;
  if (widget.currentOrderId == null) return true;
  return orderId == widget.currentOrderId;
}

bool _shouldShowApprovalCard(WidgetRef ref, ChatMessage message, List<Order> chatOrders) {
  if (message.type != MessageType.approval) return false;
  final orderId = message.orderId ?? widget.chat.orderId;
  if (orderId.isEmpty) return false;
  if (!_isOrderRelevantForContext(orderId)) return false;
  Order? order;
  try { order = chatOrders.firstWhere((o) => o.id == orderId); } catch (_) {}
  if (order != null && order.status != OrderStatus.pendingApproval && order.status != OrderStatus.pendingConfirmation) {
    return false;
  }
  final approvalsForOrder = _messages
      .where((m) => m.type == MessageType.approval && (m.orderId ?? '') == orderId)
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  if (approvalsForOrder.isEmpty) return false;
  return approvalsForOrder.first.id == message.id;
}

bool _hasApprovalMessageForOrder(List<_TimelineItem> timeline, String orderId) {
  return timeline.any((t) =>
      t.message != null &&
      t.message!.type == MessageType.approval &&
      (t.message!.orderId ?? '') == orderId);
}
```

#### Рендер: approval vs fallback vs текст (строки 460-484)

```dart
else if (item.message!.type == MessageType.system)
  _SystemMessage(text: item.message!.content)
else if (item.message!.type == MessageType.approval) ...[
  if (_isOrderRelevantForContext(item.message!.orderId) && _shouldShowApprovalCard(ref, item.message!, chatOrders))
    _ApprovalCard(...),
]
else
  _MessageBubble(message: item.message!),
```

### Client — виджет fallback (текст «Запрос согласования формируется»)

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chat_detail_screen.dart` (строки 885-937)

```dart
/// Fallback: заказ в статусе «Требуется согласование», но в чате ещё нет approval-сообщения (ошибка состояния).
class _ApprovalPendingFallbackCard extends StatelessWidget {
  final Order order;
  final Future<void> Function() onRefresh;

  const _ApprovalPendingFallbackCard({required this.order, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      // ...
      child: Column(
        children: [
          // ...
          const Text('Запрос согласования формируется', ...),
          Text('Обновите чат, чтобы увидеть перечень работ и подтвердить изменения.', ...),
          FilledButton.icon(onPressed: () => onRefresh(), icon: ..., label: const Text('Обновить'), ...),
        ],
      ),
    );
  }
}
```

---

## 0.4 Мерж сообщений и «строки/ссылки»

### Client — _loadMessages (мерж по «сегодня»)

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chat_detail_screen.dart` (строки 81-99)

```dart
Future<void> _loadMessages() async {
  final repo = ref.read(chatRepositoryProvider);
  final result = await repo.getMessages(widget.chat.id);
  if (result.dataOrNull == null) return;
  final fromApi = result.dataOrNull!;
  if (_messages.isEmpty) {
    setState(() => _messages = fromApi);
    ref.read(ordersProvider.notifier).loadOrders();
    return;
  }
  // В открытом диалоге обновляем только сообщения за сегодня — старые не трогаем
  final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final oldFromExisting = _messages.where((m) => m.timestamp.isBefore(todayStart)).toList();
  final fromApiToday = fromApi.where((m) => !m.timestamp.isBefore(todayStart)).toList();
  final merged = [...oldFromExisting, ...fromApiToday];
  merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  setState(() => _messages = merged);
  ref.read(ordersProvider.notifier).loadOrders();
}
```

### Business — loadMessagesFor (мерж по «сегодня»)

**Файл:** `autohub_business/lib/core/repositories/chat_repository.dart` (строки 108-128)

```dart
Future<void> loadMessagesFor(String chatId) async {
  _loadMessagesToken?.cancel();
  _loadMessagesToken = CancelToken();
  final result = await _api.getMessages(chatId, cancelToken: _loadMessagesToken);
  if (result.dataOrNull == null) return;
  final fromApi = result.dataOrNull!;
  final updated = Map<String, List<ChatMessage>>.from(state.messages);
  final existing = state.messages[chatId];
  if (existing != null && existing.isNotEmpty) {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final oldFromExisting = existing.where((m) => m.at.isBefore(todayStart)).toList();
    final fromApiToday = fromApi.where((m) => !m.at.isBefore(todayStart)).toList();
    final merged = [...oldFromExisting, ...fromApiToday];
    merged.sort((a, b) => a.at.compareTo(b.at));
    updated[chatId] = merged;
  } else {
    updated[chatId] = fromApi;
  }
  state = ChatRepositoryState(chats: state.chats, messages: updated);
}
```

Отдельной фильтрации «скрыть text при наличии approval» в UI нет; пропажа «строк» может быть из-за ответа API или логики мержа.

---

## 0.5 Client — парсинг сообщения и тип approval (orderId, approval_items)

**Файл:** `autohub_client2/lib/core/repositories/api_chat_repository.dart` (строки 58-132)

```dart
static ChatMessage _messageFromJson(String chatId, Map<String, dynamic> j) {
  // ...
  final approvalRaw = j['approval_items'] ?? j['approvalItems'];
  List<ApprovalMessageItem>? approvalItems;
  List<ApprovalMessageItem>? editedApprovalItems;
  List<ApprovalMessageItem>? newApprovalItems;
  if (approvalRaw is List<dynamic> && approvalRaw.isNotEmpty) {
    approvalItems = approvalRaw.map((e) => { ... }).toList();
  } else if (approvalRaw is Map<String, dynamic>) {
    final edited = approvalRaw['edited_items'] ?? approvalRaw['editedItems'];
    final newList = approvalRaw['new_items'] ?? approvalRaw['newItems'];
    // editedApprovalItems, newApprovalItems ...
  }
  final hasApproval = (approvalItems != null && approvalItems.isNotEmpty) ||
      (editedApprovalItems != null && editedApprovalItems.isNotEmpty) ||
      (newApprovalItems != null && newApprovalItems.isNotEmpty);
  final orderId = j['order_id']?.toString() ?? j['orderId']?.toString();
  final content = j['text']?.toString() ?? j['content']?.toString() ?? '';
  final type = isSystem
      ? MessageType.system
      : (hasApproval ? MessageType.approval : MessageType.text);
  return ChatMessage(
    id: j['id']?.toString() ?? '',
    chatId: chatId,
    // ...
    type: type,
    orderId: orderId,
  );
}
```

Если в ответе GET/POST нет `order_id` или `approval_items` (в формате список или объект с `edited_items`/`new_items`), сообщение не станет `MessageType.approval` или не привяжется к orderId — появится fallback.

---

## Сводка

| Что | Где |
|-----|-----|
| Отправка approval | ConfirmCorrectOrderScreen → chatRepo.sendApprovalRequest → ChatApiService.sendApprovalRequest → **POST /chats/:chatId/messages** |
| Тело запроса | `order_id`, `approval_items` (edited_items/new_items или список) |
| Проверка «есть approval» Business | `messages.any((m) => m.isApprovalCard && (m.orderId ?? '') == order.id)` |
| Проверка «есть approval» Client | `_messages.any((m) => m.type == MessageType.approval && (m.orderId ?? '') == item.order!.id)` |
| Fallback | Показ при `pending_approval` и отсутствии такого сообщения |
| Мерж сообщений | По границе «сегодня»: старые из state, за сегодня из API |

Бэкенд в репозитории MP не найден; создание ChatMessage с `order_id` и `approval_items` и установка `pending_approval` должны быть в обработчике POST `/chats/:id/messages` на сервере.

---

## Какой chatId открывается в UI и какой в логах [approval_request]

### Business: какой chatId в UI

- **Открытие чата из списка чатов**  
  `chats_screen.dart` → по тапу по чату: `ChatDetailScreen(chatId: c.id)`.  
  **chatId = `c.id`** — id чата из списка (GET `/chats`), тот чат, по которому пользователь нажал.

- **Открытие «Подтвердить или скорректировать» / «Изменить состав заказа» из карточки заказа**  
  `order_detail_screen.dart`: `ConfirmCorrectOrderScreen(orderId: orderId)` вызывается **без chatId** (виджет получает только `orderId`).  
  **chatId при отправке** в `confirm_correct_order_screen.dart` определяется так:
  1. если передан `widget.chatId` — он и используется;
  2. иначе ищется чат в `state.chats` по `c.orderId == widget.orderId` → берётся `c.id`;
  3. если не найден — вызывается `orderApi.getChatForOrder(widget.orderId)` (GET `/orders/:orderId/chat`) → **chatId = ответ `chat_id`**.

- **Открытие «Доп. работы → на согласование» из карточки заказа (статус «В работе»)**  
  Сразу вызывается `orderApi.getChatForOrder(orderId)`; полученный **chatId** передаётся в `ConfirmCorrectOrderScreen(orderId: orderId, chatId: chatId, additionalWorksOnly: true)`.

Итог для одного и того же заказа в Business: chatId в UI чата = id чата из списка (если открыли из списка) или тот же id, что возвращает GET `/orders/:orderId/chat` (если открыли из заказа и чат подставляется по orderId / getChatForOrder). Ожидается, что это один и тот же чат.

---

### Client: какой chatId в UI

- **Открытие чата из списка чатов**  
  По тапу: `ChatDetailScreen(chat: chat)`.  
  Все запросы по чату идут с **chatId = `widget.chat.id`** (id из списка чатов, GET `/chats`).

- **Открытие чата из карточки заказа («Перейти в чат»)**  
  `order_detail_screen.dart` → `_openChat()`:
  ```dart
  final chats = ref.read(chatsProvider).valueOrNull ?? [];
  chat = chats.firstWhere((c) => c.stoId == order.stoId);  // первый чат с таким же stoId!
  pushCupertino(context, ChatDetailScreen(chat: chat, currentOrderId: order.id));
  ```
  **chatId в UI = `chat.id`** — это id **первого в списке** чата с тем же `stoId`, что и у заказа. По **orderId** выбор чата не делается. Если у клиента несколько чатов с одним СТО (разные заказы), может открыться чат с другим orderId, и тогда approval по нужному заказу будет в другом чате.

---

### Лог [approval_request] на backend: какой chatId

**Файл:** `backend/src/chats/chats.service.ts` (строка 332):

```ts
console.log('[approval_request] orderId=' + effectiveOrderId + ', chatId=' + chatId + ', messageId=' + saved.id + ', previousStatus=' + previousStatus + ', nextStatus=pending_approval');
```

**chatId** здесь — это параметр метода `sendMessage(chatId, dto, ...)`, т.е. **тот chatId, что в URL запроса**:  
**POST `/chats/:chatId/messages`** — значит в лог попадает ровно тот chatId, который подставило приложение Business в этот запрос.

Для одного и того же orderId при отправке approval из Business chatId в логе `[approval_request]` должен совпадать с:
- chatId чата, открытого в Business (если открыли чат по этому заказу и из него отправили), и
- chatId чата, который backend связывает с этим заказом (чат, в который реально пишется сообщение).

Если у клиента открыт другой чат (другой chatId, например из‑за выбора по `stoId` вместо orderId), то в UI у клиента будет другой chatId, а в логах — chatId того чата, куда Business отправил сообщение.
