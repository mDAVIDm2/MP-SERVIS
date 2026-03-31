# ЗАДАЧА: Чаты — approval-карточки не отображаются (Client + Business), скрыть “Заявка отправлена”, сделать badge непрочитанных, и привести контракты API/WS к одному стандарту.
# Важно: backend уже логирует [approval_request] с chatId/messageId → значит сообщение создаётся. Проблема сейчас в контракте ответа/парсинге/рендере/условиях показа.

## СИМПТОМЫ
- В Client и Business в чате остаётся “Заявка отправлена”, approval-card не появляется.
- Лог backend есть: [approval_request] orderId=..., chatId=..., messageId=..., previousStatus=..., nextStatus=pending_approval
- Значит сообщение создаётся, но не доходит/не парсится/не рисуется.
- WebSocket может быть нестабилен и/или backend не поддерживает upgrade → нельзя падать и нельзя “терять” сообщения молча.

---

# ШАГ 0 — Стабильность: WS не обязателен, приложение не должно зависеть от него
0.1 Найди все места, где создаётся WebSocketChannel (Client и Business).
0.2 Сделай так, чтобы:
- подключение к WS было optional (feature flag / env enableWs=false для dev)
- любые ошибки подключения НЕ роняли приложение
- если WS не доступен — чаты работают через REST refetch
0.3 В Business `_onWsMessage` запрети пустой `catch {}`:
- логируй ошибку + payload (хотя бы print/debugLog)
- это нужно, чтобы видеть несоответствия формата

Проверка: приложение не падает, WS может быть отключён вообще.

---

# ШАГ 1 — Привести GET /chats/:id/messages к одному контракту (КРИТИЧНО)
Проблема: Client читает только data['items'], Business — items/data/messages.

1.1 В Client (api_chat_repository.dart) сделай устойчивый разбор списка:
- list = data['items'] ?? data['data'] ?? data['messages'] ?? []
- также поддержи обёртки вида { data: { items: [...] } } или { data: [...] }
1.2 В Business (chat_api_service.dart) тоже сделай единый util parseList() чтобы везде одинаково.
1.3 Добавь временный debug лог в обоих приложениях:
- распечатать ключи res.data (что реально приходит)
- распечатать list.length

Проверка:
- после GET messages в Client list.length > 0 и в нём есть messageId из [approval_request].

---

# ШАГ 2 — Привести POST /chats/:chatId/messages к одному контракту (КРИТИЧНО)
Проблема: Business сейчас парсит res.data как одно сообщение, но бек может вернуть обёртку.

2.1 В Business chat_api_service.dart:
- если res.data = { data: {...} } → парсить data
- если res.data = { message: {...} } → парсить message
- если res.data = {...} → парсить напрямую
2.2 Аналогично (если есть POST сообщений в Client) — сделать так же.
2.3 На backend (если возможно) стандартизировать ответ POST:
- возвращать всегда один объект message без обёртки ИЛИ всегда в {data: message}
- но фронт всё равно должен понимать оба варианта.

Проверка:
- после отправки согласования Business получает ChatMessage, в котором approval_items распарсились и messageId совпадает с созданным.

---

# ШАГ 3 — Унифицировать ChatMessage.fromJson (поля + approval_items)
3.1 В Client и Business модель ChatMessage.fromJson должна поддерживать оба формата:
- approval_items / approvalItems
- is_system / isSystem
- order_id / orderId
- created_at / createdAt / at
3.2 approval_items:
- поддержать и legacy list, и object {edited_items,new_items}
- hasApproval должно быть true если:
  - list не пуст
  - ИЛИ edited_items не пуст
  - ИЛИ new_items не пуст
- не “ломать” карточку если один из массивов null/пустой (клиент сейчас слишком строгий).

Проверка:
- вывести debug: для approval message → hasApproval=true, orderId непустой.

---

# ШАГ 4 — Починить условия отображения approval-card (САМОЕ ЧАСТОЕ ПОЧЕМУ “ЕСТЬ НО НЕ ВИДНО”)
Сейчас UI привязан к статусу заказа и к наличию заказа в chatOrders.

4.1 Client chat_detail_screen.dart:
- НЕ требовать, чтобы order обязательно нашёлся в chatOrders
- если message.hasApproval == true → показывать карточку даже если orders ещё не подгрузились
- если order найден, можно дополнительно показывать статус/баннер
- но рендер карточки НЕ должен зависеть от order.status (иначе гонка обновлений ломает UI)
4.2 Business chat_detail_screen.dart:
- убрать/ослабить блокировку “если order != null && !order.status.isActive → скрыть”
- approval-card должна показываться даже если статус внезапно не “active”, иначе это ломает историю согласований
4.3 Добавить явный refetch orders при открытии чата со стороны клиента (когда жмёт “Перейти в чат”):
- сначала обновить order details
- потом loadMessages
- так статус pending_approval и список заказов синхронизируются быстрее

Проверка:
- после отправки согласования карточка появляется в чате даже если статус/заказ ещё догружается.

---

# ШАГ 5 — Скрыть “Заявка отправлена”, когда есть согласование
Без изменения схемы БД можно сделать UI-логику:
- если в сообщениях есть хотя бы одно approval message (hasApproval==true), то “Заявка отправлена” не показывать (или свернуть в историю).
Если хотите правильно — добавить type, но для быстрого фикса достаточно правила выше.

Проверка:
- после появления approval message “Заявка отправлена” исчезает/уходит вниз в историю.

---

# ШАГ 6 — Системные сообщения (запрос отправлен / подтверждено по телефону)
6.1 Backend: при отправке согласования дополнительно создать system message:
"СТО отправило запрос на согласование дополнительных работ"
6.2 Client/Business UI: системные сообщения рисовать отдельным стилем (по центру).
6.3 Confirm-by-phone: убедиться, что system message реально попадает в список сообщений (и не скрывается фильтрами по text).

Проверка:
- в чате видно system message после отправки согласования и после confirm-by-phone.

---

# ШАГ 7 — Badge непрочитанных на вкладке Чаты
7.1 Backend: last_read_at на Chat (client/business) + unreadCount в GET /chats
7.2 Client/Business: считать totalUnread и рисовать badge на иконке чата в BottomNavigationBar
7.3 При открытии чата дергать POST /chats/:id/read и refetch /chats

Проверка:
- badge увеличивается при новых сообщениях и сбрасывается после открытия чата.

---

## Acceptance Criteria
- approval-card видна у клиента и у СТО сразу после отправки
- “Заявка отправлена” скрывается при наличии approval
- системные сообщения видны
- приложение не зависит от WS
- badge непрочитанных работает