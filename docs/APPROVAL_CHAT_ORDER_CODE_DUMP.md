# Выгрузка кода: чат по заказу, approval request, approved_item_ids

Файл содержит весь код, требуемый для анализа запроса: GET /orders/:id/chat, createForOrder, POST approval, approveByClient, открытие чата в Client/Business, sendApprovalRequest и выбор chatId.

---

## Backend (NestJS)

### 1. GET /orders/:id/chat — контроллер и сервис

**Контроллер:** `backend/src/orders/orders.controller.ts`

```ts
  /** Получить или создать чат по заказу (для СТО: отправка согласования и т.д.). */
  @Get(':id/chat')
  async getChatForOrder(@Param('id') id: string, @Req() req: { user: { organizationId?: string | null } }) {
    const orgId = (req as any).user?.organizationId;
    if (!orgId) throw new Error('Organization required');
    return this.orders.getChatForOrder(id, orgId);
  }
```

**Сервис:** `backend/src/orders/orders.service.ts`

```ts
  /** Получить или создать чат по заказу (для экрана «Подтвердить/скорректировать» в СТО). */
  async getChatForOrder(orderId: string, organizationId: string): Promise<{ chat_id: string }> {
    const order = await this.orderRepo.findOne({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');
    if ((order as any).organizationId !== organizationId) throw new NotFoundException('Order not found');
    const chat = await this.chats.createForOrder(orderId);
    return { chat_id: chat.id };
  }
```

**Как выбирается chat_id:** всегда один и тот же: вызывается `chats.createForOrder(orderId)`, возвращается `chat.id`. Если чатов несколько по заказу — не учитывается: `createForOrder` возвращает один чат (см. ниже). Итог: **в ответе один `chat_id`**.

---

### 2. chats.service.ts: createForOrder — создаёт или getOrCreate?

**Файл:** `backend/src/chats/chats.service.ts`

```ts
  /** При создании заказа: привязываем чат к клиенту и к этому заказу (не создаём новый чат и не создаём новый заказ). */
  async createForOrder(orderId: string): Promise<Chat> {
    const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['organization'] });
    if (!order) throw new Error('order not found');
    const phoneNorm = norm((order as any).clientPhone || '');
    const chat = await this.getOrCreateForClient((order as any).organizationId, (order as any).clientPhone || '');
    const updates: Record<string, unknown> = { orderId };
    if (!(chat as any).organizationId) {
      updates.organizationId = (order as any).organizationId;
      updates.clientPhone = phoneNorm;
    }
    await this.chatRepo.update(chat.id, updates);
    (chat as any).orderId = orderId;
    if (updates.organizationId != null) (chat as any).organizationId = updates.organizationId;
    if (updates.clientPhone != null) (chat as any).clientPhone = updates.clientPhone;
    return chat;
  }
```

**getOrCreateForClient:** `backend/src/chats/chats.service.ts`

```ts
  /** Получить или создать чат по организации и телефону клиента (один чат на клиента в СТО). */
  async getOrCreateForClient(organizationId: string, clientPhoneRaw: string): Promise<Chat> {
    const phoneNorm = norm(clientPhoneRaw);
    if (!phoneNorm) throw new Error('client_phone required');
    let chat = await this.chatRepo.findOne({
      where: { organizationId, clientPhone: phoneNorm },
      relations: ['messages'],
    });
    if (chat) return chat;
    chat = this.chatRepo.create({ organizationId, clientPhone: phoneNorm });
    await this.chatRepo.save(chat);
    return chat;
  }
```

**Итог:** `createForOrder` **не создаёт новый чат**, а вызывает **getOrCreateForClient** (один чат на пару organizationId + clientPhone). Потом делает **update** этого чата: выставляет `orderId` и при необходимости `organizationId`, `clientPhone`. То есть чат **получаем или создаём по клиенту**, затем **привязываем к заказу** через `orderId`.

**Уникальный индекс по orderId:** в сущности Chat его **нет**.

**Сущность Chat:** `backend/src/chats/chat.entity.ts`

```ts
@Entity('chats')
export class Chat {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Legacy: один чат на заказ. Новый формат: чат привязан к клиенту (org + телефон). */
  @Column({ name: 'order_id', nullable: true })
  orderId: string | null;

  @ManyToOne(() => Order, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'order_id' })
  order: Order | null;

  @Column({ name: 'organization_id', type: 'uuid', nullable: true })
  organizationId: string | null;

  @Column({ name: 'client_phone', type: 'varchar', length: 32, nullable: true })
  clientPhone: string | null;

  @OneToMany(() => ChatMessage, (m) => m.chat, { cascade: true })
  messages: ChatMessage[];
}
```

Уникального индекса по `order_id` в entity нет; логика «один чат на клиента в СТО» обеспечивается выборкой по `organizationId` + `clientPhone` и обновлением `orderId` у этого чата.

---

### 3. POST /chats/:chatId/messages (approval request): где order_id, approval_items, что возвращается

**Файл:** `backend/src/chats/chats.service.ts`, метод `sendMessage` (ветка `hasApproval`):

```ts
    if (hasApproval) {
      if (approvalPayload != null && typeof approvalPayload === 'object' && !Array.isArray(approvalPayload)) {
        const obj = approvalPayload as { edited_items?: any[]; new_items?: any[] };
        const newItems = obj.new_items ?? [];
        newItems.forEach((item: any, index: number) => {
          item.id = item.id ?? item.temp_id ?? ('proposed_' + index);
        });
      }
      let effectiveOrderId: string | null = dto.order_id ?? null;
      if (!effectiveOrderId) {
        const chat = await this.chatRepo.findOne({ where: { id: chatId } });
        // ... создание заказа из чата, update chat.orderId = effectiveOrderId
      }
      // ...
      const msg = this.msgRepo.create({
        chatId,
        text: '',
        isFromClient: false,
        approvalItems: approvalPayload,
        approvalStatus: 'pending',
        proposedDateTime: proposedDt,
        orderId: effectiveOrderId,
      } as Partial<ChatMessage>) as ChatMessage;
      const saved = await this.msgRepo.save(msg) as ChatMessage;
      // ...
      return {
        id: saved.id,
        text: saved.text,
        is_from_client: saved.isFromClient,
        at: saved.at.toISOString(),
        approval_items: saved.approvalItems,
        approval_status: saved.approvalStatus,
        proposed_date_time: saved.proposedDateTime ? saved.proposedDateTime.toISOString() : null,
        order_id: saved.orderId ?? effectiveOrderId,
      };
    }
```

**Где сохраняется order_id:** в записи сообщения: `msg.orderId = effectiveOrderId` (поле `order_id` в БД, см. entity ниже).

**Где сохраняется approval_items:** в той же записи: `msg.approvalItems = approvalPayload` (поле `approval_items`, jsonb).

**Что возвращается в ответе:** ключи в snake_case: `order_id`, `approval_items`, а также `approval_status`, `proposed_date_time`, `id`, `text`, `is_from_client`, `at`.

**Сущность ChatMessage:** `backend/src/chats/chat-message.entity.ts`

```ts
  @Column({ name: 'approval_items', type: 'jsonb', nullable: true })
  approvalItems: unknown;

  @Column({ name: 'order_id', type: 'uuid', nullable: true })
  orderId: string | null;
```

---

### 4. approveByClient / applyApprovalDraft: сравнение approved_item_ids с new_items[i].id

**Файл:** `backend/src/orders/orders.service.ts`

**Ветка object format (edited_items + new_items):**

```ts
      const newItems = payloadObj?.new_items ?? [];
      const acceptAllNew = approvedItemIds.length === 1 && String(approvedItemIds[0]) === '0';
      const approvedSet = new Set(approvedItemIds);
      const approvedSetWithMsg = new Set<string>();
      approvedItemIds.forEach((aid) => {
        approvedSetWithMsg.add(aid);
        if (typeof aid === 'string' && aid.startsWith('msg_')) {
          const idx = aid.slice(4);
          if (/^\d+$/.test(idx)) approvedSetWithMsg.add('proposed_' + idx);
        }
      });
      // ...
      let inserted = 0;
      for (let index = 0; index < newItems.length; index++) {
        const n = newItems[index];
        const id = n.id ?? `proposed_${index}`;
        const allowed = acceptAllNew || approvedSet.has(id) || approvedSetWithMsg.has(id);
        if (!allowed) {
          console.log('[approveByClient] SKIP new_items[' + index + '] id=', id, 'not in approved set');
          continue;
        }
        // INSERT в order_item
        const entity = this.itemRepo.create({ orderId, ... });
        await this.itemRepo.save(entity);
        inserted++;
      }
```

**Ветка legacy (один массив approvalItems):**

```ts
    const approvalItems = Array.isArray(payload) ? payload : [];
    const approvedSet = new Set(approvedItemIds);
    const currentItems = ((order as any).items || []).map((i: any) => ({ ... }));
    const itemsWithId = approvalItems.map((i: any, index: number) => ({
      id: (i as any).id ?? `proposed_${index}`,
      name: i.name ?? '',
      price_kopecks: i.price_kopecks ?? i.priceKopecks ?? null,
      estimated_minutes: i.estimated_minutes ?? i.estimatedMinutes ?? 60,
      is_completed: false,
      is_additional: true,
    }));
    const addAllLegacy = approvedItemIds.length === 1 && approvedItemIds[0] === '0' && itemsWithId.length > 1;
    const newItemsFromMessage = addAllLegacy
      ? itemsWithId
      : itemsWithId.filter((item: { id: string }) => approvedSet.has(item.id));
    await this.updateItems(orderId, [...currentItems, ...newItemsFromMessage]);
```

**Итоговая логика:**

- **object format:** для каждого `new_items[i]` берётся `id = n.id ?? 'proposed_' + index`. В выборку попадают элементы, для которых: `acceptAllNew` (approvedItemIds === ['0']) **или** `approvedSet.has(id)` **или** `approvedSetWithMsg.has(id)` (дополнительно маппинг `msg_0` → `proposed_0` и т.д.).
- **legacy:** у каждого элемента из сообщения задаётся `id` как `(i as any).id ?? 'proposed_' + index`; в заказ добавляются либо все (`addAllLegacy`), либо только те, у кого `approvedSet.has(item.id)`.

---

## Client (Flutter)

### 1. Все места, где открывается чат

**Из карточки заказа («Перейти в чат»):** сейчас чат открывается **по orderId** через GET /orders/:orderId/chat (раньше был выбор по `stoId`).

**Файл:** `autohub_client2/lib/features/orders/presentation/screens/order_detail_screen.dart`

```dart
  /// Открыть чат по заказу: GET /orders/:orderId/chat → chat_id, затем открыть тот же chatId, куда Business пишет approval.
  Future<void> _openChat(BuildContext context, WidgetRef ref, Order order) async {
    final orderApi = ref.read(orderApiServiceProvider);
    final chatIdResult = await orderApi.getChatIdForOrder(order.id);
    final resolvedChatId = chatIdResult.dataOrNull;
    if (resolvedChatId == null || resolvedChatId.isEmpty) { ... return; }
    await ref.read(chatsProvider.notifier).loadChats();
    // ...
    final chats = ref.read(chatsProvider).valueOrNull ?? [];
    Chat? chat;
    for (final c in chats) {
      if (c.id == resolvedChatId) { chat = c; break; }
    }
    if (chat == null) {
      chat = Chat(id: resolvedChatId, stoId: order.stoId, orderId: order.id, ...);
    }
    pushCupertino(context, ChatDetailScreen(chat: chat!, currentOrderId: order.id));
  }
```

Вызовы: кнопка «Перейти в чат» и т.п. вызывают `_openChat(context, ref, displayOrder)` / `_openChat(context, ref, order)`.

**Из списка чатов:** чат не ищется по stoId, открывается выбранная карточка.

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chats_screen.dart`

```dart
      onTap: () => pushCupertino(context, ChatDetailScreen(chat: chat)),
```

**Из уведомления:** чат берётся по targetId (getChatById).

**Файл:** `autohub_client2/lib/features/notifications/presentation/screens/notifications_screen.dart`

```dart
      case NotificationTarget.chat:
        if (item.targetId != null) {
          final result = await ref.read(chatRepositoryProvider).getChatById(item.targetId!);
          if (context.mounted && result.dataOrNull != null) {
            pushCupertino(context, ChatDetailScreen(chat: result.dataOrNull!));
          }
        }
```

**Использование stoId в чате (не для выбора чата):** фильтрация заказов по тому же СТО и отображение.

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chat_detail_screen.dart`

```dart
    return orders.where((o) => o.stoId == widget.chat.stoId).toList();
    // ...
    final chatOrders = orders.where((o) => o.stoId == widget.chat.stoId).toList();
```

Раньше при «Перейти в чат» из заказа использовалось `chats.firstWhere((c) => c.stoId == order.stoId)` — первый чат с таким же stoId; это заменено на выбор по orderId через API (см. выше).

---

### 2. _handleApproval: как формируются approvedIds (hasAdditional true/false)

**Файл:** `autohub_client2/lib/features/chats/presentation/screens/chat_detail_screen.dart`

```dart
  Future<void> _handleApproval({required bool approved, required Set<String> checkedItemIds, String? orderId}) async {
    final id = orderId ?? widget.chat.orderId;
    if (id.isEmpty) return;
    final orders = ref.read(ordersProvider).valueOrNull ?? [];
    Order? order;
    final orderIdx = orders.indexWhere((o) => o.id == id);
    if (orderIdx >= 0) order = orders[orderIdx];

    final additionalItems = order?.items.where((i) => i.isAdditional).toList() ?? [];
    final hasAdditional = additionalItems.isNotEmpty;

    List<String> approvedIds;
    List<String> rejectedIds;
    if (!approved) {
      approvedIds = [];
      rejectedIds = [];
    } else {
      approvedIds = hasAdditional
          ? order!.items.where((i) => i.isAdditional && checkedItemIds.contains(i.id)).map((i) => i.id).toList()
          : checkedItemIds.toList(); // id из сообщения (proposed_0, new_xxx) для сопоставления с backend
      rejectedIds = hasAdditional
          ? order!.items.where((i) => i.isAdditional && !checkedItemIds.contains(i.id)).map((i) => i.id).toList()
          : [];
    }

    final ok = await ref.read(ordersProvider.notifier).approveItems(id,
      approvedItemIds: approvedIds,
      rejectedItemIds: rejectedIds,
    );
    // ...
  }
```

**Оба кейса:**

- **hasAdditional == true:** в заказе уже есть доп. работы. `approvedIds` = id тех элементов заказа (`order.items`), у которых `isAdditional` и чей `id` есть в `checkedItemIds`. То есть шлём id из **заказа**.
- **hasAdditional == false:** доп. работ в заказе ещё нет (ожидаем согласование по сообщению). `approvedIds = checkedItemIds.toList()` — шлём ровно те id, которые пользователь отметил в карточке (это id из **сообщения**: `proposed_0`, `new_xxx` и т.д.), backend сопоставляет их с `new_items[i].id`.

---

## Business (Flutter)

### sendApprovalRequest и как выбирается chatId (state.chats vs /orders/:id/chat)

**Кто вызывает sendApprovalRequest:** `ConfirmCorrectOrderScreen._sendToClient()`.

**Файл:** `autohub_business/lib/features/orders/presentation/screens/confirm_correct_order_screen.dart`

```dart
  Future<void> _sendToClient() async {
    // ...
    String? chatId = widget.chatId;
    if (chatId == null || chatId.isEmpty) {
      final chatState = ref.read(chatRepositoryProvider);
      for (final c in chatState.chats) {
        if (c.orderId == widget.orderId) {
          chatId = c.id;
          break;
        }
      }
    }
    if (chatId == null || chatId.isEmpty) {
      final orderApi = ref.read(orderApiServiceProvider);
      final chatResult = await orderApi.getChatForOrder(widget.orderId);
      chatId = chatResult.dataOrNull;
      if (chatId == null || chatId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(...);
        return;
      }
    }
    // ...
    final orderIdResult = await chatRepo.sendApprovalRequest(
      chatId,
      widget.orderId,
      editedItems: ...,
      newItems: ...,
      proposedDateTime: _proposedDateTime,
      isInitialConfirm: false,
    );
```

**Как выбирается chatId (критично при дублях):**

1. Если передан **widget.chatId** (например, открыли из чата или с кнопки «Открыть чат» после GET /orders/:id/chat) — используется он.
2. Иначе ищется чат в **state.chats** по **c.orderId == widget.orderId** (первое совпадение, `break`). При нескольких чатах с одним orderId в state возьмётся первый.
3. Если так не нашли — вызывается **GET /orders/:orderId/chat** и берётся **chatResult.dataOrNull** как chatId.

Итог: при дублях чатов в списке приоритет у **локального** совпадения по orderId; если его нет — используется **канонический** chat_id с бэкенда (GET /orders/:id/chat). Надёжный вариант — всегда брать chatId через getChatForOrder перед отправкой согласования.

**Репозиторий:** `autohub_business/lib/core/repositories/chat_repository.dart`

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
    final result = await _api.sendApprovalRequest(
      chatId,
      orderId,
      editedItems: editedItems,
      newItems: newItems,
      items: items,
      proposedDateTime: proposedDateTime,
    );
    final msg = result.dataOrNull;
    if (msg != null) {
      _replaceMessage(chatId, tempId, msg);
      _updateChatPreview(chatId, previewText, msg.at);
      final effectiveOrderId = msg.orderId ?? orderId;
      return effectiveOrderId.isEmpty ? null : effectiveOrderId;
    }
    _removeMessage(chatId, tempId);
    return null;
  }
```

`sendApprovalRequest` в репозитории только прокидывает переданный **chatId** в API; выбор chatId целиком в `ConfirmCorrectOrderScreen` (логика выше).
