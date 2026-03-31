# Debug: порядок загрузки и отображения order links в чате STO

## Цель

Локализовать разницу между тремя сценариями:
1. **First open** — первое открытие диалога (часто «Заказ загружается...»).
2. **Switch dialog** — переход в другой чат и обратно (ссылки потом отображаются).
3. **App resume** — сворачивание/разворачивание приложения (ссылки потом отображаются).

## Включение логов

Логи выводятся только в **Debug** (`kDebugMode == true`). В release сборке отключены.

Фильтр в консоли/логе: **`[ChatOrderDebug]`**.

## Точки логирования

| Точка | Файл | Что логируется |
|-------|------|----------------|
| `ensureChatDataLoaded` | chat_detail_screen.dart | START/END, chatId, после каждого шага: chatsCount, ordersCount, messagesCount, uniqueOrderIdsInMessages |
| `initState` | ChatDetailScreen | chatId |
| `didChangeDependencies` | ChatDetailScreen | chatId |
| `didUpdateWidget` | ChatDetailScreen | oldChatId, newChatId, факт смены chatId и вызова _loadChatData (switch path) |
| `didChangeAppLifecycleState` | ChatDetailScreen | state (resumed/…), факт вызова _loadChatData (resume path) |
| `_loadChatData` | ChatDetailScreen | START/END, chatId, после loadFromApi: ordersCount, после loadMessagesFor: messagesCount, uniqueOrderIdsInMessages, ordersCount |
| `build` | ChatDetailScreen | chatId, messagesCount, uniqueOrderIdsInMessages, chatOrdersCount, allOrdersCount, orderIdsResolved, orderIdsUnresolved |
| `_OrderLinkInline.build` | chat_detail_screen.dart | orderId (short), orderResolved, orderNumber, label=OK/FALLBACK |
| `loadMessagesFor` | chat_repository.dart | START, chatId; fromApi: messagesCount, uniqueOrderIds; state updated: finalMessagesCount |
| `ChatRepository.loadFromApi` | chat_repository.dart | START; state updated: chatsCount или error |
| `OrderRepository.loadFromApi` | order_repository.dart | START: currentStateCount; state updated: newCount, orderIds (первые 3) или no data |

## Как сравнивать сценарии

1. **First open**  
   Открыть приложение → вкладка Чаты → один раз открыть нужный диалог.  
   Сохранить лог от момента тапа по чату до стабилизации экрана. Обратить внимание:
   - вызывается ли `ensureChatDataLoaded` до появления экрана;
   - в каком порядке идут `loadFromApi` (orders) и `loadMessagesFor`;
   - в первом `build` ChatDetailScreen: `allOrdersCount`, `orderIdsResolved`, `orderIdsUnresolved`;
   - в `_OrderLinkInline.build`: сколько раз `label=FALLBACK` и при каких `orderId`.

2. **Switch dialog**  
   Открыть чат A → переключиться на чат B → вернуться на чат A.  
   Сохранить лог при возврате на A. Сравнить с first open:
   - вызывается ли `didUpdateWidget` и затем `_loadChatData` для chatId A;
   - после `_loadChatData` END: те же метрики (messagesCount, ordersCount, uniqueOrderIds);
   - в следующем `build`: те же `orderIdsResolved` / `orderIdsUnresolved`;
   - в `_OrderLinkInline.build`: те же orderId теперь с `label=OK` или всё ещё FALLBACK.

3. **App resume**  
   Открыть чат → свернуть приложение → развернуть.  
   Сохранить лог с момента resume. Проверить:
   - вызов `didChangeAppLifecycleState` с `state=resumed`;
   - вызов `_loadChatData` (resume path);
   - после `_loadChatData` END: значения messagesCount, ordersCount, uniqueOrderIds;
   - следующий `build`: orderIdsResolved / orderIdsUnresolved;
   - в `_OrderLinkInline.build`: смена FALLBACK → OK для тех же orderId.

## Что искать (корневая причина)

- **Порядок данных:** на first open при первом `build` уже есть `messages`, но `allOrdersCount == 0` или `orderIdsUnresolved > 0`? Значит, orders приходят позже первого рендера.
- **Путь обновления:** при resume/switch вызывается `_loadChatData` → обновляются orders и messages → следующий `build` видит полные данные. На first open `_loadChatData` вызывается в `addPostFrameCallback` — первый `build` уже прошёл до этого?
- **Подписка виджета:** `_OrderLinkInline` подписан на `orderByIdProvider(orderId)`. После обновления `orderRepositoryProvider` виджет должен перестроиться. В логах: при first open после обновления orders есть ли повторные `_OrderLinkInline.build` с теми же orderId и уже `label=OK`? Если нет — возможно, подписка не срабатывает или build не вызывается.

## Отключение логов после локализации

В `chat_detail_screen.dart`:

```dart
const bool _kChatOrderDebug = false;  // было kDebugMode
```

Либо удалить вызовы `_chatOrderLog` и логи в репозиториях по префиксу `[ChatOrderDebug]`.
