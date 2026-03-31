# Approval-flow v3: выгрузка правок (проход 2 — шаги 3, 4, 5, 6)

Правки внесены в коде. Ниже — выгрузка изменённых фрагментов для проверки.

---

## ШАГ 3 — Backend: системное сообщение при создании заказа

**Цель:** После создания заказа клиентом в чат добавляется системное сообщение «Клиент создал заявку. Требуется подтверждение/проверка.»; чат уже создаётся в orders.service (createForOrder + addOrderCardMessage).

### 3.1 ChatsService: addSystemMessage

**Файл:** `backend/src/chats/chats.service.ts`

Добавлен метод (перед `addOrderCardMessage`):

```ts
  /** Добавить системное сообщение в чат (is_system=true). Для уведомления «Клиент создал заявку» и т.д. */
  async addSystemMessage(chatId: string, text: string, orderId?: string | null): Promise<ChatMessage> {
    const msg = this.msgRepo.create({
      chatId,
      text,
      isFromClient: false,
      isSystem: true,
      orderId: orderId ?? null,
    } as Partial<ChatMessage>) as ChatMessage;
    await this.msgRepo.save(msg);
    return msg;
  }
```

### 3.2 OrdersService: вызов при создании заказа

**Файл:** `backend/src/orders/orders.service.ts`

После `createForOrder` и перед `addOrderCardMessage` добавлен вызов:

```ts
    const chat = await this.chats.createForOrder(order.id);
    await this.chats.addSystemMessage(chat.id, 'Клиент создал заявку. Требуется подтверждение/проверка.', order.id);
    const itemsForCard = ...
    await this.chats.addOrderCardMessage(chat.id, order.id, itemsForCard, order.dateTime);
```

---

## ШАГ 4 — Merge сообщений по id (без пропажи строк/ссылок)

**Цель:** Заменить merge «по сегодня» на merge по id сообщений: все existing по id, поверх — fromApi; итог сортировать по времени.

### 4.1 Client: _loadMessages()

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chat_detail_screen.dart`

Блок мержа заменён на:

```dart
    // Merge по id: все existing, поверх — fromApi (обновление). Строки/ссылки не пропадают после refetch.
    final byId = <String, ChatMessage>{};
    for (final m in _messages) {
      byId[m.id] = m;
    }
    for (final m in fromApi) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    setState(() => _messages = merged);
```

### 4.2 Business: loadMessagesFor()

**Файл:** `autohub_business/lib/core/repositories/chat_repository.dart`

В ветке `existing != null && existing.isNotEmpty`:

```dart
    if (existing != null && existing.isNotEmpty) {
      // Merge по id: все existing, поверх — fromApi (обновление). Сообщения не пропадают после refetch.
      final byId = <String, ChatMessage>{};
      for (final m in existing) {
        byId[m.id] = m;
      }
      for (final m in fromApi) {
        byId[m.id] = m;
      }
      final merged = byId.values.toList()..sort((a, b) => a.at.compareTo(b.at));
      updated[chatId] = merged;
    } else {
```

---

## ШАГ 5 — Стабильные id для new_items и approved_item_ids

**Цель:** Business шлёт id для каждой new_item; backend сохраняет их; Client шлёт approved_item_ids по этим id.

### 5.1 Business: ApprovalItem с id, генерация в ConfirmCorrectOrderScreen

**Файл:** `autohub_business/lib/shared/models/chat_model.dart`

В `ApprovalItem` добавлено поле и комментарий:

```dart
/// Позиция в запросе согласования. [id] — стабильный id для new_items (клиент шлёт approved_item_ids по ним).
class ApprovalItem {
  final String name;
  final int priceKopecks;
  final int estimatedMinutes;
  final String? id;
  const ApprovalItem({ required this.name, required this.priceKopecks, this.estimatedMinutes = 60, this.id });
}
```

**Файл:** `autohub_business/lib/features/orders/presentation/screens/confirm_correct_order_screen.dart`

`_newApprovalItems` переписан с генерацией id:

```dart
  List<ApprovalItem> get _newApprovalItems {
    final base = DateTime.now().millisecondsSinceEpoch;
    return _newRows.asMap().entries.map((e) {
      final i = _itemsFromRows([e.value]).first;
      return ApprovalItem(
        name: i.name,
        priceKopecks: i.priceKopecks ?? 0,
        estimatedMinutes: i.estimatedMinutes,
        id: 'new_${base}_${e.key}',
      );
    }).toList();
  }
```

### 5.2 Business: ChatApiService — отправка id в new_items

**Файл:** `autohub_business/lib/core/api/services/chat_api_service.dart`

В маппинге `new_items` добавлена условная передача id:

```dart
          'new_items': (newItems ?? []).map((i) => {
            if (i.id != null && i.id!.isNotEmpty) 'id': i.id!,
            'name': i.name,
            'price_kopecks': i.priceKopecks,
            'estimated_minutes': i.estimatedMinutes,
          }).toList(),
```

### 5.3 Backend: сохранение id из payload для new_items

**Файл:** `backend/src/chats/chats.service.ts`

В блоке обработки approval payload:

```ts
        newItems.forEach((item: any, index: number) => {
          item.id = item.id ?? item.temp_id ?? ('proposed_' + index);
        });
```

### 5.4 Client: ApprovalMessageItem.id, парсинг и использование в карточке

**Файл:** `autohub_client2/lib/shared/models/chat_model.dart`  
В `ApprovalMessageItem` добавлено `final String? id;`.

**Файл:** `autohub_client2/lib/core/repositories/api_chat_repository.dart`  
При разборе approval_items (список и объект edited/new) добавлено: `id: m['id']?.toString()`.

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chat_detail_screen.dart`

- Инициализация fromMessage: `newList.asMap().entries.map((e) => e.value.id ?? 'msg_${e.key}').toSet()`.
- Подсчёт и итоги по доп. работам из сообщения: используется `itemKey(e.value, e.key) == e.value.id ?? 'msg_${e.key}'`.
- Чекбоксы: `_checked.contains(e.value.id ?? 'msg_${e.key}')` и add/remove с тем же ключом.
- В `_handleApproval` при отсутствии доп. работ в заказе: `approvedIds = checkedItemIds.toList()` (вместо `['0']`), чтобы слать реальные id из сообщения.

---

## ШАГ 6 — Системные сообщения (approval, confirm-by-phone, approve)

**Цель:** В тот же chatId пишутся системные сообщения с кратким списком услуг.

### 6.1 Backend: при отправке approval request

**Файл:** `backend/src/chats/chats.service.ts`

- Добавлен приватный метод `approvalItemNames(payload)` — возвращает массив названий из edited_items/new_items (или legacy-массива).
- После сохранения approval-сообщения и вызова `applyApprovalToOrder`:

```ts
      const names = this.approvalItemNames(approvalPayload);
      const namesText = names.length > 3 ? names.slice(0, 3).join(', ') + ` и ещё ${names.length - 3}` : names.join(', ');
      if (namesText) {
        await this.addSystemMessage(chatId, `СТО отправило запрос на согласование работ: ${namesText}`, effectiveOrderId ?? undefined);
      }
```

### 6.2 Backend: confirm-by-phone (approveBySto)

**Файл:** `backend/src/orders/orders.service.ts`

Перед отправкой системного сообщения формируется список добавленных услуг из payload:

```ts
    const chat = await this.chats.getChatByOrderId(orderId);
    if (chat) {
      const payloadObj = payload != null && typeof payload === 'object' && !Array.isArray(payload)
        ? (payload as { new_items?: any[] })
        : null;
      const addedNames = (payloadObj?.new_items ?? []).map((n: any) => n?.name ?? '').filter(Boolean);
      const namesText = addedNames.length > 3
        ? addedNames.slice(0, 3).join(', ') + ` и ещё ${addedNames.length - 3}`
        : addedNames.join(', ');
      const text = namesText
        ? `СТО подтвердило по телефону: ${namesText}. Работы продолжаются.`
        : 'СТО подтвердило изменения по телефону. Работы продолжаются.';
      await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
    }
```

### 6.3 Backend: approve-by-client (две ветки)

**Файл:** `backend/src/orders/orders.service.ts`

- В ветке, где заказ уже имел доп. работы (hasAdditional): системное сообщение с текстом «Клиент подтвердил: …» и списком названий одобренных позиций из заказа (до 3 + «и ещё N»).
- В ветке с approvalItems/itemsWithId: системное сообщение «Клиент подтвердил: …» по названиям из `itemsWithId`, входящим в `approvedSet`.

---

## Список изменённых файлов (проход 2)

| Файл | Изменения |
|------|-----------|
| `backend/src/chats/chats.service.ts` | addSystemMessage; approvalItemNames; после approval — системное «СТО отправило запрос…»; сохранение id из payload для new_items. |
| `backend/src/orders/orders.service.ts` | При создании заказа — addSystemMessage «Клиент создал заявку…»; approveBySto — системное с перечнем услуг; approveByClient — два системных «Клиент подтвердил: …» с перечнем. |
| `autohub_client2/.../chat_detail_screen.dart` | Merge по id в _loadMessages; ключи и approvedIds по item.id в карточке согласования. |
| `autohub_business/lib/core/repositories/chat_repository.dart` | Merge по id в loadMessagesFor. |
| `autohub_business/lib/shared/models/chat_model.dart` | ApprovalItem.id. |
| `autohub_business/lib/features/orders/.../confirm_correct_order_screen.dart` | _newApprovalItems с id. |
| `autohub_business/lib/core/api/services/chat_api_service.dart` | Передача id в new_items. |
| `autohub_client2/lib/shared/models/chat_model.dart` | ApprovalMessageItem.id. |
| `autohub_client2/lib/core/repositories/api_chat_repository.dart` | Парсинг id в approval items. |

---

## Ручная проверка после прохода 2

**ШАГ 3:** Клиент создал заказ → в Business в «Чатах» появился чат по заказу; в чате есть системное сообщение «Клиент создал заявку. Требуется подтверждение/проверка.»

**ШАГ 4:** После approve/confirm-by-phone старые сообщения и «строки/ссылки» в чате не исчезают при обновлении.

**ШАГ 5:** Подтвердить одну добавленную услугу → в логах нет SKIP по new_items → услуга появляется в заказе; approved_item_ids совпадают с id из сообщения.

**ШАГ 6:** После отправки согласования в чате — системное «СТО отправило запрос на согласование работ: …»; после confirm-by-phone — «СТО подтвердило по телефону: …» с перечнем; после approve клиентом — «Клиент подтвердил: …» с перечнем.
