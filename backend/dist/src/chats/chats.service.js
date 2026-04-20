"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatsService = void 0;
const common_1 = require("@nestjs/common");
const notifications_service_1 = require("../notifications/notifications.service");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const chat_entity_1 = require("./chat.entity");
const chat_message_entity_1 = require("./chat-message.entity");
const order_entity_1 = require("../orders/order.entity");
const order_item_entity_1 = require("../orders/order-item.entity");
const organization_entity_1 = require("../organizations/organization.entity");
const organization_business_kind_1 = require("../organizations/organization-business-kind");
const orders_service_1 = require("../orders/orders.service");
const media_service_1 = require("../media/media.service");
const subscription_quota_service_1 = require("../subscriptions/subscription-quota.service");
const users_service_1 = require("../users/users.service");
const norm = (s) => (s || '').replace(/\D/g, '');
let ChatsService = class ChatsService {
    constructor(chatRepo, msgRepo, orderRepo, itemRepo, orgRepo, orders, notifications, mediaService, subscriptionQuota, usersService) {
        this.chatRepo = chatRepo;
        this.msgRepo = msgRepo;
        this.orderRepo = orderRepo;
        this.itemRepo = itemRepo;
        this.orgRepo = orgRepo;
        this.orders = orders;
        this.notifications = notifications;
        this.mediaService = mediaService;
        this.subscriptionQuota = subscriptionQuota;
        this.usersService = usersService;
    }
    apiBaseUrl() {
        return process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
    }
    validateChatAccess(chat, userOrgId, userPhoneNorm, asClient) {
        const ord = chat.order;
        const chatOrgId = chat.organizationId ?? ord?.organizationId;
        const chatPhone = norm(chat.clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : ''));
        if (asClient) {
            const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
            if (!p || p !== chatPhone)
                throw new common_1.NotFoundException('Chat not found');
        }
        else {
            const isSupportChat = chat.organizationId == null && !!chatPhone;
            if (isSupportChat) {
                const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
                if (!p || p !== chatPhone)
                    throw new common_1.NotFoundException('Chat not found');
            }
            else if (userOrgId == null || userOrgId !== chatOrgId) {
                throw new common_1.NotFoundException('Chat not found');
            }
        }
    }
    async getOrCreateSupportChat(clientPhoneRaw) {
        const phoneNorm = norm(clientPhoneRaw);
        if (!phoneNorm)
            throw new Error('client_phone required');
        let chat = await this.chatRepo.findOne({
            where: { organizationId: (0, typeorm_2.IsNull)(), clientPhone: phoneNorm },
            relations: ['messages'],
        });
        if (chat)
            return chat;
        chat = this.chatRepo.create({ organizationId: null, clientPhone: phoneNorm });
        await this.chatRepo.save(chat);
        await this.addSystemMessage(chat.id, 'Добро пожаловать в чат поддержки MP-Servis. Опишите вопрос — оператор ответит в ближайшее время.');
        return (await this.chatRepo.findOne({ where: { id: chat.id }, relations: ['messages'] }));
    }
    async openOrganizationChatForClient(organizationId, clientPhoneRaw) {
        const org = await this.orgRepo.findOne({ where: { id: organizationId } });
        if (!org)
            throw new common_1.NotFoundException('Организация не найдена');
        const phoneNorm = norm(clientPhoneRaw);
        if (!phoneNorm)
            throw new common_1.BadRequestException('В профиле не указан телефон');
        const chat = await this.getOrCreateForClient(organizationId, clientPhoneRaw);
        return this.getChatById(chat.id, null, phoneNorm, true);
    }
    async getOrCreateForClient(organizationId, clientPhoneRaw) {
        const phoneNorm = norm(clientPhoneRaw);
        if (!phoneNorm)
            throw new Error('client_phone required');
        let chat = await this.chatRepo.findOne({
            where: { organizationId, clientPhone: phoneNorm },
            relations: ['messages'],
        });
        if (chat)
            return chat;
        chat = this.chatRepo.create({ organizationId, clientPhone: phoneNorm });
        await this.chatRepo.save(chat);
        return chat;
    }
    async getOrCreateForOrderChat(_orderId, organizationId, clientPhoneRaw) {
        return this.getOrCreateForClient(organizationId, clientPhoneRaw);
    }
    async findChatByOrgAndPhone(organizationId, clientPhoneRaw) {
        const phoneNorm = norm(clientPhoneRaw);
        if (!phoneNorm)
            return null;
        return this.chatRepo.findOne({ where: { organizationId, clientPhone: phoneNorm } });
    }
    async getChatByOrderId(orderId) {
        const order = await this.orderRepo.findOne({ where: { id: orderId } });
        if (!order)
            return null;
        const orgId = order.organizationId;
        const clientPhone = order.clientPhone;
        if (!orgId || !clientPhone)
            return null;
        try {
            return await this.getOrCreateForClient(orgId, clientPhone);
        }
        catch {
            return null;
        }
    }
    approvalItemNames(payload) {
        if (payload == null)
            return [];
        if (Array.isArray(payload))
            return payload.map((i) => i?.name ?? '').filter(Boolean);
        if (typeof payload === 'object' && payload !== null && !Array.isArray(payload)) {
            const o = payload;
            const edited = (o.edited_items ?? []).map((i) => i?.name ?? '').filter(Boolean);
            const added = (o.new_items ?? []).map((i) => i?.name ?? '').filter(Boolean);
            return [...edited, ...added];
        }
        return [];
    }
    parseApprovalPayload(raw) {
        if (raw == null)
            return null;
        if (typeof raw === 'string') {
            try {
                return JSON.parse(raw);
            }
            catch {
                return null;
            }
        }
        return raw;
    }
    hasApprovalContent(payload) {
        const p = this.parseApprovalPayload(payload);
        if (p == null)
            return false;
        if (Array.isArray(p))
            return p.length > 0;
        if (typeof p === 'object' && p !== null && !Array.isArray(p)) {
            const o = p;
            const edited = o.edited_items ?? o.editedItems ?? [];
            const added = o.new_items ?? o.newItems ?? [];
            return (edited.length + added.length) > 0;
        }
        return false;
    }
    isUsableApprovalMessage(m) {
        const mt = m.messageType ?? m.message_type;
        if (mt === 'approval_request')
            return true;
        return this.hasApprovalContent(m.approvalItems);
    }
    async getLastApprovalMessageForOrder(orderId) {
        return this.getLastApprovalMessageByOrderId(orderId);
    }
    async resolveApprovalMessageForOrder(orderId, messageId) {
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
    async getLastApprovalMessageByOrderId(orderId) {
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
            if (this.isUsableApprovalMessage(m))
                return m;
        }
        if (process.env.NODE_ENV === 'development' && list.length > 0) {
            console.log('[getLastApprovalMessageByOrderId] orderId=%s had %d candidates but none usable', orderId, list.length);
        }
        if (process.env.NODE_ENV === 'development' && list.length === 0) {
            const anyWithOrder = await this.msgRepo.createQueryBuilder('m').where('m.order_id = :orderId', { orderId }).getCount();
            console.log('[getLastApprovalMessageByOrderId] orderId=%s no approval candidates; messages with this order_id: %d', orderId, anyWithOrder);
        }
        const chat = await this.getChatByOrderId(orderId);
        if (!chat)
            return null;
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
            if (this.isUsableApprovalMessage(m))
                return m;
        }
        return null;
    }
    async createForOrder(orderId) {
        const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['organization'] });
        if (!order)
            throw new common_1.NotFoundException('Order not found');
        const orgId = order.organizationId;
        const clientPhoneRaw = order.clientPhone || '';
        return this.getOrCreateForOrderChat(orderId, orgId, clientPhoneRaw);
    }
    async addSystemMessage(chatId, text, orderId) {
        const msg = this.msgRepo.create({
            chatId,
            text,
            isFromClient: false,
            isSystem: true,
            orderId: orderId ?? null,
        });
        await this.msgRepo.save(msg);
        return msg;
    }
    async addOrderCardMessage(chatId, orderId, items, proposedDateTime) {
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
        });
        await this.msgRepo.save(msg);
    }
    async getChats(organizationId) {
        const byOrgId = await this.chatRepo.find({
            where: { organizationId },
            relations: ['messages'],
            order: { id: 'ASC' },
        });
        const legacy = await this.chatRepo.find({
            where: { order: { organizationId: organizationId } },
            relations: ['order', 'order.organization', 'messages'],
        });
        const legacyFiltered = legacy.filter((c) => c.order && c.order.organizationId === organizationId);
        for (const c of legacyFiltered) {
            const ord = c.order;
            if (!c.organizationId && ord) {
                c.organizationId = ord.organizationId;
                c.clientPhone = norm(ord.clientPhone || '');
                await this.chatRepo.save(c);
            }
        }
        const allChats = [...byOrgId];
        const legacyIds = new Set(allChats.map((c) => c.id));
        for (const c of legacyFiltered) {
            if (!legacyIds.has(c.id))
                allChats.push(c);
        }
        const deduped = this.dedupChatsByClient(allChats);
        return this.formatChatsResponse(deduped, organizationId, null, false, false);
    }
    async getChatsWithSupportForStaff(organizationId, phoneRaw) {
        const phoneNorm = norm(phoneRaw);
        const orgPayload = await this.getChats(organizationId);
        if (!phoneNorm)
            return orgPayload;
        const support = await this.chatRepo.findOne({
            where: { organizationId: (0, typeorm_2.IsNull)(), clientPhone: phoneNorm },
            relations: ['messages'],
        });
        if (!support)
            return orgPayload;
        const formattedSupport = await this.formatChatsResponse([support], organizationId, phoneNorm, false, false);
        const item = formattedSupport.items[0];
        const existingIds = new Set(orgPayload.items.map((i) => i.id));
        if (existingIds.has(item.id))
            return orgPayload;
        return { items: [item, ...orgPayload.items] };
    }
    async listSupportChatsForInternal() {
        const chats = await this.chatRepo.find({
            where: { organizationId: (0, typeorm_2.IsNull)() },
            relations: ['messages'],
            order: { id: 'DESC' },
        });
        return this.formatChatsResponse(chats, null, null, false, true);
    }
    async postInternalSupportOperatorMessage(chatId, text) {
        const trimmed = (text || '').trim();
        if (!trimmed)
            throw new common_1.BadRequestException('Пустое сообщение');
        const chat = await this.chatRepo.findOne({ where: { id: chatId } });
        if (!chat || chat.organizationId != null)
            throw new common_1.NotFoundException('Чат поддержки не найден');
        const row = this.msgRepo.create({
            chatId,
            text: trimmed,
            isFromClient: false,
            isSystem: false,
            isFromSupportOperator: true,
            supportChannel: null,
            messageType: 'support_operator_reply',
        });
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
    async markInternalSupportChatRead(chatId) {
        const chat = await this.chatRepo.findOne({ where: { id: chatId } });
        if (!chat || chat.organizationId != null)
            throw new common_1.NotFoundException('Чат поддержки не найден');
        chat.internalSupportLastReadAt = new Date();
        await this.chatRepo.save(chat);
    }
    async findChatEntityById(chatId) {
        return this.chatRepo.findOne({ where: { id: chatId } });
    }
    async findChatForAccess(chatId) {
        return this.chatRepo.findOne({
            where: { id: chatId },
            relations: ['order', 'order.organization'],
        });
    }
    async getChatById(chatId, userOrgId, userPhoneNorm, asClient) {
        const chat = await this.chatRepo.findOne({
            where: { id: chatId },
            relations: ['messages', 'order', 'order.organization'],
        });
        if (!chat)
            throw new common_1.NotFoundException('Chat not found');
        this.validateChatAccess(chat, userOrgId, userPhoneNorm, asClient);
        const formatted = await this.formatChatsResponse([chat], userOrgId, userPhoneNorm, asClient, false);
        return formatted;
    }
    async getChatsForClient(clientPhoneNorm) {
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
            const ord = c.order;
            const orderPhone = norm(ord?.clientPhone || '');
            return orderPhone && orderPhone === phoneNorm;
        });
        for (const c of legacyFiltered) {
            const ord = c.order;
            if (!ord)
                continue;
            if (!c.organizationId && ord.organizationId) {
                c.organizationId = ord.organizationId;
                c.clientPhone = norm(ord.clientPhone || '');
                await this.chatRepo.save(c);
            }
        }
        const allChats = [...byPhone];
        const seen = new Set(allChats.map((c) => c.id));
        for (const c of legacyFiltered) {
            if (!seen.has(c.id)) {
                allChats.push(c);
                seen.add(c.id);
            }
        }
        const deduped = this.dedupChatsByClient(allChats);
        return this.formatChatsResponse(deduped, null, phoneNorm, true, false);
    }
    dedupChatsByClient(chats) {
        const byKey = new Map();
        for (const c of chats) {
            const ord = c.order;
            const orgId = c.organizationId ?? ord?.organizationId ?? '';
            const phone = c.clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : '');
            const key = `${orgId}_${phone}`;
            if (!key)
                continue;
            const isCanonical = !!c.organizationId && !!c.clientPhone;
            const existing = byKey.get(key);
            if (!existing) {
                byKey.set(key, c);
                continue;
            }
            const existingCanonical = !!existing.organizationId && !!existing.clientPhone;
            if (isCanonical && !existingCanonical)
                byKey.set(key, c);
            else if (!isCanonical && existingCanonical) { }
            else if ((existing.messages?.length ?? 0) < (c.messages?.length ?? 0))
                byKey.set(key, c);
        }
        return Array.from(byKey.values());
    }
    async getLastOrderForChat(chat, organizationId, clientPhoneNorm) {
        const ord = chat.order;
        const orgId = chat.organizationId ?? ord?.organizationId;
        const phone = chat.clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : clientPhoneNorm ?? '');
        if (!orgId || !phone) {
            if (chat.order)
                return chat.order;
            return null;
        }
        const orders = await this.orderRepo.find({
            where: { organizationId: orgId },
            relations: ['organization'],
            order: { updatedAt: 'DESC' },
            take: 50,
        });
        const match = orders.find((o) => norm(o.clientPhone) === phone);
        return match || null;
    }
    async getOrderForChat(c, organizationId, clientPhoneNorm) {
        const linkedId = c.lastOrderId;
        if (linkedId) {
            const order = await this.orderRepo.findOne({ where: { id: linkedId }, relations: ['organization'] });
            if (order)
                return order;
        }
        return this.getLastOrderForChat(c, organizationId, clientPhoneNorm);
    }
    async markApprovalRequestsResolvedForOrder(orderId, status) {
        await this.msgRepo
            .createQueryBuilder()
            .update(chat_message_entity_1.ChatMessage)
            .set({ approvalStatus: status })
            .where('order_id = :oid', { oid: orderId })
            .andWhere('message_type = :mt', { mt: 'approval_request' })
            .andWhere('(approval_status IS NULL OR approval_status = :pending)', { pending: 'pending' })
            .execute();
    }
    isPendingApproval(msg) {
        const mt = msg.messageType ?? msg.message_type;
        if (mt !== 'approval_request')
            return false;
        const st = msg.approvalStatus ?? msg.approval_status;
        return st == null || st === 'pending';
    }
    computeUnreadForClient(chat, messages) {
        const raw = chat.clientLastReadAt ?? chat.client_last_read_at;
        const lastRead = raw ? new Date(raw) : new Date(0);
        const sorted = [...messages].sort((a, b) => {
            const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at).getTime();
            const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at).getTime();
            return ta - tb;
        });
        const pending = sorted.filter((m) => !m.isFromClient && this.isPendingApproval(m));
        const pendingIds = new Set(pending.map((m) => m.id));
        let n = pending.length;
        for (const m of sorted) {
            if (m.isFromClient)
                continue;
            if (pendingIds.has(m.id))
                continue;
            const at = m.at instanceof Date ? m.at : new Date(m.at);
            if (at > lastRead)
                n++;
        }
        return n;
    }
    computeUnreadForSupportParticipant(chat, messages) {
        const raw = chat.organizationLastReadAt ?? chat.organization_last_read_at;
        const lastRead = raw ? new Date(raw) : new Date(0);
        const sorted = [...messages].sort((a, b) => {
            const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at).getTime();
            const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at).getTime();
            return ta - tb;
        });
        let n = 0;
        for (const m of sorted) {
            const at = m.at instanceof Date ? m.at : new Date(m.at);
            if (at <= lastRead)
                continue;
            if (m.isSystem)
                continue;
            if (m.isFromSupportOperator) {
                n++;
                continue;
            }
            if (!m.isFromClient)
                n++;
        }
        return n;
    }
    computeUnreadForInternalSupport(chat, messages) {
        const raw = chat.internalSupportLastReadAt ?? chat.internal_support_last_read_at;
        const lastRead = raw ? new Date(raw) : new Date(0);
        const sorted = [...messages].sort((a, b) => {
            const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at).getTime();
            const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at).getTime();
            return ta - tb;
        });
        let n = 0;
        for (const m of sorted) {
            const at = m.at instanceof Date ? m.at : new Date(m.at);
            if (at <= lastRead)
                continue;
            if (m.isSystem)
                continue;
            if (m.isFromSupportOperator)
                continue;
            const ch = m.supportChannel;
            if (m.isFromClient || (ch != null && ch !== '')) {
                n++;
                continue;
            }
        }
        return n;
    }
    computeUnreadForOrganization(chat, messages) {
        const raw = chat.organizationLastReadAt ?? chat.organization_last_read_at;
        const lastRead = raw ? new Date(raw) : new Date(0);
        const sorted = [...messages].sort((a, b) => {
            const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at).getTime();
            const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at).getTime();
            return ta - tb;
        });
        let n = 0;
        for (const m of sorted) {
            const at = m.at instanceof Date ? m.at : new Date(m.at);
            if (at <= lastRead)
                continue;
            const mt = m.messageType ?? m.message_type;
            if (m.isFromClient) {
                n++;
                continue;
            }
            if (mt === 'booking_card')
                n++;
        }
        return n;
    }
    async markChatRead(chatId, userOrgId, userPhoneNorm, asClient) {
        const chat = await this.chatRepo.findOne({ where: { id: chatId } });
        if (!chat)
            throw new common_1.NotFoundException('Chat not found');
        const ord = chat.order;
        const chatOrgId = chat.organizationId ?? ord?.organizationId;
        const chatPhone = norm(chat.clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : ''));
        if (asClient) {
            const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
            if (!p || p !== chatPhone)
                throw new common_1.NotFoundException('Chat not found');
            chat.clientLastReadAt = new Date();
        }
        else {
            const isSupportChat = (chatOrgId == null || chatOrgId === '') && !!chatPhone;
            if (isSupportChat) {
                const p = userPhoneNorm != null ? norm(userPhoneNorm) : '';
                if (!p || p !== chatPhone)
                    throw new common_1.NotFoundException('Chat not found');
            }
            else if (userOrgId == null || userOrgId !== chatOrgId) {
                throw new common_1.NotFoundException('Chat not found');
            }
            chat.organizationLastReadAt = new Date();
        }
        await this.chatRepo.save(chat);
    }
    async formatChatsResponse(chats, organizationId, clientPhoneNorm, forClient, forInternalSupport) {
        const rows = await Promise.all(chats.map(async (c) => {
            const msgs = c.messages?.length ? [...c.messages] : [];
            const last = msgs.length ? msgs.sort((a, b) => {
                const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at).getTime();
                const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at).getTime();
                return ta - tb;
            })[msgs.length - 1] : null;
            let ord = await this.getOrderForChat(c, organizationId, clientPhoneNorm);
            if (!ord && c.messages?.length) {
                const msgWithOrder = [...c.messages].reverse().find((m) => m.orderId);
                if (msgWithOrder?.orderId) {
                    ord = await this.orderRepo.findOne({ where: { id: msgWithOrder.orderId }, relations: ['organization'] });
                }
            }
            const rawOrgId = ord?.organizationId ?? c.organizationId ?? null;
            const chatPhone = c.clientPhone ?? (ord ? norm(ord.clientPhone ?? '') : '');
            const isSupportChat = rawOrgId == null && !!chatPhone;
            if (!c.clientPhone && chatPhone) {
                c.clientPhone = chatPhone;
                await this.chatRepo.save(c).catch(() => { });
            }
            let primaryRequesterChannel = null;
            if (isSupportChat && msgs.length) {
                const sorted = [...msgs].sort((a, b) => {
                    const ta = a.at instanceof Date ? a.at.getTime() : new Date(a.at).getTime();
                    const tb = b.at instanceof Date ? b.at.getTime() : new Date(b.at).getTime();
                    return ta - tb;
                });
                for (let i = sorted.length - 1; i >= 0; i--) {
                    const m = sorted[i];
                    if (m.isSystem)
                        continue;
                    if (m.isFromSupportOperator)
                        continue;
                    const ch = m.supportChannel;
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
            let unreadCount;
            if (forInternalSupport) {
                unreadCount = this.computeUnreadForInternalSupport(c, msgs);
            }
            else if (forClient) {
                unreadCount = this.computeUnreadForClient(c, msgs);
            }
            else if (isSupportChat) {
                unreadCount = this.computeUnreadForSupportParticipant(c, msgs);
            }
            else {
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
        }));
        const orgIds = new Set();
        for (const r of rows) {
            if (!r.isSupportChat && r.rawOrgId)
                orgIds.add(r.rawOrgId);
        }
        let orgById = new Map();
        if (orgIds.size > 0) {
            const list = await this.orgRepo.find({ where: { id: (0, typeorm_2.In)([...orgIds]) } });
            orgById = new Map(list.map((o) => [o.id, o]));
        }
        let clientAvatarByPhoneKey = new Map();
        if (!forClient) {
            const phoneKeys = new Set();
            for (const r of rows) {
                const pk = this.usersService.clientPhoneMatchKey(String(r.chatPhone || ''));
                if (pk)
                    phoneKeys.add(pk);
            }
            clientAvatarByPhoneKey = await this.usersService.mapClientAvatarUrlsByPhoneKeys(phoneKeys);
        }
        const items = rows.map((r) => {
            const orgFromOrder = r.ord?.organization;
            const orgFromDb = r.rawOrgId ? orgById.get(r.rawOrgId) : undefined;
            const org = orgFromOrder ?? orgFromDb;
            const orgName = r.isSupportChat ? 'Поддержка MP-Servis' : (org?.name ?? '');
            const businessKind = !r.isSupportChat ? (0, organization_business_kind_1.normalizeOrganizationBusinessKind)(org?.businessKind) : null;
            const photoUrls = org && Array.isArray(org.photoUrls) ? org.photoUrls : [];
            const organizationPhotoUrl = !r.isSupportChat && photoUrls.length > 0 ? photoUrls[0] : null;
            const organizationPhone = !r.isSupportChat && org ? String(org.phone ?? '').trim() || null : null;
            const clientPhoneKey = this.usersService.clientPhoneMatchKey(String(r.chatPhone || ''));
            const clientAvatarUrl = !forClient && clientPhoneKey ? clientAvatarByPhoneKey.get(clientPhoneKey) ?? null : null;
            return {
                id: r.c.id,
                order_id: r.ord?.id ?? r.c.lastOrderId ?? '',
                order_number: r.ord?.orderNumber || '',
                order_status: r.ord?.status ?? 'pending_confirmation',
                organization_id: r.isSupportChat ? '' : (r.rawOrgId ?? ''),
                organization_name: orgName,
                organization_photo_url: organizationPhotoUrl,
                organization_phone: organizationPhone,
                client_avatar_url: clientAvatarUrl,
                organization_kind: businessKind,
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
    async getInternalSupportChatMessages(chatId) {
        const chat = await this.chatRepo.findOne({ where: { id: chatId } });
        if (!chat || chat.organizationId != null)
            throw new common_1.NotFoundException('Chat not found');
        return this.buildMessagesPayload(chatId, this.apiBaseUrl());
    }
    async getMessagesForParticipant(chatId, userOrgId, userPhoneNorm, asClient) {
        const chat = await this.chatRepo.findOne({
            where: { id: chatId },
            relations: ['order', 'order.organization'],
        });
        if (!chat)
            throw new common_1.NotFoundException('Chat not found');
        this.validateChatAccess(chat, userOrgId, userPhoneNorm, asClient);
        return this.buildMessagesPayload(chatId, this.apiBaseUrl());
    }
    async buildMessagesPayload(chatId, baseUrl) {
        const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(chatId);
        if (!isUuid) {
            return { items: [] };
        }
        const list = await this.msgRepo.find({ where: { chatId }, order: { at: 'ASC' } });
        const messageIds = list.map((m) => m.id);
        const attByMsg = await this.mediaService.getChatAttachmentDtosByMessageIds(chatId, messageIds, baseUrl);
        const items = list.map((m) => ({
            id: m.id,
            text: m.text ?? '',
            at: m.at?.toISOString?.() ?? null,
            is_from_client: !!m.isFromClient,
            is_system: !!m.isSystem,
            is_from_support_operator: !!m.isFromSupportOperator,
            support_channel: m.supportChannel ?? null,
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
                const hasApprovalItems = m.approvalItems != null && (Array.isArray(m.approvalItems) ? m.approvalItems.length > 0 : true);
                console.log('  [%d] id=%s order_id=%s hasApprovalItems=%s', i, m.id, m.orderId ?? 'null', hasApprovalItems);
            });
            if (items.length > 0) {
                console.log('[GET /chats/:id/messages] keys(responseObject)=%s', Object.keys(items[0]).join(', '));
            }
        }
        return { items };
    }
    async resolveChatAttachmentLocalPath(chatId, assetId, userOrgId, userPhoneNorm, asClient) {
        const chat = await this.chatRepo.findOne({
            where: { id: chatId },
            relations: ['order', 'order.organization'],
        });
        if (!chat)
            return null;
        try {
            this.validateChatAccess(chat, userOrgId, userPhoneNorm, asClient);
        }
        catch {
            return null;
        }
        return this.mediaService.getLocalPathForChatAttachment(chatId, assetId);
    }
    async sendMessageWithMedia(chatId, dto, files, isFromClient, access, opts) {
        const chat = await this.chatRepo.findOne({
            where: { id: chatId },
            relations: ['order', 'order.organization'],
        });
        if (!chat)
            throw new common_1.NotFoundException('Chat not found');
        this.validateChatAccess(chat, access.userOrgId, access.userPhoneNorm, access.asClient);
        const trimmed = (dto.text ?? '').trim();
        const fileList = files?.filter((f) => f?.buffer?.length) ?? [];
        if (!trimmed && fileList.length === 0) {
            throw new common_1.BadRequestException('Нужен текст или хотя бы одно изображение.');
        }
        const orgId = chat.organizationId ?? null;
        if (orgId) {
            await this.subscriptionQuota.assertSubscriptionAllowsWrites(orgId);
            const limits = await this.subscriptionQuota.getLimitsForOrganization(orgId);
            const max = limits.maxChatImagesPerMessage;
            if (max != null && fileList.length > max) {
                throw new common_1.BadRequestException(`Не более ${max} изображений в одном сообщении по тарифу сервиса (не ограничение аккаунта клиента).`);
            }
        }
        const isSupportChat = chat.organizationId == null && !!chat.clientPhone;
        const supportChannel = isSupportChat && isFromClient ? (opts?.supportChannel ?? null) : null;
        const m = this.msgRepo.create({
            chatId,
            text: trimmed,
            isFromClient,
            isSystem: false,
            isFromSupportOperator: false,
            supportChannel,
        });
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
        }
        catch (e) {
            await this.msgRepo.delete({ id: m.id });
            throw e;
        }
        const chatRow = await this.chatRepo.findOne({ where: { id: chatId } });
        if (!isFromClient && !m.isSystem && chatRow) {
            const phoneNorm = chatRow?.clientPhone;
            if (phoneNorm) {
                const preview = trimmed ||
                    (fileList.length ? (fileList.length > 1 ? `${fileList.length} изображения` : 'Изображение') : '');
                const cut = preview.length > 140 ? preview.substring(0, 137) + '…' : preview;
                let chatTitle = 'Сервис';
                if (chatRow.organizationId) {
                    const org = await this.orgRepo.findOne({ where: { id: chatRow.organizationId } });
                    chatTitle = (org?.name ?? '').trim() || 'Сервис';
                }
                else {
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
            is_system: !!m.isSystem,
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
    async sendMessage(chatId, dto, isFromClient = false, opts) {
        const proposedDt = dto.proposed_date_time ? new Date(dto.proposed_date_time) : null;
        let approvalPayload = dto.approval_items != null ? dto.approval_items : [];
        const hasApproval = !isFromClient && this.hasApprovalContent(dto.approval_items);
        if (hasApproval) {
            if (process.env.NODE_ENV === 'development') {
                console.log('[POST /chats/:chatId/messages] approval: incoming chatId=%s dto.order_id=%s hasApprovalItems=%s', chatId, dto.order_id ?? 'null', true);
            }
            if (approvalPayload != null && typeof approvalPayload === 'object' && !Array.isArray(approvalPayload)) {
                const obj = approvalPayload;
                const newItems = obj.new_items ?? [];
                newItems.forEach((item, index) => {
                    item.id = item.id ?? item.temp_id ?? ('proposed_' + index);
                });
            }
            let effectiveOrderId = dto.order_id ?? null;
            if (!effectiveOrderId) {
                const chat = await this.chatRepo.findOne({ where: { id: chatId } });
                if (!chat)
                    throw new common_1.BadRequestException('Чат не найден');
                const organizationId = chat.organizationId;
                const clientPhone = chat.clientPhone;
                if (!organizationId || !clientPhone)
                    throw new common_1.BadRequestException('Чат не привязан к организации или клиенту');
                const itemsForNewOrder = Array.isArray(dto.approval_items)
                    ? dto.approval_items
                    : (dto.approval_items?.new_items ?? []);
                effectiveOrderId = await this.orders.createFromChat(organizationId, clientPhone, itemsForNewOrder, proposedDt ?? undefined);
                await this.chatRepo.update(chatId, { lastOrderId: effectiveOrderId });
            }
            const orderBefore = effectiveOrderId ? await this.orderRepo.findOne({ where: { id: effectiveOrderId } }) : null;
            const previousStatus = orderBefore ? orderBefore.status : null;
            const msg = this.msgRepo.create({
                chatId,
                text: '',
                isFromClient: false,
                approvalItems: approvalPayload,
                approvalStatus: 'pending',
                proposedDateTime: proposedDt,
                orderId: effectiveOrderId,
                messageType: 'approval_request',
            });
            const saved = await this.msgRepo.save(msg);
            if (process.env.NODE_ENV === 'development') {
                console.log('[POST /chats/:chatId/messages] approval saved: savedMessage.id=%s savedMessage.chatId=%s savedMessage.orderId=%s', saved.id, saved.chatId, saved.orderId ?? 'null');
            }
            if (effectiveOrderId) {
                const orderForApproval = await this.orderRepo.findOne({ where: { id: effectiveOrderId }, relations: ['items'] });
                const isNewOrderFromChat = orderForApproval && (orderForApproval.items?.length ?? 0) === 0;
                if (!isNewOrderFromChat) {
                    const totalsAfter = approvalPayload != null && typeof approvalPayload === 'object' && !Array.isArray(approvalPayload)
                        ? approvalPayload.totals_after
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
            const clientPhoneNorm = chatForNotify?.clientPhone;
            if (clientPhoneNorm && effectiveOrderId) {
                await this.notifications.createForClientPhone(clientPhoneNorm, {
                    carId: orderForCar ? orderForCar.carId : null,
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
            const isSupportChat = !!chatRow && chatRow.organizationId == null && !!chatRow.clientPhone;
            const supportChannel = isSupportChat && isFromClient ? (opts?.supportChannel ?? null) : null;
            const m = this.msgRepo.create({
                chatId,
                text: dto.text,
                isFromClient,
                isSystem: dto.is_system ?? false,
                isFromSupportOperator: false,
                supportChannel,
            });
            await this.msgRepo.save(m);
            if (!isFromClient && !(dto.is_system ?? false) && chatRow) {
                const phoneNorm = chatRow?.clientPhone;
                if (phoneNorm) {
                    const t = dto.text;
                    const preview = t.length > 140 ? t.substring(0, 137) + '…' : t;
                    let chatTitle = 'Сервис';
                    if (chatRow.organizationId) {
                        const org = await this.orgRepo.findOne({ where: { id: chatRow.organizationId } });
                        chatTitle = (org?.name ?? '').trim() || 'Сервис';
                    }
                    else {
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
        throw new common_1.BadRequestException('Нужен текст сообщения или approval_items для запроса согласования.');
    }
    async applyApprovalToOrder(orderId, proposedDateTime, totalsAfter) {
        const order = await this.orderRepo.findOne({ where: { id: orderId } });
        if (!order)
            return;
        const status = order.status;
        if (status === 'done' || status === 'cancelled') {
            throw new common_1.BadRequestException('Нельзя добавить работы в завершённый заказ. Создайте новый.');
        }
        const updates = {
            status: 'pending_approval',
            previousStatus: status,
        };
        const startBase = proposedDateTime ?? order.plannedStartTime ?? order.dateTime ?? new Date();
        let totalMin;
        if (totalsAfter?.estimated_minutes != null && totalsAfter.estimated_minutes >= 0) {
            totalMin = totalsAfter.estimated_minutes;
        }
        else {
            const items = await this.itemRepo.find({ where: { orderId } });
            totalMin = items.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
        }
        if (proposedDateTime) {
            updates.dateTime = proposedDateTime;
            updates.plannedStartTime = proposedDateTime;
        }
        else if (order.plannedStartTime == null) {
            updates.plannedStartTime = startBase;
        }
        updates.plannedEndTime = new Date(new Date(startBase).getTime() + totalMin * 60 * 1000);
        await this.orderRepo.update(orderId, updates);
    }
};
exports.ChatsService = ChatsService;
exports.ChatsService = ChatsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(chat_entity_1.Chat)),
    __param(1, (0, typeorm_1.InjectRepository)(chat_message_entity_1.ChatMessage)),
    __param(2, (0, typeorm_1.InjectRepository)(order_entity_1.Order)),
    __param(3, (0, typeorm_1.InjectRepository)(order_item_entity_1.OrderItem)),
    __param(4, (0, typeorm_1.InjectRepository)(organization_entity_1.Organization)),
    __param(5, (0, common_1.Inject)((0, common_1.forwardRef)(() => orders_service_1.OrdersService))),
    __param(6, (0, common_1.Inject)((0, common_1.forwardRef)(() => notifications_service_1.NotificationsService))),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        orders_service_1.OrdersService,
        notifications_service_1.NotificationsService,
        media_service_1.MediaService,
        subscription_quota_service_1.SubscriptionQuotaService,
        users_service_1.UsersService])
], ChatsService);
//# sourceMappingURL=chats.service.js.map