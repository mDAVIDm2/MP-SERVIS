# Отчёт: баг order links в чате STO

## Симптом

- При первом открытии диалога вместо строк-ссылок на заказ часто показывается «Заказ загружается...».
- После сворачивания/разворачивания приложения или после перехода в другой диалог и обратно ссылки отображаются правильно.

## Шаг 1. Разница между сценариями (локализация через логи)

Во все перечисленные точки добавлены debug-логи с префиксом `[ChatOrderDebug]` (включены только при `kDebugMode`).

### Точки логирования

| Сценарий | Что вызывается |
|----------|-----------------|
| **First open** | `ensureChatDataLoaded` (если открытие из списка чатов/заказа) → push/setState → `initState` → первый `build` → `addPostFrameCallback` → `_loadChatData()` (асинхронно). |
| **Switch dialog** | `didUpdateWidget(chatId changed)` → `_resumePathWorkaroundChatId = null` → `addPostFrameCallback(_loadChatData)` → `_loadChatData()` → `setState` → `build`. |
| **App resume** | `didChangeAppLifecycleState(resumed)` → `_loadChatData()` → после завершения `setState` → `build`. |

### Ожидаемая разница (гипотеза)

- **First open:** первый `build` выполняется **до** завершения `_loadChatData()` (она запущена в `postFrameCallback` и асинхронна). В этот момент в `orderRepositoryProvider` могут быть ещё старые/пустые данные (если до открытия не вызывался `ensureChatDataLoaded` или он не успел завершиться).
- **Resume / switch:** `_loadChatData()` вызывается явно, после её завершения вызывается `setState` → повторный `build` уже с обновлёнными orders и messages.

Итог: при первом открытии виджет может отрисоваться с пустым/устаревшим `orderRepositoryProvider`; при resume/switch данные перед вторым `build` уже обновлены.

## Шаг 2. Потеря данных из orderRepositoryProvider

- Заказы попадают в репозиторий при вызове `OrderRepository.loadFromApi()` (из `ensureChatDataLoaded` или из `_loadChatData`).
- На момент первого `build` ChatDetailScreen заказы могут ещё не быть загружены, если экран открыт до завершения `ensureChatDataLoaded` или без его вызова.
- `orderByIdProvider(orderId)` возвращает `null`, пока в `orderRepositoryProvider` нет заказа с таким `id`; после обновления репозитория провайдер пересчитывается и виджет, подписанный через `ref.watch(orderByIdProvider(orderId))`, должен перестроиться. Если родительский экран не перестраивается (нет `setState` после загрузки), дочерние Consumer-виджеты всё равно должны обновляться при смене провайдера. Логи покажут, сколько `orderIdsResolved` / `orderIdsUnresolved` в каждом `build` и сколько раз `_OrderLinkInline` показывает FALLBACK.

## Шаг 3. Порядок pipeline (сообщения → превью заказов → рендер)

Текущий порядок:

1. В `build` читаются `messages` и `chatOrders` из провайдеров.
2. Строится `timeline` и для каждого элемента с `orderId` рендерится `_OrderLinkInline(orderId)`.
3. `_OrderLinkInline` подписан на `orderByIdProvider(orderId)` и показывает «Заказ загружается...», если заказ ещё не найден.

Проблема: рендер ссылок выполняется при каждом `build`; если заказы ещё не подгружены, показывается placeholder. После завершения `_loadChatData()` и обновления `orderRepositoryProvider` должен происходить пересчёт `orderByIdProvider` и перестроение `_OrderLinkInline`. Временный workaround (шаг 4) гарантирует повторный вызов того же пути загрузки при наличии неразрешённых `orderId`.

## Шаг 4. Lifecycle resume и повторное использование пути

- При **resume** вызывается `didChangeAppLifecycleState(AppLifecycleState.resumed)` → `_loadChatData()`.
- В `_loadChatData()`: `markChatRead` → `loadFromApi()` (orders) → `loadMessagesFor(chatId)` → в конце `setState(() {})`.
- После этого выполняется новый `build`, в репозитории уже актуальные orders и messages, ссылки отображаются.

Временный workaround: если в `build` есть сообщения с `orderId`, но часть из них не разрешена (`orderIdsUnresolved > 0`), один раз для данного `chatId` планируется дополнительный вызов `_loadChatData()` в `addPostFrameCallback`. Таким образом при первом открытии выполняется тот же путь обновления, что и при resume, и ссылки должны обновиться после второй загрузки. Помечено в коде как «Временный workaround».

## Шаг 5. Отображение ссылки (уже реализовано)

- Используется один виджет `_OrderLinkInline`: компактная строка по центру, не на всю ширину.
- Дублирующий текст «Заявка отправлена» убирается за счёт дедупликации в timeline (если есть карточка заказа/ожидания подтверждения, отдельный блок «Заявка отправлена» не рисуется).
- Для pending confirmation / pending approval используется та же компактная ссылка.

## Шаг 6. Номер заказа (уже реализовано)

- В `_OrderLinkInline` не показывается raw UUID: при отсутствии или «uuid-подобном» `orderNumber` показывается «Заказ загружается...» или «Открыть заказ», иначе `Открыть заказ ##${order.orderNumber}`.
- `_looksLikeUuid` отсекает отображение uuid-подобных значений в качестве номера заказа.

## Что изменено в коде

### 1. Debug-логи (для локализации и сравнения сценариев)

- **chat_detail_screen.dart**
  - Константа `_kChatOrderDebug = kDebugMode` и функция `_chatOrderLog(scene, message, data)`.
  - Логи в: `ensureChatDataLoaded` (START, после каждого шага, END с количеством сообщений и orderIds), `initState`, `didChangeDependencies`, `didUpdateWidget`, `didChangeAppLifecycleState`, `_loadChatData` (START, после loadFromApi orders, END), `build` (количество сообщений, orderIds, разрешённых/неразрешённых, chatOrdersCount, allOrdersCount), `_OrderLinkInline.build` (orderId, orderResolved, orderNumber, label FALLBACK/OK), срабатывание workaround.
- **chat_repository.dart**
  - В `loadFromApi`: START и после обновления state (chatsCount или error).
  - В `loadMessagesFor`: START (chatId), после получения fromApi (messagesCount, uniqueOrderIds), после обновления state (finalMessagesCount).
- **order_repository.dart**
  - В `loadFromApi`: START (currentStateCount), после обновления state (newCount, первые orderIds) или при отсутствии данных.

### 2. Временный workaround (один повторный путь как при resume)

- **chat_detail_screen.dart**
  - Поле `_resumePathWorkaroundChatId`.
  - В `build`: если есть сообщения с `orderId`, но часть не разрешена (`unresolvedCount > 0`) и для текущего `chatId` workaround ещё не запускался — выставляется `_resumePathWorkaroundChatId = widget.chatId` и в `addPostFrameCallback` один раз вызывается `_loadChatData()`.
  - В `didUpdateWidget` при смене `chatId`: `_resumePathWorkaroundChatId = null`, чтобы workaround мог сработать для нового чата.

### 3. Документация

- **docs/CHAT_ORDER_LINKS_DEBUG.md** — как включать логи, какие точки смотреть, как сравнивать first open / switch / resume.
- **docs/CHAT_ORDER_LINKS_FIX_REPORT.md** — этот отчёт.

## Изменённые файлы

| Файл | Изменения |
|------|-----------|
| `lib/features/chats/presentation/screens/chat_detail_screen.dart` | Логи, флаг и вызов workaround при неразрешённых orderId, сброс флага при смене чата. |
| `lib/core/repositories/chat_repository.dart` | Логи в `loadFromApi` и `loadMessagesFor`. |
| `lib/core/repositories/order_repository.dart` | Импорт `foundation`, логи в `loadFromApi`. |
| `docs/CHAT_ORDER_LINKS_DEBUG.md` | Новый файл — инструкция по отладке. |
| `docs/CHAT_ORDER_LINKS_FIX_REPORT.md` | Новый файл — отчёт о причине и правках. |

## Временный workaround vs постоянный fix

- **Временный workaround:** при первом `build` с неразрешёнными `orderId` один раз планируется дополнительный вызов `_loadChatData()` (тот же путь, что при resume). Помечен в коде комментарием «Временный workaround». После сбора логов и подтверждения причины его можно убрать или оставить как страховку.
- **Постоянный fix:** оставлена существующая архитектура: `_OrderLinkInline` подписан на `orderByIdProvider(orderId)` и обновляется при появлении заказа в репозитории; компактная ссылка и запрет показа UUID уже реализованы. При необходимости дальше можно явно вынести «resolve order previews» в отдельный шаг (например, провайдер по списку orderIds из сообщений) и рендерить ссылки только после разрешения, оставив placeholder до этого.

## Критерии приёмки (проверка после включения workaround и по логам)

- При первом открытии чата ссылки на заказ отображаются (сразу или после одного повторного обновления без сворачивания/переключения).
- Без обязательного сворачивания/разворачивания приложения.
- Без обязательного перехода в другой диалог и обратно.
- Для новых заказов строки-ссылки появляются.
- Для pending confirmation / pending approval ссылки отображаются.
- Нет дублей «Заявка отправлена» при одной карточке.
- Нет широких ссылок на всю ширину.
- Нет uuid вместо нормального номера заказа, если номер уже есть.

По логам `[ChatOrderDebug]` можно сверить порядок вызовов и значения `orderIdsResolved` / `orderIdsUnresolved` и FALLBACK в трёх сценариях (first open, switch, resume) и при необходимости скорректировать постоянный fix (например, порядок загрузки или момент первого рендера ссылок).
