import { BadRequestException, forwardRef, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Repository } from 'typeorm';
import { Chat } from './chat.entity';
import { ChatMessage } from './chat-message.entity';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { Organization } from '../organizations/organization.entity';
import { normalizeOrganizationBusinessKind } from '../organizations/organization-business-kind';
import { OrdersService } from '../orders/orders.service';
import { MediaService } from '../media/media.service';
import { SubscriptionQuotaService } from '../subscriptions/subscription-quota.service';
import { UsersService } from '../users/users.service';

const norm = (s: string) => (s || '').replace(/\D/g, '');

@Injectable()
export class ChatsService {
  constructor(
    @InjectRepository(Chat) private chatRepo: Repository<Chat>,
    @InjectRepository(ChatMessage) private msgRepo: Repository<ChatMessage>,
    @InjectRepository(Order) private orderRepo: Repository<Order>,
    @InjectRepository(OrderItem) private itemRepo: Repository<OrderItem>,
    @InjectRepository(Organization) private orgRepo: Repository<Organization>,
    @Inject(forwardRef(() => OrdersService)) private orders: OrdersService,
    @Inject(forwardRef(() => NotificationsService)) private notifications: NotificationsService,
    private readonly mediaService: MediaService,
    private readonly subscriptionQuota: SubscriptionQuotaService,
    private readonly usersService: UsersService,
  ) {}

  private apiBaseUrl(): string {
    return process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
  }

  /** Доступ к чату: клиент по телефону; СТО по organizationId; чат поддержки — участник по телефону. */
  validateChatAccess(
    chat: Chat,
    userOrgId: string | null,
    userPhoneNorm: string | null,
    asClient: boolean,
  ): void {
    const ord = chat.order as any;
    const chatOrgId = (chat as any).organizationId ?? ord?.organizationId;
    const chatPhone = norm((chat as any).clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : ''));
    if (asClient) {
      const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
      if (!p || p !== chatPhone) throw new NotFoundException('Chat not found');
    } else {
      const isSupportChat = (chat as any).organizationId == null && !!chatPhone;
      if (isSupportChat) {
        const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
        if (!p || p !== chatPhone) throw new NotFoundException('Chat not found');
      } else if (userOrgId == null || userOrgId !== chatOrgId) {
        throw new NotFoundException('Chat not found');
      }
    }
  }

  /** Получить или создать чат по организации и телефону клиента (один общий чат на пару org+client). Единственный источник chatId. */
  /** Чат поддержки: без organization_id, один на номер телефона (клиент или сотрудник СТО). */
  async getOrCreateSupportChat(clientPhoneRaw: string): Promise<Chat> {
    const phoneNorm = norm(clientPhoneRaw);
    if (!phoneNorm) throw new Error('client_phone required');
    let chat = await this.chatRepo.findOne({
      where: { organizationId: IsNull(), clientPhone: phoneNorm },
      relations: ['messages'],
    });
    if (chat) return chat;
    chat = this.chatRepo.create({ organizationId: null, clientPhone: phoneNorm });
    await this.chatRepo.save(chat);
    await this.addSystemMessage(
      chat.id,
      'Добро пожаловать в чат поддержки MP-Servis. Опишите вопрос — оператор ответит в ближайшее время.',
    );
    return (await this.chatRepo.findOne({ where: { id: chat.id }, relations: ['messages'] }))!;
  }

  /** Клиентское приложение: открыть диалог с СТО (org должна существовать). */
  async openOrganizationChatForClient(organizationId: string, clientPhoneRaw: string) {
    const org = await this.orgRepo.findOne({ where: { id: organizationId } });
    if (!org) throw new NotFoundException('Организация не найдена');
    const phoneNorm = norm(clientPhoneRaw);
    if (!phoneNorm) throw new BadRequestException('В профиле не указан телефон');
    const chat = await this.getOrCreateForClient(organizationId, clientPhoneRaw);
    return this.getChatById(chat.id, null, phoneNorm, true);
  }

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

  /** Возвращает общий чат по org+phone. Не перезаписываем lastOrderId — UI не должен воспринимать чат как «привязанный к заказу». */
  async getOrCreateForOrderChat(_orderId: string, organizationId: string, clientPhoneRaw: string): Promise<Chat> {
    return this.getOrCreateForClient(organizationId, clientPhoneRaw);
  }

  /** Найти чат по org+phone (для диагностики foundExistingChat). */
  async findChatByOrgAndPhone(organizationId: string, clientPhoneRaw: string): Promise<Chat | null> {
    const phoneNorm = norm(clientPhoneRaw);
    if (!phoneNorm) return null;
    return this.chatRepo.findOne({ where: { organizationId, clientPhone: phoneNorm } });
  }

  /** Общий чат клиент–СТО для заказа (по org + телефон клиента). */
  async getChatByOrderId(orderId: string): Promise<Chat | null> {
    const order = await this.orderRepo.findOne({ where: { id: orderId } });
    if (!order) return null;
    const orgId = (order as any).organizationId;
    const clientPhone = (order as any).clientPhone;
    if (!orgId || !clientPhone) return null;
    try {
      return await this.getOrCreateForClient(orgId, clientPhone);
    } catch {
      return null;
    }
  }

  /** Краткий список названий услуг из approval payload (для системного сообщения). */
  private approvalItemNames(payload: unknown): string[] {
    if (payload == null) return [];
    if (Array.isArray(payload)) return (payload as any[]).map((i) => i?.name ?? '').filter(Boolean);
    if (typeof payload === 'object' && payload !== null && !Array.isArray(payload)) {
      const o = payload as { edited_items?: any[]; new_items?: any[] };
      const edited = (o.edited_items ?? []).map((i) => i?.name ?? '').filter(Boolean);
      const added = (o.new_items ?? []).map((i) => i?.name ?? '').filter(Boolean);
      return [...edited, ...added];
    }
    return [];
  }

  /** Нормализация approval_items из БД/JSONB (иногда приходит строка). */
  private parseApprovalPayload(raw: unknown): unknown {
    if (raw == null) return null;
    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw);
      } catch {
        return null;
      }
    }
    return raw;
  }

  /** Проверка: есть ли в payload хотя бы одна позиция согласования (legacy массив или объект edited_items/new_items). */
  private hasApprovalContent(payload: unknown): boolean {
    const p = this.parseApprovalPayload(payload);
    if (p == null) return false;
    if (Array.isArray(p)) return p.length > 0;
    if (typeof p === 'object' && p !== null && !Array.isArray(p)) {
      const o = p as { edited_items?: unknown[]; new_items?: unknown[]; editedItems?: unknown[]; newItems?: unknown[] };
      const edited = o.edited_items ?? o.editedItems ?? [];
      const added = o.new_items ?? o.newItems ?? [];
      return (edited.length + added.length) > 0;
    }
    return false;
  }

  /**
   * Сообщение считается актуальным черновиком согласования для заказа:
   * — явный approval_request (в т.ч. только время / пустой diff в JSON — время уже в proposed_date_time и в заказе);
   * — или legacy-сообщение с непустым approval_items.
   */
  private isUsableApprovalMessage(m: ChatMessage): boolean {
    const mt = (m as any).messageType ?? (m as any).message_type;
    if (mt === 'approval_request') return true;
    return this.hasApprovalContent(m.approvalItems);
  }

  /** То же, что getLastApprovalMessageByOrderId: ищем по order_id в сообщении, не по чату. */
  async getLastApprovalMessageForOrder(orderId: string): Promise<ChatMessage | null> {
    return this.getLastApprovalMessageByOrderId(orderId);
  }

  /**
   * Черновик согласования: явный id сообщения с карточки клиента (актуально при нескольких запросах подряд)
   * или последнее сообщение по заказу (fallback для старых клиентов).
   */
  async resolveApprovalMessageForOrder(orderId: string, messageId?: string | null): Promise<ChatMessage | null> {
    const mid = messageId != null ? String(messageId).trim() : '';
    if (!mid) {
      return this.getLastApprovalMessageByOrderId(orderId);
    }
    const m = await this.msgRepo.findOne({ where: { id: mid } });
    if (!m) {
      if (process.env.NODE_ENV === 'development') {
        console.log('[resolveApprovalMessageForOrder] message not found id=%s', mid);
      }
      return null;
    }
    if ((m.orderId ?? '') !== orderId) {
      if (process.env.NODE_ENV === 'development') {
        console.log('[resolveApprovalMessageForOrder] order mismatch msg.orderId=%s expected=%s', m.orderId, orderId);
      }
      return null;
    }
    if (!this.isUsableApprovalMessage(m)) {
      return null;
    }
    const chat = await this.getChatByOrderId(orderId);
    if (!chat || m.chatId !== chat.id) {
      if (process.env.NODE_ENV === 'development') {
        console.log('[resolveApprovalMessageForOrder] chat mismatch msg.chatId=%s orderChatId=%s', m.chatId, chat?.id);
      }
      return null;
    }
    return m;
  }

  /**
   * Последнее сообщение с approval_items по order_id в самом сообщении (для черновика заказа).
   * Используется в GET /orders/:id когда заказ pending_approval и позиции ещё только в чате.
   * Явно по колонке order_id и fallback: поиск по чату (org+clientPhone заказа).
   *
   * Важно: не отбрасывать самое новое сообщение только из‑за пустых edited_items/new_items
   * (например, изменили только время) — иначе выбирается предыдущий запрос согласования и
   * при повторном подтверждении клиентом применяется устаревший diff.
   */
  async getLastApprovalMessageByOrderId(orderId: string): Promise<ChatMessage | null> {
    const list = await this.msgRepo
      .createQueryBuilder('m')
      .where('m.order_id = :orderId', { orderId })
      .andWhere('(m.message_type = :approvalMsgType OR m.approval_items IS NOT NULL)', {
        approvalMsgType: 'approval_request',
      })
      .orderBy('m.at', 'DESC')
      .addOrderBy('m.id', 'DESC')
      .take(120)
      .getMany();
    for (const m of list) {
      if (this.isUsableApprovalMessage(m)) return m;
    }
    if (process.env.NODE_ENV === 'development' && list.length > 0) {
      console.log('[getLastApprovalMessageByOrderId] orderId=%s had %d candidates but none usable', orderId, list.length);
    }
    if (process.env.NODE_ENV === 'development' && list.length === 0) {
      const anyWithOrder = await this.msgRepo.createQueryBuilder('m').where('m.order_id = :orderId', { orderId }).getCount();
      console.log('[getLastApprovalMessageByOrderId] orderId=%s no approval candidates; messages with this order_id: %d', orderId, anyWithOrder);
    }
    // Fallback: через чат заказа — последнее подходящее сообщение с order_id и approval
    const chat = await this.getChatByOrderId(orderId);
    if (!chat) return null;
    const inChat = await this.msgRepo
      .createQueryBuilder('m')
      .where('m.chat_id = :chatId', { chatId: chat.id })
      .andWhere('m.order_id = :orderId', { orderId })
      .andWhere('(m.message_type = :approvalMsgType OR m.approval_items IS NOT NULL)', {
        approvalMsgType: 'approval_request',
      })
      .orderBy('m.at', 'DESC')
      .addOrderBy('m.id', 'DESC')
      .getMany();
    for (const m of inChat) {
      if (this.isUsableApprovalMessage(m)) return m;
    }
    return null;
  }

  /** @deprecated Используйте getOrCreateForOrderChat / getOrCreateForClient. Оставлено для совместимости с getChatByOrderId. */
  async createForOrder(orderId: string): Promise<Chat> {
    const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['organization'] });
    if (!order) throw new NotFoundException('Order not found');
    const orgId = (order as any).organizationId;
    const clientPhoneRaw = (order as any).clientPhone || '';
    return this.getOrCreateForOrderChat(orderId, orgId, clientPhoneRaw);
  }

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

  /** Добавить в чат карточку «Заявка отправлена» (первичная заявка клиента). Без approval_items — клиент не должен видеть кнопки согласования. */
  async addOrderCardMessage(
    chatId: string,
    orderId: string,
    items: { name: string; price_kopecks?: number | null; estimated_minutes?: number }[],
    proposedDateTime?: Date,
  ): Promise<void> {
    const snapshot = items.map((i) => ({
      name: i.name,
      price_kopecks: i.price_kopecks ?? null,
      estimated_minutes: i.estimated_minutes ?? 60,
    }));
    const msg = this.msgRepo.create({
      chatId,
      text: '',
      isFromClient: false,
      isSystem: false,
      orderId,
      messageType: 'booking_card',
      orderItemsSnapshot: snapshot,
      proposedDateTime: proposedDateTime ?? null,
    } as Partial<ChatMessage>) as ChatMessage;
    await this.msgRepo.save(msg);
  }

  async getChats(organizationId: string) {
    const byOrgId = await this.chatRepo.find({
      where: { organizationId },
      relations: ['messages'],
      order: { id: 'ASC' },
    });
    const legacy = await this.chatRepo.find({
      where: { order: { organizationId: organizationId } },
      relations: ['order', 'order.organization', 'messages'],
    });
    const legacyFiltered = legacy.filter((c) => c.order && (c.order as any).organizationId === organizationId);
    for (const c of legacyFiltered) {
      const ord = c.order as any;
      if (!(c as any).organizationId && ord) {
        (c as any).organizationId = ord.organizationId;
        (c as any).clientPhone = norm(ord.clientPhone || '');
        await this.chatRepo.save(c);
      }
    }
    const allChats = [...byOrgId];
    const legacyIds = new Set(allChats.map((c) => c.id));
    for (const c of legacyFiltered) {
      if (!legacyIds.has(c.id)) allChats.push(c);
    }
    const deduped = this.dedupChatsByClient(allChats);
    return this.formatChatsResponse(deduped, organizationId, null, false, false);
  }

  /** Список чатов СТО + чат поддержки по тому же номеру (если есть). */
  async getChatsWithSupportForStaff(organizationId: string, phoneRaw: string) {
    const phoneNorm = norm(phoneRaw);
    const orgPayload = await this.getChats(organizationId);
    if (!phoneNorm) return orgPayload;
    const support = await this.chatRepo.findOne({
      where: { organizationId: IsNull(), clientPhone: phoneNorm },
      relations: ['messages'],
    });
    if (!support) return orgPayload;
    const formattedSupport = await this.formatChatsResponse([support], organizationId, phoneNorm, false, false);
    const item = formattedSupport.items[0];
    const existingIds = new Set(orgPayload.items.map((i: any) => i.id));
    if (existingIds.has(item.id)) return orgPayload;
    return { items: [item, ...orgPayload.items] };
  }

  /** Все чаты поддержки для Control Center. */
  async listSupportChatsForInternal() {
    const chats = await this.chatRepo.find({
      where: { organizationId: IsNull() },
      relations: ['messages'],
      order: { id: 'DESC' },
    });
    return this.formatChatsResponse(chats, null, null, false, true);
  }

  /** Ответ оператора поддержки (internal API). */
  async postInternalSupportOperatorMessage(chatId: string, text: string) {
    const trimmed = (text || '').trim();
    if (!trimmed) throw new BadRequestException('Пустое сообщение');
    const chat = await this.chatRepo.findOne({ where: { id: chatId } });
    if (!chat || chat.organizationId != null) throw new NotFoundException('Чат поддержки не найден');
    const row = this.msgRepo.create({
      chatId,
      text: trimmed,
      isFromClient: false,
      isSystem: false,
      isFromSupportOperator: true,
      supportChannel: null,
      messageType: 'support_operator_reply',
    } as Partial<ChatMessage>) as ChatMessage;
    const m = await this.msgRepo.save(row);
    return {
      id: m.id,
      text: m.text,
      is_from_client: false,
      is_system: false,
      is_from_support_operator: true,
      support_channel: null,
      message_type: 'support_operator_reply',
      at: m.at.toISOString(),
      approval_items: null,
      approval_status: null,
      proposed_date_time: null,
      order_id: null,
    };
  }

  async markInternalSupportChatRead(chatId: string): Promise<void> {
    const chat = await this.chatRepo.findOne({ where: { id: chatId } });
    if (!chat || chat.organizationId != null) throw new NotFoundException('Чат поддержки не найден');
    (chat as any).internalSupportLastReadAt = new Date();
    await this.chatRepo.save(chat);
  }

  /** Один чат по id (GET /chats/:id). СТО — по active organizationId; клиент — по номеру телефона (asClient). */
  /** Для маршрута POST сообщения: проверка типа чата без форматирования. */
  async findChatEntityById(chatId: string): Promise<Chat | null> {
    return this.chatRepo.findOne({ where: { id: chatId } });
  }

  /** Чат с заказом для проверки доступа (legacy clientPhone на order). */
  async findChatForAccess(chatId: string): Promise<Chat | null> {
    return this.chatRepo.findOne({
      where: { id: chatId },
      relations: ['order', 'order.organization'],
    });
  }

  async getChatById(
    chatId: string,
    userOrgId: string | null,
    userPhoneNorm: string | null,
    asClient: boolean,
  ): Promise<{ items: any[] }> {
    const chat = await this.chatRepo.findOne({
      where: { id: chatId },
      relations: ['messages', 'order', 'order.organization'],
    });
    if (!chat) throw new NotFoundException('Chat not found');
    this.validateChatAccess(chat, userOrgId, userPhoneNorm, asClient);
    const formatted = await this.formatChatsResponse(
      [chat],
      userOrgId,
      userPhoneNorm,
      asClient,
      false,
    );
    return formatted;
  }

  /** Чаты клиента по номеру телефона (для Client-приложения) */
  async getChatsForClient(clientPhoneNorm: string) {
    const phoneNorm = clientPhoneNorm.replace(/\D/g, '');
    const byPhone = await this.chatRepo.find({
      where: { clientPhone: phoneNorm },
      relations: ['messages'],
      order: { id: 'ASC' },
    });
    const legacy = await this.chatRepo.find({
      relations: ['order', 'order.organization', 'messages'],
    });
    const legacyFiltered = legacy.filter((c) => {
      const ord = c.order as any;
      const orderPhone = norm(ord?.clientPhone || '');
      return orderPhone && orderPhone === phoneNorm;
    });
    for (const c of legacyFiltered) {
      const ord = c.order as any;
      if (!ord) continue;
      if (!(c as any).organizationId && ord.organizationId) {
        (c as any).organizationId = ord.organizationId;
        (c as any).clientPhone = norm(ord.clientPhone || '');
        await this.chatRepo.save(c);
      }
    }
    const allChats = [...byPhone];
    const seen = new Set(allChats.map((c) => c.id));
    for (const c of legacyFiltered) {
      if (!seen.has(c.id)) { allChats.push(c); seen.add(c.id); }
    }
    const deduped = this.dedupChatsByClient(allChats);
    return this.formatChatsResponse(deduped, null, phoneNorm, true, false);
  }

  /** Один чат на пару (org, phone). При дублях приоритет — канонический чат (organizationId + clientPhone на entity), чтобы совпадал с GET /orders/:id/chat. */
  private dedupChatsByClient(chats: Chat[]): Chat[] {
    const byKey = new Map<string, Chat>();
    for (const c of chats) {
      const ord = c.order as any;
      const orgId = (c as any).organizationId ?? ord?.organizationId ?? '';
      const phone = (c as any).clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : '');
      const key = `${orgId}_${phone}`;
      if (!key) continue;
      const isCanonical = !!(c as any).organizationId && !!(c as any).clientPhone;
      const existing = byKey.get(key);
      if (!existing) {
        byKey.set(key, c);
        continue;
      }
      const existingCanonical = !!(existing as any).organizationId && !!(existing as any).clientPhone;
      if (isCanonical && !existingCanonical) byKey.set(key, c);
      else if (!isCanonical && existingCanonical) { /* keep existing */ }
      else if ((existing.messages?.length ?? 0) < (c.messages?.length ?? 0)) byKey.set(key, c);
    }
    return Array.from(byKey.values());
  }

  private async getLastOrderForChat(chat: Chat, organizationId: string | null, clientPhoneNorm: string | null) {
    const ord = chat.order as any;
    const orgId = (chat as any).organizationId ?? ord?.organizationId;
    const phone = (chat as any).clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : clientPhoneNorm ?? '');
    if (!orgId || !phone) {
      if (chat.order) return chat.order as any;
      return null;
    }
    const orders = await this.orderRepo.find({
      where: { organizationId: orgId } as any,
      relations: ['organization'],
      order: { updatedAt: 'DESC' },
      take: 50,
    });
    const match = orders.find((o) => norm((o as any).clientPhone) === phone);
    return match || null;
  }

  /** Заказ для отображения в чате (превью): lastOrderId или последний заказ клиента. */
  private async getOrderForChat(c: Chat, organizationId: string | null, clientPhoneNorm: string | null) {
    const linkedId = (c as any).lastOrderId;
    if (linkedId) {
      const order = await this.orderRepo.findOne({ where: { id: linkedId }, relations: ['organization'] });
      if (order) return order as any;
    }
    return this.getLastOrderForChat(c, organizationId, clientPhoneNorm);
  }

  /**
   * После ответа клиента по API заказов — закрыть «висящие» approval_request в подсчёте непрочитанного.
   * Иначе computeUnreadForClient вечно считает pending-карточки.
   */
  async markApprovalRequestsResolvedForOrder(
    orderId: string,
    status: 'accepted' | 'rejected' | 'superseded',
  ): Promise<void> {
    await this.msgRepo
      .createQueryBuilder()
      .update(ChatMessage)
      .set({ approvalStatus: status })
      .where('order_id = :oid', { oid: orderId })
      .andWhere('message_type = :mt', { mt: 'approval_request' })
      .andWhere('(approval_status IS NULL OR approval_status = :pending)', { pending: 'pending' })
      .execute();
  }

  private isPendingApproval(msg: ChatMessage): boolean {
    const mt = (msg as any).messageType ?? (msg as any).message_type;
    if (mt !== 'approval_request') return false;
    const st = (msg as any).approvalStatus ?? (msg as any).approval_status;
    return st == null || st === 'pending';
  }

  /** Непрочитанное для клиента: сообщения от СТО после client_last_read_at + карточки согласования, ожидающие ответа клиента. */
  private computeUnreadForClient(chat: Chat, messages: ChatMessage[]): number {
    const raw = (chat as any).clientLastReadAt ?? (chat as any).client_last_read_at;
    const lastRead = raw ? new Date(raw) : new Date(0);
    const sorted = [...messages].sort((a, b) => {
      const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at as any).getTime();
      const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at as any).getTime();
      return ta - tb;
    });
    const pending = sorted.filter((m) => !m.isFromClient && this.isPendingApproval(m));
    const pendingIds = new Set(pending.map((m) => m.id));
    let n = pending.length;
    for (const m of sorted) {
      if (m.isFromClient) continue;
      if (pendingIds.has(m.id)) continue;
      const at = m.at instanceof Date ? m.at : new Date(m.at as any);
      if (at > lastRead) n++;
    }
    return n;
  }

  /** Непрочитанные ответы поддержки для автора обращения (СТО или клиент в чате поддержки). */
  private computeUnreadForSupportParticipant(chat: Chat, messages: ChatMessage[]): number {
    const raw = (chat as any).organizationLastReadAt ?? (chat as any).organization_last_read_at;
    const lastRead = raw ? new Date(raw) : new Date(0);
    const sorted = [...messages].sort((a, b) => {
      const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at as any).getTime();
      const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at as any).getTime();
      return ta - tb;
    });
    let n = 0;
    for (const m of sorted) {
      const at = m.at instanceof Date ? m.at : new Date(m.at as any);
      if (at <= lastRead) continue;
      if (m.isSystem) continue;
      if ((m as any).isFromSupportOperator) {
        n++;
        continue;
      }
      if (!m.isFromClient) n++;
    }
    return n;
  }

  /** Непрочитанные сообщения автора обращения для операторов Control Center. */
  private computeUnreadForInternalSupport(chat: Chat, messages: ChatMessage[]): number {
    const raw = (chat as any).internalSupportLastReadAt ?? (chat as any).internal_support_last_read_at;
    const lastRead = raw ? new Date(raw) : new Date(0);
    const sorted = [...messages].sort((a, b) => {
      const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at as any).getTime();
      const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at as any).getTime();
      return ta - tb;
    });
    let n = 0;
    for (const m of sorted) {
      const at = m.at instanceof Date ? m.at : new Date(m.at as any);
      if (at <= lastRead) continue;
      if (m.isSystem) continue;
      if ((m as any).isFromSupportOperator) continue;
      const ch = (m as any).supportChannel as string | null | undefined;
      if (m.isFromClient || (ch != null && ch !== '')) {
        n++;
        continue;
      }
    }
    return n;
  }

  /** Непрочитанное для СТО: сообщения клиента после organization_last_read_at + карточки заявки (booking_card) после метки. */
  private computeUnreadForOrganization(chat: Chat, messages: ChatMessage[]): number {
    const raw = (chat as any).organizationLastReadAt ?? (chat as any).organization_last_read_at;
    const lastRead = raw ? new Date(raw) : new Date(0);
    const sorted = [...messages].sort((a, b) => {
      const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at as any).getTime();
      const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at as any).getTime();
      return ta - tb;
    });
    let n = 0;
    for (const m of sorted) {
      const at = m.at instanceof Date ? m.at : new Date(m.at as any);
      if (at <= lastRead) continue;
      const mt = (m as any).messageType ?? (m as any).message_type;
      if (m.isFromClient) {
        n++;
        continue;
      }
      if (mt === 'booking_card') n++;
    }
    return n;
  }

  async markChatRead(
    chatId: string,
    userOrgId: string | null,
    userPhoneNorm: string | null,
    asClient: boolean,
  ): Promise<void> {
    const chat = await this.chatRepo.findOne({ where: { id: chatId } });
    if (!chat) throw new NotFoundException('Chat not found');
    const ord = chat.order as any;
    const chatOrgId = (chat as any).organizationId ?? ord?.organizationId;
    const chatPhone = norm((chat as any).clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : ''));
    if (asClient) {
      const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
      if (!p || p !== chatPhone) throw new NotFoundException('Chat not found');
      (chat as any).clientLastReadAt = new Date();
    } else {
      const isSupportChat = (chatOrgId == null || chatOrgId === '') && !!chatPhone;
      if (isSupportChat) {
        const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
        if (!p || p !== chatPhone) throw new NotFoundException('Chat not found');
      } else if (userOrgId == null || userOrgId !== chatOrgId) {
        throw new NotFoundException('Chat not found');
      }
      (chat as any).organizationLastReadAt = new Date();
    }
    await this.chatRepo.save(chat);
  }

  private async formatChatsResponse(
    chats: Chat[],
    organizationId: string | null,
    clientPhoneNorm: string | null,
    forClient: boolean,
    forInternalSupport: boolean,
  ) {
    type Row = {
      c: Chat;
      msgs: ChatMessage[];
      last: ChatMessage | null;
      ord: any;
      rawOrgId: string | null;
      chatPhone: string;
      isSupportChat: boolean;
      primaryRequesterChannel: string | null;
      unreadCount: number;
    };

    const rows: Row[] = await Promise.all(
      chats.map(async (c) => {
        const msgs = c.messages?.length ? [...c.messages] : [];
        const last = msgs.length ? msgs.sort((a, b) => {
          const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at as any).getTime();
          const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at as any).getTime();
          return ta - tb;
        })[msgs.length - 1] : null;
        let ord = await this.getOrderForChat(c, organizationId, clientPhoneNorm);
        if (!ord && c.messages?.length) {
          const msgWithOrder = [...c.messages].reverse().find((m: any) => m.orderId);
          if (msgWithOrder?.orderId) {
            ord = await this.orderRepo.findOne({ where: { id: msgWithOrder.orderId }, relations: ['organization'] }) as any;
          }
        }
        const rawOrgId = ord?.organizationId ?? (c as any).organizationId ?? null;
        const chatPhone = (c as any).clientPhone ?? (ord ? norm((ord as any).clientPhone ?? '') : '');
        const isSupportChat = rawOrgId == null && !!chatPhone;
        if (!(c as any).clientPhone && chatPhone) {
          (c as any).clientPhone = chatPhone;
          await this.chatRepo.save(c).catch(() => {});
        }
        let primaryRequesterChannel: string | null = null;
        if (isSupportChat && msgs.length) {
          const sorted = [...msgs].sort((a, b) => {
            const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at as any).getTime();
            const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at as any).getTime();
            return ta - tb;
          });
          for (let i = sorted.length - 1; i >= 0; i--) {
            const m = sorted[i];
            if (m.isSystem) continue;
            if ((m as any).isFromSupportOperator) continue;
            const ch = (m as any).supportChannel as string | null | undefined;
            if (ch === 'client' || ch === 'business') {
              primaryRequesterChannel = ch;
              break;
            }
            if (m.isFromClient) {
              primaryRequesterChannel = 'client';
              break;
            }
            primaryRequesterChannel = 'business';
            break;
          }
        }
        let unreadCount: number;
        if (forInternalSupport) {
          unreadCount = this.computeUnreadForInternalSupport(c, msgs);
        } else if (forClient) {
          unreadCount = this.computeUnreadForClient(c, msgs);
        } else if (isSupportChat) {
          unreadCount = this.computeUnreadForSupportParticipant(c, msgs);
        } else {
          unreadCount = this.computeUnreadForOrganization(c, msgs);
        }
        return {
          c,
          msgs,
          last,
          ord,
          rawOrgId,
          chatPhone,
          isSupportChat,
          primaryRequesterChannel,
          unreadCount,
        };
      }),
    );

    const orgIds = new Set<string>();
    for (const r of rows) {
      if (!r.isSupportChat && r.rawOrgId) orgIds.add(r.rawOrgId);
    }
    let orgById = new Map<string, Organization>();
    if (orgIds.size > 0) {
      const list = await this.orgRepo.find({ where: { id: In([...orgIds]) } });
      orgById = new Map(list.map((o) => [o.id, o]));
    }

    let clientAvatarByPhoneKey = new Map<string, string | null>();
    if (!forClient) {
      const phoneKeys = new Set<string>();
      for (const r of rows) {
        const pk = this.usersService.clientPhoneMatchKey(String(r.chatPhone || ''));
        if (pk) phoneKeys.add(pk);
      }
      clientAvatarByPhoneKey = await this.usersService.mapClientAvatarUrlsByPhoneKeys(phoneKeys);
    }

    const items = rows.map((r) => {
      const orgFromOrder = r.ord?.organization as Organization | undefined;
      const orgFromDb = r.rawOrgId ? orgById.get(r.rawOrgId) : undefined;
      const org = orgFromOrder ?? orgFromDb;
      const orgName = r.isSupportChat ? 'Поддержка MP-Servis' : ((org as any)?.name ?? '');
      const businessKind = !r.isSupportChat ? normalizeOrganizationBusinessKind((org as any)?.businessKind) : null;
      const photoUrls = org && Array.isArray((org as any).photoUrls) ? ((org as any).photoUrls as string[]) : [];
      const organizationPhotoUrl = !r.isSupportChat && photoUrls.length > 0 ? photoUrls[0] : null;
      const organizationPhone =
        !r.isSupportChat && org ? String((org as any).phone ?? '').trim() || null : null;
      const clientPhoneKey = this.usersService.clientPhoneMatchKey(String(r.chatPhone || ''));
      const clientAvatarUrl =
        !forClient && clientPhoneKey ? clientAvatarByPhoneKey.get(clientPhoneKey) ?? null : null;
      return {
        id: r.c.id,
        order_id: r.ord?.id ?? (r.c as any).lastOrderId ?? '',
        order_number: r.ord?.orderNumber || '',
        order_status: r.ord?.status ?? 'pending_confirmation',
        organization_id: r.isSupportChat ? '' : (r.rawOrgId ?? ''),
        organization_name: orgName,
        organization_photo_url: organizationPhotoUrl,
        organization_phone: organizationPhone,
        client_avatar_url: clientAvatarUrl,
        /** Код вида бизнеса для подписей в клиентском приложении (null — чат поддержки). */
        organization_kind: businessKind,
        /** Дубликат для единообразия с профилем организации (`business_kind`); значение то же, что у organization_kind. */
        business_kind: businessKind,
        car_info: r.ord?.carInfo ?? (r.isSupportChat ? 'Поддержка' : ''),
        is_support_chat: r.isSupportChat,
        primary_requester_channel: r.primaryRequesterChannel,
        car_id: r.ord?.carId ?? '',
        last_message_order_id: r.last?.orderId ?? '',
        client_name: r.ord?.clientName || '',
        client_phone: r.chatPhone,
        last_message_text: r.last?.text || '',
        last_message_at: r.last?.at?.toISOString() || new Date().toISOString(),
        last_message_from_client: r.last?.isFromClient ?? false,
        unread_count: r.unreadCount,
      };
    });
    return { items };
  }

  /** Сообщения чата поддержки для internal API (без JWT клиента/СТО). */
  async getInternalSupportChatMessages(chatId: string) {
    const chat = await this.chatRepo.findOne({ where: { id: chatId } });
    if (!chat || chat.organizationId != null) throw new NotFoundException('Chat not found');
    return this.buildMessagesPayload(chatId, this.apiBaseUrl());
  }

  async getMessagesForParticipant(
    chatId: string,
    userOrgId: string | null,
    userPhoneNorm: string | null,
    asClient: boolean,
  ) {
    const chat = await this.chatRepo.findOne({
      where: { id: chatId },
      relations: ['order', 'order.organization'],
    });
    if (!chat) throw new NotFoundException('Chat not found');
    this.validateChatAccess(chat, userOrgId, userPhoneNorm, asClient);
    return this.buildMessagesPayload(chatId, this.apiBaseUrl());
  }

  private async buildMessagesPayload(chatId: string, baseUrl: string) {
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(chatId);
    if (!isUuid) {
      return { items: [] };
    }
    const list: ChatMessage[] = await this.msgRepo.find({ where: { chatId }, order: { at: 'ASC' } });
    const messageIds = list.map((m) => m.id);
    const attByMsg = await this.mediaService.getChatAttachmentDtosByMessageIds(chatId, messageIds, baseUrl);
    const items = list.map((m: ChatMessage) => ({
      id: m.id,
      text: m.text ?? '',
      at: m.at?.toISOString?.() ?? null,
      is_from_client: !!m.isFromClient,
      is_system: !!(m as any).isSystem,
      is_from_support_operator: !!(m as any).isFromSupportOperator,
      support_channel: (m as any).supportChannel ?? null,
      order_id: m.orderId ?? null,
      message_type: m.messageType ?? null,
      order_items_snapshot: m.orderItemsSnapshot ?? null,
      approval_items: m.approvalItems ?? null,
      approval_status: m.approvalStatus ?? null,
      proposed_date_time: m.proposedDateTime ? m.proposedDateTime.toISOString() : null,
      attachments: attByMsg.get(m.id) ?? [],
    }));
    if (process.env.NODE_ENV === 'development') {
      const last3 = list.slice(-3);
      console.log('[GET /chats/:id/messages] chatId=%s count=%d', chatId, list.length);
      last3.forEach((m, i) => {
        const hasApprovalItems = m.approvalItems != null && (Array.isArray(m.approvalItems) ? (m.approvalItems as any[]).length > 0 : true);
        console.log('  [%d] id=%s order_id=%s hasApprovalItems=%s', i, m.id, m.orderId ?? 'null', hasApprovalItems);
      });
      if (items.length > 0) {
        console.log('[GET /chats/:id/messages] keys(responseObject)=%s', Object.keys(items[0]).join(', '));
      }
    }
    return { items };
  }

  async resolveChatAttachmentLocalPath(
    chatId: string,
    assetId: string,
    userOrgId: string | null,
    userPhoneNorm: string | null,
    asClient: boolean,
  ): Promise<string | null> {
    const chat = await this.chatRepo.findOne({
      where: { id: chatId },
      relations: ['order', 'order.organization'],
    });
    if (!chat) return null;
    try {
      this.validateChatAccess(chat, userOrgId, userPhoneNorm, asClient);
    } catch {
      return null;
    }
    return this.mediaService.getLocalPathForChatAttachment(chatId, assetId);
  }

  async sendMessageWithMedia(
    chatId: string,
    dto: { text?: string },
    files: Express.Multer.File[] | undefined,
    isFromClient: boolean,
    access: { userOrgId: string | null; userPhoneNorm: string | null; asClient: boolean },
    opts?: { supportChannel?: 'client' | 'business' | null; uploadedByUserId?: string | null },
  ) {
    const chat = await this.chatRepo.findOne({
      where: { id: chatId },
      relations: ['order', 'order.organization'],
    });
    if (!chat) throw new NotFoundException('Chat not found');
    this.validateChatAccess(chat, access.userOrgId, access.userPhoneNorm, access.asClient);

    const trimmed = (dto.text ?? '').trim();
    const fileList = files?.filter((f) => f?.buffer?.length) ?? [];
    if (!trimmed && fileList.length === 0) {
      throw new BadRequestException('Нужен текст или хотя бы одно изображение.');
    }

    const orgId = (chat as any).organizationId ?? null;
    if (orgId) {
      await this.subscriptionQuota.assertSubscriptionAllowsWrites(orgId);
      const limits = await this.subscriptionQuota.getLimitsForOrganization(orgId);
      const max = limits.maxChatImagesPerMessage;
      if (max != null && fileList.length > max) {
        throw new BadRequestException(
          `Не более ${max} изображений в одном сообщении по тарифу сервиса (не ограничение аккаунта клиента).`,
        );
      }
    }

    const isSupportChat = chat.organizationId == null && !!(chat as any).clientPhone;
    const supportChannel =
      isSupportChat && isFromClient ? (opts?.supportChannel ?? null) : null;

    const m = this.msgRepo.create({
      chatId,
      text: trimmed,
      isFromClient,
      isSystem: false,
      isFromSupportOperator: false,
      supportChannel,
    } as Partial<ChatMessage>) as ChatMessage;
    await this.msgRepo.save(m);

    try {
      if (fileList.length > 0) {
        await this.mediaService.addImagesToChatMessage({
          messageId: m.id,
          chatId,
          organizationId: orgId,
          files: fileList,
          uploadedByUserId: opts?.uploadedByUserId ?? null,
        });
      }
    } catch (e) {
      await this.msgRepo.delete({ id: m.id });
      throw e;
    }

    const chatRow = await this.chatRepo.findOne({ where: { id: chatId } });
    if (!isFromClient && !(m as any).isSystem && chatRow) {
      const phoneNorm = (chatRow as any)?.clientPhone as string | undefined | null;
      if (phoneNorm) {
        const preview =
          trimmed ||
          (fileList.length ? (fileList.length > 1 ? `${fileList.length} изображения` : 'Изображение') : '');
        const cut = preview.length > 140 ? preview.substring(0, 137) + '…' : preview;
        let chatTitle = 'Сервис';
        if (chatRow.organizationId) {
          const org = await this.orgRepo.findOne({ where: { id: chatRow.organizationId } });
          chatTitle = (org?.name ?? '').trim() || 'Сервис';
        } else {
          chatTitle = 'Поддержка MP-Servis';
        }
        await this.notifications.createOrRefreshChatMessageForClientPhone(phoneNorm, {
          title: chatTitle,
          messageLine: cut,
          payload: {
            chat_id: chatId,
            target_type: 'chat',
            target_id: chatId,
          },
        });
      }
    }

    const baseUrl = this.apiBaseUrl();
    const attMap = await this.mediaService.getChatAttachmentDtosByMessageIds(chatId, [m.id], baseUrl);
    const attachments = attMap.get(m.id) ?? [];

    return {
      id: m.id,
      text: m.text,
      is_from_client: m.isFromClient,
      is_system: !!(m as any).isSystem,
      is_from_support_operator: false,
      support_channel: m.supportChannel ?? null,
      at: m.at.toISOString(),
      approval_items: null,
      approval_status: null,
      proposed_date_time: null,
      order_id: null,
      attachments,
    };
  }

  async sendMessage(
    chatId: string,
    dto: { text?: string; order_id?: string; approval_items?: any; proposed_date_time?: string; is_system?: boolean },
    isFromClient = false,
    opts?: { supportChannel?: 'client' | 'business' | null },
  ) {
    const proposedDt = dto.proposed_date_time ? new Date(dto.proposed_date_time) : null;
    let approvalPayload: unknown = dto.approval_items != null ? dto.approval_items : [];
    const hasApproval = !isFromClient && this.hasApprovalContent(dto.approval_items);

    // Обрабатываем запрос согласования первым: сообщение сохраняем в БД до смены статуса заказа (гарантия появления карточки в чате).
    if (hasApproval) {
      if (process.env.NODE_ENV === 'development') {
        console.log('[POST /chats/:chatId/messages] approval: incoming chatId=%s dto.order_id=%s hasApprovalItems=%s', chatId, dto.order_id ?? 'null', true);
      }
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
        if (!chat) throw new BadRequestException('Чат не найден');
        const organizationId = (chat as any).organizationId;
        const clientPhone = (chat as any).clientPhone;
        if (!organizationId || !clientPhone) throw new BadRequestException('Чат не привязан к организации или клиенту');
        const itemsForNewOrder = Array.isArray(dto.approval_items)
          ? dto.approval_items
          : (dto.approval_items?.new_items ?? []);
        effectiveOrderId = await this.orders.createFromChat(organizationId, clientPhone, itemsForNewOrder, proposedDt ?? undefined);
        await this.chatRepo.update(chatId, { lastOrderId: effectiveOrderId });
      }
      const orderBefore = effectiveOrderId ? await this.orderRepo.findOne({ where: { id: effectiveOrderId } }) : null;
      const previousStatus = orderBefore ? ((orderBefore as any).status as string) : null;

      const msg = this.msgRepo.create({
        chatId,
        text: '',
        isFromClient: false,
        approvalItems: approvalPayload,
        approvalStatus: 'pending',
        proposedDateTime: proposedDt,
        orderId: effectiveOrderId,
        messageType: 'approval_request',
      } as Partial<ChatMessage>) as ChatMessage;
      const saved = await this.msgRepo.save(msg) as ChatMessage;
      if (process.env.NODE_ENV === 'development') {
        console.log('[POST /chats/:chatId/messages] approval saved: savedMessage.id=%s savedMessage.chatId=%s savedMessage.orderId=%s', saved.id, saved.chatId, saved.orderId ?? 'null');
      }
      if (effectiveOrderId) {
        const orderForApproval = await this.orderRepo.findOne({ where: { id: effectiveOrderId }, relations: ['items'] });
        const isNewOrderFromChat = orderForApproval && ((orderForApproval as any).items?.length ?? 0) === 0;
        if (!isNewOrderFromChat) {
          const totalsAfter = approvalPayload != null && typeof approvalPayload === 'object' && !Array.isArray(approvalPayload)
            ? (approvalPayload as { totals_after?: { estimated_minutes?: number; price_kopecks?: number } }).totals_after
            : undefined;
          await this.applyApprovalToOrder(effectiveOrderId, proposedDt ?? undefined, totalsAfter);
        }
      }
      const names = this.approvalItemNames(approvalPayload);
      const namesText = names.length > 3 ? names.slice(0, 3).join(', ') + ` и ещё ${names.length - 3}` : names.join(', ');
      if (namesText) {
        await this.addSystemMessage(chatId, `Сервис отправил запрос на согласование работ: ${namesText}`, effectiveOrderId ?? undefined);
      }
      const chatForNotify = await this.chatRepo.findOne({ where: { id: chatId } });
      const orderForCar = effectiveOrderId ? await this.orderRepo.findOne({ where: { id: effectiveOrderId } }) : null;
      const clientPhoneNorm = (chatForNotify as any)?.clientPhone as string | null | undefined;
      if (clientPhoneNorm && effectiveOrderId) {
        await this.notifications.createForClientPhone(clientPhoneNorm, {
          carId: orderForCar ? ((orderForCar as any).carId as string) : null,
          type: 'order',
          title: 'Ответ по заказу: запрос согласования',
          body: namesText
            ? `СТО предлагает согласовать: ${namesText}`
            : 'Требуется ваше согласование по работам или времени',
          payload: {
            order_id: effectiveOrderId,
            chat_id: chatId,
            target_type: 'order',
            target_id: effectiveOrderId,
          },
        });
      }
      console.log('[approval_request] orderId=' + effectiveOrderId + ', chatId=' + chatId + ', messageId=' + saved.id + ', previousStatus=' + previousStatus + ', nextStatus=pending_approval');
      return {
        id: saved.id,
        text: saved.text,
        is_from_client: saved.isFromClient,
        at: saved.at.toISOString(),
        message_type: 'approval_request',
        approval_items: saved.approvalItems,
        approval_status: saved.approvalStatus,
        proposed_date_time: saved.proposedDateTime ? saved.proposedDateTime.toISOString() : null,
        order_id: saved.orderId ?? effectiveOrderId,
      };
    }

    if (dto.text != null && dto.text !== '') {
      const chatRow = await this.chatRepo.findOne({ where: { id: chatId } });
      const isSupportChat =
        !!chatRow && chatRow.organizationId == null && !!(chatRow as any).clientPhone;
      const supportChannel =
        isSupportChat && isFromClient ? (opts?.supportChannel ?? null) : null;
      const m = this.msgRepo.create({
        chatId,
        text: dto.text,
        isFromClient,
        isSystem: dto.is_system ?? false,
        isFromSupportOperator: false,
        supportChannel,
      } as Partial<ChatMessage>) as ChatMessage;
      await this.msgRepo.save(m);
      if (!isFromClient && !(dto.is_system ?? false) && chatRow) {
        const phoneNorm = (chatRow as any)?.clientPhone as string | undefined | null;
        if (phoneNorm) {
          const t = dto.text!;
          const preview = t.length > 140 ? t.substring(0, 137) + '…' : t;
          let chatTitle = 'Сервис';
          if (chatRow.organizationId) {
            const org = await this.orgRepo.findOne({ where: { id: chatRow.organizationId } });
            chatTitle = (org?.name ?? '').trim() || 'Сервис';
          } else {
            chatTitle = 'Поддержка MP-Servis';
          }
          await this.notifications.createOrRefreshChatMessageForClientPhone(phoneNorm, {
            title: chatTitle,
            messageLine: preview,
            payload: {
              chat_id: chatId,
              target_type: 'chat',
              target_id: chatId,
            },
          });
        }
      }
      return {
        id: m.id,
        text: m.text,
        is_from_client: m.isFromClient,
        is_system: m.isSystem,
        is_from_support_operator: false,
        support_channel: m.supportChannel ?? null,
        at: m.at.toISOString(),
        approval_items: null,
        approval_status: null,
        proposed_date_time: null,
        order_id: null,
      };
    }
    throw new BadRequestException('Нужен текст сообщения или approval_items для запроса согласования.');
  }

  /**
   * При отправке запроса согласования СТО: заказу ставим pending_approval.
   * plannedEndTime считаем по totals_after.estimated_minutes из payload (итог после изменений), иначе по позициям в БД.
   */
  private async applyApprovalToOrder(
    orderId: string,
    proposedDateTime?: Date,
    totalsAfter?: { estimated_minutes?: number; price_kopecks?: number },
  ): Promise<void> {
    const order = await this.orderRepo.findOne({ where: { id: orderId } });
    if (!order) return;
    const status = (order as any).status;
    if (status === 'done' || status === 'cancelled') {
      throw new BadRequestException('Нельзя добавить работы в завершённый заказ. Создайте новый.');
    }
    const updates: Record<string, unknown> = {
      status: 'pending_approval',
      previousStatus: status,
    };
    const startBase = proposedDateTime ?? (order as any).plannedStartTime ?? (order as any).dateTime ?? new Date();
    let totalMin: number;
    if (totalsAfter?.estimated_minutes != null && totalsAfter.estimated_minutes >= 0) {
      totalMin = totalsAfter.estimated_minutes;
    } else {
      const items = await this.itemRepo.find({ where: { orderId } });
      totalMin = items.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
    }
    if (proposedDateTime) {
      updates.dateTime = proposedDateTime;
      updates.plannedStartTime = proposedDateTime;
    } else if ((order as any).plannedStartTime == null) {
      updates.plannedStartTime = startBase;
    }
    updates.plannedEndTime = new Date(new Date(startBase).getTime() + totalMin * 60 * 1000);
    await this.orderRepo.update(orderId, updates);
  }
}
