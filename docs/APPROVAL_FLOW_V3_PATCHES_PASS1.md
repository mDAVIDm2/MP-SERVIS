# Approval-flow v3: выгрузка правок (проход 1 — шаги 1, 2, 7)

Правки внесены в коде. Ниже — выгрузка изменённых фрагментов для проверки и ручного теста.

---

## ШАГ 1 — Client: выбор чата по orderId

**Цель:** «Перейти в чат» из карточки заказа открывает тот `chatId`, куда Business пишет approval (GET `/orders/:orderId/chat` → `chat_id`).

### 1.1 Client: endpoint и API

**Файл:** `autohub_client2/lib/core/api/api_endpoints.dart`

Добавлено:

```dart
  /// Чат по заказу (GET /orders/:orderId/chat → { chat_id }). Для открытия чата по orderId.
  static String orderChat(String orderId) => '/orders/$orderId/chat';
```

(в блок ORDERS, после `order(id)`.)

---

**Файл:** `autohub_client2/lib/core/api/order_api_service.dart`

Добавлен метод:

```dart
  /// Получить chat_id по заказу (GET /orders/:orderId/chat). Для открытия «правильного» чата по orderId.
  Future<Result<String>> getChatIdForOrder(String orderId) async {
    try {
      final res = await _client.get(ApiEndpoints.orderChat(orderId));
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Неверный формат ответа'));
      }
      final chatId = data['chat_id'] as String? ?? data['chatId'] as String?;
      if (chatId == null || chatId.isEmpty) {
        return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Нет chat_id в ответе'));
      }
      return Result.success(chatId);
    } on DioException catch (e) {
      return Result.failure(ApiException.fromDioError(e));
    }
  }
```

---

### 1.2 Client: _openChat по orderId + stub Chat

**Файл:** `autohub_client2/lib/features/orders/presentation/screens/order_detail_screen.dart`

- Добавлен импорт: `import 'package:flutter/foundation.dart';` (для `kDebugMode` / `debugPrint`).
- Метод `_openChat` заменён на асинхронный вариант:

```dart
  /// Открыть чат по заказу: GET /orders/:orderId/chat → chat_id, затем открыть тот же chatId, куда Business пишет approval.
  Future<void> _openChat(BuildContext context, WidgetRef ref, Order order) async {
    final orderApi = ref.read(orderApiServiceProvider);
    final chatIdResult = await orderApi.getChatIdForOrder(order.id);
    final resolvedChatId = chatIdResult.dataOrNull;
    if (resolvedChatId == null || resolvedChatId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(chatIdResult.errorOrNull?.message ?? 'Чат по заказу не найден'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[open_chat_from_order] orderId=${order.id}, resolvedChatId=$resolvedChatId, stoId=${order.stoId}');
    }
    await ref.read(chatsProvider.notifier).loadChats();
    if (!context.mounted) return;
    final chats = ref.read(chatsProvider).valueOrNull ?? [];
    Chat? chat;
    for (final c in chats) {
      if (c.id == resolvedChatId) {
        chat = c;
        break;
      }
    }
    if (chat == null) {
      chat = Chat(
        id: resolvedChatId,
        stoId: order.stoId,
        stoName: order.stoName,
        orderId: order.id,
        orderNumber: order.orderNumber,
        carBrand: '',
        carModel: '',
        orderStatus: order.status,
        lastMessage: null,
        lastMessageTime: null,
        lastMessageFromUser: false,
        lastMessageStatus: MessageDeliveryStatus.read,
        unreadCount: 0,
        isPinned: false,
        isArchived: false,
      );
    }
    if (context.mounted) {
      pushCupertino(context, ChatDetailScreen(chat: chat!, currentOrderId: order.id));
    }
  }
```

Вызовы `_openChat(context, ref, order)` оставлены без изменений (кнопки «Перейти в чат» и т.п.); метод теперь сам выполняет запрос и навигацию.

---

## ШАГ 2 — Business: кнопка «Открыть чат» по orderId

**Цель:** СТО всегда открывает чат по заказу через GET `/orders/:orderId/chat` → `chat_id` → `ChatDetailScreen(chatId, currentOrderId)`.

### 2.1 Импорт и кнопка в карточке заказа

**Файл:** `autohub_business/lib/features/orders/presentation/screens/order_detail_screen.dart`

- Добавлен импорт:  
  `import '../../chats/presentation/screens/chat_detail_screen.dart';`
- В виджете `_Actions`, в начале `Column(children: [...])`, добавлен блок для активных заказов:

```dart
        if (order.status.isActive) ...[
          OutlinedButton.icon(
            onPressed: () async {
              final orderApi = ref.read(orderApiServiceProvider);
              final chatResult = await orderApi.getChatForOrder(orderId);
              if (!context.mounted) return;
              final chatId = chatResult.dataOrNull;
              if (chatId == null || chatId.isEmpty) {
                showMessage(chatResult.errorOrNull?.message ?? 'Чат по заказу не найден');
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(chatId: chatId, currentOrderId: orderId),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            label: const Text('Открыть чат'),
          ),
          const SizedBox(height: 8),
        ],
```

Кнопка показывается для всех заказов с `order.status.isActive == true`.

---

## ШАГ 7 — UI: переименование кнопок

**Цель:** Одна кнопка «Изменить состав заказа» (отдельная кнопка «Подтвердить» без изменений).

### 7.1 Кнопка в карточке заказа (Business)

**Файл:** `autohub_business/lib/features/orders/presentation/screens/order_detail_screen.dart`

- В блоке `order.status == OrderStatus.pendingConfirmation` текст кнопки заменён:  
  **было:** `'Подтвердить или скорректировать'`  
  **стало:** `'Изменить состав заказа'`

```dart
            child: const Text('Изменить состав заказа'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setStatus(OrderStatus.confirmed, 'Заказ подтверждён без изменений'),
            child: const Text('Подтвердить без изменений'),
```

### 7.2 Заголовок экрана «Изменить состав заказа» (Business)

**Файл:** `autohub_business/lib/features/orders/presentation/screens/confirm_correct_order_screen.dart`

- В `AppBar` заголовок заменён:  
  **было:** `'Подтвердить или скорректировать'`  
  **стало:** `'Изменить состав заказа'`

```dart
        title: const Text('Изменить состав заказа'),
```

---

## Список изменённых файлов (проход 1)

| Файл | Изменения |
|------|-----------|
| `autohub_client2/lib/core/api/api_endpoints.dart` | Добавлен `orderChat(orderId)`. |
| `autohub_client2/lib/core/api/order_api_service.dart` | Добавлен `getChatIdForOrder(orderId)`. |
| `autohub_client2/lib/features/orders/presentation/screens/order_detail_screen.dart` | Импорт `foundation`; `_openChat` переписан: GET chat по orderId, loadChats, поиск/ stub Chat, debug-лог, открытие `ChatDetailScreen`. |
| `autohub_business/lib/features/orders/presentation/screens/order_detail_screen.dart` | Импорт `ChatDetailScreen`; кнопка «Открыть чат» (GET chat по orderId → `ChatDetailScreen`); кнопка «Подтвердить или скорректировать» → «Изменить состав заказа». |
| `autohub_business/lib/features/orders/presentation/screens/confirm_correct_order_screen.dart` | Заголовок AppBar → «Изменить состав заказа». |

---

## Ручная проверка после прохода 1

**ШАГ 1 (Client):**

1. Клиент: заказ → «Перейти в чат».
2. В логе (dev): `[open_chat_from_order] orderId=..., resolvedChatId=..., stoId=...`.
3. Business: отправить согласование по этому заказу.
4. В backend-логе: `[approval_request] orderId=..., chatId=...`.
5. Убедиться: `resolvedChatId` у клиента совпадает с `chatId` в логе `[approval_request]`, в открытом чате видна approval-карточка (не fallback).

**ШАГ 2 (Business):**

1. Business: открыть заказ → нажать «Открыть чат».
2. Открывается чат по этому заказу.
3. Отправить согласование из того же заказа (или уже отправленное) — в этом чате должна быть видна approval-карточка, не fallback.

**ШАГ 7:**

1. Business: заказ в статусе «Ожидает подтверждения» — первая кнопка с текстом «Изменить состав заказа», вторая — «Подтвердить без изменений».
2. Открытие экрана корректировки — в AppBar заголовок «Изменить состав заказа».

После успешной проверки можно переходить к шагам 3–6 (backend, merge сообщений, new_items id, системные сообщения).
