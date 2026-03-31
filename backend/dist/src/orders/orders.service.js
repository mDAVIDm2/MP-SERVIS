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
exports.OrdersService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const typeorm_3 = require("typeorm");
const fs = require("fs");
const path = require("path");
const order_entity_1 = require("./order.entity");
const order_item_entity_1 = require("./order-item.entity");
const order_photo_entity_1 = require("./order-photo.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const chats_service_1 = require("../chats/chats.service");
const chat_entity_1 = require("../chats/chat.entity");
const chat_message_entity_1 = require("../chats/chat-message.entity");
const notifications_service_1 = require("../notifications/notifications.service");
const organizations_service_1 = require("../organizations/organizations.service");
const subscription_quota_service_1 = require("../subscriptions/subscription-quota.service");
const media_service_1 = require("../media/media.service");
const organization_business_kind_1 = require("../organizations/organization-business-kind");
const organization_scheduling_1 = require("../organizations/organization-scheduling");
const bay_settings_util_1 = require("../organizations/bay-settings.util");
const UPLOADS_DIR = path.join(process.cwd(), 'uploads', 'order-photos');
let OrdersService = class OrdersService {
    constructor(orderRepo, itemRepo, photoRepo, staffRepo, chatRepo, chatMsgRepo, chats, notifications, orgService, subscriptionQuota, mediaService) {
        this.orderRepo = orderRepo;
        this.itemRepo = itemRepo;
        this.photoRepo = photoRepo;
        this.staffRepo = staffRepo;
        this.chatRepo = chatRepo;
        this.chatMsgRepo = chatMsgRepo;
        this.chats = chats;
        this.notifications = notifications;
        this.orgService = orgService;
        this.subscriptionQuota = subscriptionQuota;
        this.mediaService = mediaService;
    }
    async assertOrderMediaAttachmentLimit(orderId, organizationId) {
        const limits = await this.subscriptionQuota.getLimitsForOrganization(organizationId);
        const max = limits.maxOrderMediaAttachments;
        if (max == null)
            return;
        const [modern, legacy] = await Promise.all([
            this.mediaService.countOrderMediaLinks(orderId),
            this.photoRepo.count({ where: { orderId } }),
        ]);
        if (modern + legacy >= max) {
            throw new common_1.BadRequestException(`Достигнут лимит вложений к заказу по тарифу (${max}). Удалите файлы или смените тариф.`);
        }
    }
    async mergeFirstBillingConfirmation(order, previousStatus, updates) {
        const nextStatus = updates.status !== undefined ? String(updates.status) : previousStatus;
        if (order.firstConfirmedAt) {
            return updates;
        }
        const leavesPendingConfirmation = previousStatus === 'pending_confirmation' &&
            (nextStatus === 'confirmed' || nextStatus === 'in_progress');
        if (!leavesPendingConfirmation) {
            return updates;
        }
        await this.subscriptionQuota.assertCanConsumeConfirmedOrderSlot(order.organizationId);
        return { ...updates, firstConfirmedAt: new Date() };
    }
    async findAll(organizationId) {
        const orders = await this.orderRepo.find({
            where: { organizationId },
            relations: ['items', 'master', 'organization'],
            order: { dateTime: 'DESC' },
        });
        const bayCache = new Map();
        const items = await Promise.all(orders.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache)));
        return { items };
    }
    async findAllForInternal(limit = 200, offset = 0) {
        const [orders, total] = await this.orderRepo.findAndCount({
            relations: ['items', 'master', 'organization'],
            order: { dateTime: 'DESC' },
            take: limit,
            skip: offset,
        });
        const bayCache = new Map();
        const items = await Promise.all(orders.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache)));
        return { items, total };
    }
    async findForClient(clientPhoneNorm) {
        const norm = this.normalizePhoneForCompare(clientPhoneNorm);
        const digitsExpr = "REGEXP_REPLACE(COALESCE(order.client_phone, ''), '\\D', '', 'g')";
        const normalizedExpr = `CASE WHEN LENGTH(${digitsExpr}) = 11 AND LEFT(${digitsExpr}, 1) = '8' THEN '7' || SUBSTRING(${digitsExpr} FROM 2) ELSE ${digitsExpr} END`;
        const orders = await this.orderRepo
            .createQueryBuilder('order')
            .leftJoinAndSelect('order.items', 'items')
            .leftJoinAndSelect('order.master', 'master')
            .leftJoinAndSelect('order.organization', 'organization')
            .where(`${normalizedExpr} = :phone`, { phone: norm })
            .orderBy('order.date_time', 'DESC')
            .getMany();
        const bayCache = new Map();
        const items = await Promise.all(orders.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache)));
        return { items };
    }
    async findOne(id) {
        const o = await this.orderRepo.findOne({ where: { id }, relations: ['items', 'master', 'organization'] });
        if (!o)
            return null;
        return this.toOrderJsonWithApprovalPreview(o, new Map());
    }
    async createFromChat(organizationId, clientPhone, approvalItems, proposedDateTime) {
        const norm = this.normalizePhoneForCompare(clientPhone);
        const recentOrders = await this.orderRepo.find({
            where: { organizationId },
            order: { updatedAt: 'DESC' },
            take: 50,
        });
        const lastOrder = recentOrders.find((o) => this.normalizePhoneForCompare(o.clientPhone || '') === norm) ?? null;
        const orderNumber = await this.nextOrderNumber(organizationId);
        const dateTime = proposedDateTime ?? new Date();
        const totalMin = approvalItems.reduce((s, i) => s + (Number(i.estimated_minutes) ?? Number(i.estimatedMinutes) ?? 60), 0);
        const plannedEndTime = new Date(dateTime.getTime() + totalMin * 60 * 1000);
        const order = this.orderRepo.create({
            organizationId,
            orderNumber,
            carId: lastOrder?.carId ?? 'unknown',
            carInfo: lastOrder?.carInfo ?? '',
            vin: lastOrder?.vin ?? null,
            licensePlate: lastOrder?.licensePlate ?? null,
            bodyType: lastOrder?.bodyType ?? null,
            color: lastOrder?.color ?? null,
            mileage: lastOrder?.mileage ?? null,
            engineType: lastOrder?.engineType ?? null,
            clientName: lastOrder?.clientName ?? null,
            clientPhone,
            status: 'pending_confirmation',
            previousStatus: null,
            dateTime,
            plannedStartTime: dateTime,
            plannedEndTime,
            comment: null,
            masterId: null,
        });
        const maxSaveRetries = 5;
        for (let attempt = 0; attempt < maxSaveRetries; attempt++) {
            try {
                await this.orderRepo.save(order);
                return order.id;
            }
            catch (e) {
                const isUniqueError = e instanceof typeorm_3.QueryFailedError && e.code === '23505';
                if (isUniqueError && attempt < maxSaveRetries - 1) {
                    order.orderNumber = await this.nextOrderNumber(organizationId);
                    continue;
                }
                throw e;
            }
        }
        return order.id;
    }
    async nextOrderNumber(organizationId, maxRetries = 5) {
        for (let attempt = 0; attempt < maxRetries; attempt++) {
            const num = await this.orderRepo.count({ where: { organizationId } });
            const orderNumber = '#2024-' + String(num + 1).padStart(3, '0');
            const exists = await this.orderRepo.findOne({ where: { orderNumber }, select: ['id'] });
            if (!exists)
                return orderNumber;
        }
        return '#2024-' + String(Date.now()).slice(-6);
    }
    async create(organizationId, dto) {
        const dateTime = new Date(dto.date_time);
        const itemDtos = Array.isArray(dto.items) ? dto.items : [];
        const totalMinutes = itemDtos.reduce((sum, i) => sum + (Number(i.estimated_minutes) ?? Number(i.estimatedMinutes) ?? 60), 0);
        const plannedEndTime = new Date(dateTime.getTime() + totalMinutes * 60 * 1000);
        const baseOverlap = this.orderRepo
            .createQueryBuilder('order')
            .where('order.organization_id = :orgId', { orgId: organizationId })
            .andWhere('order.status NOT IN (:...excluded)', { excluded: ['cancelled', 'done'] })
            .andWhere('COALESCE(order.planned_start_time, order.date_time) < :newEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :newStart', { newStart: dateTime.toISOString(), newEnd: plannedEndTime.toISOString() });
        const orgRow = await this.orgService.findOne(organizationId);
        const schedMode = (0, organization_scheduling_1.normalizeSchedulingMode)(orgRow?.schedulingMode);
        const settings = (await this.orgService.getSettings(organizationId));
        const slotsBlock = settings?.slots;
        const bays = (0, bay_settings_util_1.normalizeOrgBays)(slotsBlock);
        const bayCount = (0, bay_settings_util_1.effectiveBayCountFromSlots)(slotsBlock);
        let resolvedBayId = dto.bay_id != null && String(dto.bay_id).trim() !== '' ? String(dto.bay_id).trim() : null;
        if (schedMode === 'bay_based') {
            if (bays.length > 0) {
                if (resolvedBayId) {
                    if (!bays.some((b) => b.id === resolvedBayId)) {
                        throw new common_1.BadRequestException('Указан неизвестный пост.');
                    }
                    const overlappingBay = await baseOverlap.clone().andWhere('order.bay_id = :bid', { bid: resolvedBayId }).getCount();
                    if (overlappingBay > 0) {
                        throw new common_1.BadRequestException('Этот пост занят в выбранное время.');
                    }
                }
                else {
                    resolvedBayId = null;
                    for (const b of bays) {
                        const c = await baseOverlap.clone().andWhere('order.bay_id = :bid', { bid: b.id }).getCount();
                        if (c === 0) {
                            resolvedBayId = b.id;
                            break;
                        }
                    }
                    if (!resolvedBayId) {
                        throw new common_1.BadRequestException('Все посты заняты в это время. Выберите другое время.');
                    }
                }
            }
            else {
                resolvedBayId = null;
                const overlappingCount = await baseOverlap.getCount();
                if (overlappingCount >= bayCount) {
                    throw new common_1.BadRequestException('Все посты заняты в это время. Выберите другое время.');
                }
            }
        }
        else {
            resolvedBayId = null;
        }
        if (dto.master_id) {
            const overlapping = await baseOverlap.clone().andWhere('order.master_id = :masterId', { masterId: dto.master_id }).getCount();
            if (overlapping > 0) {
                throw new common_1.BadRequestException('Мастер уже занят в это время. Выберите другое время.');
            }
        }
        else if (schedMode !== 'bay_based') {
            const overlappingCount = await baseOverlap.getCount();
            const solo = await this.subscriptionQuota.isSoloPlan(organizationId);
            if (solo) {
                if (overlappingCount >= 1) {
                    throw new common_1.BadRequestException('Нет свободных слотов в это время. Выберите другое время.');
                }
            }
            else {
                const mastersCount = await this.staffRepo.count({
                    where: { organizationId, role: 'master', isActive: true },
                });
                if (mastersCount === 0 || overlappingCount >= mastersCount) {
                    throw new common_1.BadRequestException('Нет свободных мастеров в это время. Выберите другое время.');
                }
            }
        }
        const orderNumber = await this.nextOrderNumber(organizationId);
        const order = this.orderRepo.create({
            organizationId,
            orderNumber,
            carId: dto.car_id || 'unknown',
            carInfo: dto.car_info || '',
            vin: dto.vin ?? null,
            licensePlate: dto.license_plate ?? null,
            bodyType: dto.body_type ?? null,
            color: dto.color ?? null,
            mileage: dto.mileage != null ? Number(dto.mileage) : null,
            engineType: dto.engine_type ?? null,
            clientName: dto.client_name,
            clientPhone: dto.client_phone,
            status: 'pending_confirmation',
            dateTime,
            plannedStartTime: dateTime,
            plannedEndTime,
            comment: dto.comment,
            masterId: dto.master_id ?? null,
            bayId: resolvedBayId,
        });
        const maxSaveRetries = 5;
        for (let attempt = 0; attempt < maxSaveRetries; attempt++) {
            try {
                await this.orderRepo.save(order);
                break;
            }
            catch (e) {
                const isUniqueError = e instanceof typeorm_3.QueryFailedError && e.code === '23505';
                if (isUniqueError && attempt < maxSaveRetries - 1) {
                    order.orderNumber = await this.nextOrderNumber(organizationId);
                    continue;
                }
                throw e;
            }
        }
        for (const i of itemDtos) {
            const item = this.itemRepo.create({
                orderId: order.id,
                name: i.name,
                priceKopecks: i.price_kopecks ?? null,
                estimatedMinutes: i.estimated_minutes ?? 60,
            });
            await this.itemRepo.save(item);
        }
        const chat = await this.chats.createForOrder(order.id);
        await this.chats.addSystemMessage(chat.id, 'Клиент создал заявку. Требуется подтверждение/проверка.', order.id);
        const itemsForCard = itemDtos.map((i) => ({
            name: i.name ?? '',
            price_kopecks: i.price_kopecks ?? null,
            estimated_minutes: i.estimated_minutes ?? 60,
        }));
        await this.chats.addOrderCardMessage(chat.id, order.id, itemsForCard, order.dateTime);
        return this.findOne(order.id);
    }
    async updateStatus(id, status) {
        const order = await this.orderRepo.findOne({ where: { id } });
        if (!order)
            return null;
        const current = order.status;
        if (status === 'in_progress' && current === 'pending_approval') {
            throw new common_1.BadRequestException('Нельзя перевести в работу: ожидается подтверждение клиента');
        }
        const updates = { status: status };
        if (status === 'in_progress' && !order.actualStartTime) {
            updates.actualStartTime = new Date();
        }
        if ((status === 'completed' || status === 'done') && !order.actualEndTime) {
            updates.actualEndTime = new Date();
        }
        const merged = await this.mergeFirstBillingConfirmation(order, current, updates);
        await this.orderRepo.update(id, merged);
        await this.notifyClientOrderIfNeeded(order, current, status);
        return this.findOne(id);
    }
    async notifyClientOrderIfNeeded(order, previousStatus, newStatus) {
        if (newStatus === previousStatus)
            return;
        const phone = this.normalizePhoneForCompare(order.clientPhone || '');
        if (!phone)
            return;
        const interesting = new Set([
            'confirmed',
            'pending_confirmation',
            'in_progress',
            'completed',
            'done',
            'cancelled',
        ]);
        if (!interesting.has(newStatus))
            return;
        const titles = {
            confirmed: 'Заказ подтверждён',
            pending_confirmation: 'Требуется подтверждение записи',
            in_progress: 'Работы по заказу начались',
            completed: 'Заказ выполнен',
            done: 'Заказ выполнен',
            cancelled: 'Заказ отменён',
        };
        const title = titles[newStatus] || 'Обновление заказа';
        const num = order.orderNumber || '';
        await this.notifications.createForClientPhone(phone, {
            carId: order.carId,
            type: 'order',
            title,
            body: num ? `Заказ №${num}` : undefined,
            payload: {
                order_id: order.id,
                target_type: 'order',
                target_id: order.id,
            },
        });
    }
    async updateTime(id, dto) {
        const order = await this.orderRepo.findOne({ where: { id } });
        if (!order)
            return null;
        const updates = {};
        if (dto.planned_start_time != null)
            updates.plannedStartTime = new Date(dto.planned_start_time);
        if (dto.planned_end_time != null)
            updates.plannedEndTime = new Date(dto.planned_end_time);
        if (Object.keys(updates).length === 0)
            return this.findOne(id);
        await this.orderRepo.update(id, updates);
        return this.findOne(id);
    }
    normalizePhoneForCompare(phone) {
        const digits = String(phone || '').replace(/\D/g, '');
        if (digits.length === 11 && digits.startsWith('8'))
            return '7' + digits.slice(1);
        return digits;
    }
    buildClientApprovalAppliedDisplayNames(edited, newItems, approvedItemIds) {
        const acceptAllNew = approvedItemIds.length === 1 && String(approvedItemIds[0]) === '0';
        const approvedSet = new Set(approvedItemIds.map((x) => String(x)));
        const approvedSetWithMsg = new Set();
        approvedItemIds.forEach((aid) => {
            const a = String(aid);
            approvedSetWithMsg.add(a);
            if (a.startsWith('msg_')) {
                const idx = a.slice(4);
                if (/^\d+$/.test(idx))
                    approvedSetWithMsg.add('proposed_' + idx);
            }
        });
        const names = [];
        for (const e of edited) {
            const nm = String(e?.name ?? '').trim();
            if (nm)
                names.push(nm);
        }
        for (let index = 0; index < newItems.length; index++) {
            const n = newItems[index];
            const id = n?.id != null ? String(n.id) : `proposed_${index}`;
            const allowed = acceptAllNew ||
                approvedSet.has(id) ||
                approvedSetWithMsg.has(id);
            if (!allowed)
                continue;
            const nm = String(n?.name ?? '').trim();
            if (nm)
                names.push(nm);
        }
        return names;
    }
    async applyClientTimeConfirmAfterApproval(orderId, newDateTime, acceptProposed) {
        const updates = {};
        if (newDateTime) {
            const dt = new Date(newDateTime);
            updates.dateTime = dt;
            const items = await this.itemRepo.find({ where: { orderId } });
            const totalMin = items.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
            updates.plannedStartTime = dt;
            updates.plannedEndTime = new Date(dt.getTime() + totalMin * 60 * 1000);
        }
        if (acceptProposed === false && newDateTime) {
            updates.status = 'pending_confirmation';
        }
        if (Object.keys(updates).length > 0) {
            await this.orderRepo.update(orderId, updates);
        }
        if (newDateTime) {
            const chat = await this.chats.getChatByOrderId(orderId);
            if (chat) {
                const dt = new Date(newDateTime);
                const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
                const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
                const text = acceptProposed !== false
                    ? `Клиент подтвердил запись на ${dateStr} в ${timeStr}.`
                    : `Клиент перенёс время на ${dateStr} в ${timeStr}.`;
                await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
            }
        }
        return this.findOne(orderId);
    }
    async confirmByClient(orderId, clientPhoneNorm, newDateTime, acceptProposed, approvalMessageId) {
        const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['items'] });
        if (!order)
            return null;
        const orderPhone = this.normalizePhoneForCompare(order.clientPhone);
        const userPhone = this.normalizePhoneForCompare(clientPhoneNorm);
        if (orderPhone !== userPhone)
            return null;
        const status = order.status;
        if (status === 'confirmed' || status === 'in_progress') {
            return this.applyClientTimeConfirmAfterApproval(orderId, newDateTime, acceptProposed);
        }
        if (status !== 'pending_confirmation' && status !== 'pending_approval')
            return null;
        if (status === 'pending_confirmation' && (order.items?.length ?? 0) === 0) {
            const approvalMsg = await this.chats.getLastApprovalMessageForOrder(orderId);
            if (approvalMsg?.approvalItems) {
                let payload = approvalMsg.approvalItems;
                if (typeof payload === 'string') {
                    try {
                        payload = JSON.parse(payload);
                    }
                    catch {
                        payload = null;
                    }
                }
                const newItems = (Array.isArray(payload) ? payload : (payload?.new_items ?? payload?.newItems ?? []));
                for (const n of newItems) {
                    const item = this.itemRepo.create({
                        orderId,
                        order: { id: orderId },
                        name: n.name ?? '',
                        priceKopecks: n.price_kopecks ?? n.priceKopecks ?? null,
                        estimatedMinutes: n.estimated_minutes ?? n.estimatedMinutes ?? 60,
                        isCompleted: false,
                        isAdditional: false,
                    });
                    await this.itemRepo.save(item);
                }
                const updates = { status: 'confirmed' };
                if (newDateTime) {
                    const dt = new Date(newDateTime);
                    updates.dateTime = dt;
                    updates.plannedStartTime = dt;
                    const totalMin = newItems.reduce((s, i) => s + (Number(i.estimated_minutes) ?? Number(i.estimatedMinutes) ?? 60), 0);
                    updates.plannedEndTime = new Date(dt.getTime() + totalMin * 60 * 1000);
                }
                const mergedEmptyItems = await this.mergeFirstBillingConfirmation(order, status, updates);
                await this.orderRepo.update(orderId, mergedEmptyItems);
                const chat = await this.chats.getChatByOrderId(orderId);
                if (chat && newDateTime) {
                    const dt = new Date(newDateTime);
                    const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
                    const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
                    await this.chats.sendMessage(chat.id, { text: `Клиент подтвердил запись на ${dateStr} в ${timeStr}.`, is_system: true }, false);
                }
                else if (chat) {
                    await this.chats.sendMessage(chat.id, { text: 'Клиент подтвердил запись.', is_system: true }, false);
                }
                return this.findOne(orderId);
            }
        }
        if (status === 'pending_approval') {
            try {
                const afterApproval = await this.approveByClient(orderId, clientPhoneNorm, ['0'], [], {
                    approvalMessageId,
                });
                if (!afterApproval)
                    return null;
            }
            catch (e) {
                if (newDateTime && acceptProposed === false) {
                    const updates = {
                        dateTime: new Date(newDateTime),
                        status: 'pending_confirmation',
                    };
                    const items = await this.itemRepo.find({ where: { orderId } });
                    const totalMin = items.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
                    updates.plannedStartTime = new Date(newDateTime);
                    updates.plannedEndTime = new Date(new Date(newDateTime).getTime() + totalMin * 60 * 1000);
                    await this.orderRepo.update(orderId, updates);
                    const chat = await this.chats.getChatByOrderId(orderId);
                    if (chat) {
                        const dt = new Date(newDateTime);
                        const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
                        const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
                        await this.chats.sendMessage(chat.id, { text: `Клиент перенёс время на ${dateStr} в ${timeStr}.`, is_system: true }, false);
                    }
                    return this.findOne(orderId);
                }
                throw e;
            }
        }
        const updates = {};
        if (newDateTime) {
            const dt = new Date(newDateTime);
            updates.dateTime = dt;
            const items = await this.itemRepo.find({ where: { orderId } });
            const totalMin = items.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
            updates.plannedStartTime = dt;
            updates.plannedEndTime = new Date(dt.getTime() + totalMin * 60 * 1000);
        }
        if (acceptProposed === false && newDateTime) {
            updates.status = 'pending_confirmation';
        }
        else {
            updates.status = 'confirmed';
        }
        if (Object.keys(updates).length > 0) {
            const mergedPc = await this.mergeFirstBillingConfirmation(order, status, updates);
            await this.orderRepo.update(orderId, mergedPc);
        }
        if (newDateTime) {
            const chat = await this.chats.getChatByOrderId(orderId);
            if (chat) {
                const dt = new Date(newDateTime);
                const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
                const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
                const text = acceptProposed !== false
                    ? `Клиент подтвердил запись на ${dateStr} в ${timeStr}.`
                    : `Клиент перенёс время на ${dateStr} в ${timeStr}.`;
                await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
            }
        }
        return this.findOne(orderId);
    }
    async assignMaster(id, body) {
        const order = await this.orderRepo.findOne({ where: { id }, relations: ['items'] });
        if (!order)
            throw new common_1.NotFoundException('Заказ не найден');
        const patch = {};
        if ('master_id' in body)
            patch['masterId'] = body.master_id ?? null;
        if ('bay_id' in body) {
            const v = body.bay_id;
            const newBayId = v === '' || v === undefined ? null : String(v).trim();
            const orgId = order.organizationId;
            const orgRow = await this.orgService.findOne(orgId);
            const schedMode = (0, organization_scheduling_1.normalizeSchedulingMode)(orgRow?.schedulingMode);
            const settings = (await this.orgService.getSettings(orgId));
            const slotsBlock = settings?.slots;
            const bays = (0, bay_settings_util_1.normalizeOrgBays)(slotsBlock);
            if (schedMode !== 'bay_based') {
                if (newBayId != null) {
                    throw new common_1.BadRequestException('В режиме записи по мастеру пост не задаётся.');
                }
            }
            else if (bays.length > 0) {
                if (newBayId != null && !bays.some((b) => b.id === newBayId)) {
                    throw new common_1.BadRequestException('Указан неизвестный пост.');
                }
            }
            else if (newBayId != null) {
                throw new common_1.BadRequestException('Именованные посты не настроены.');
            }
            if (schedMode === 'bay_based' && newBayId != null && bays.length > 0) {
                const items = order.items ?? [];
                const totalMinutes = items.reduce((s, i) => s + (Number(i.estimatedMinutes) || 60), 0);
                const start = order.plannedStartTime ?? order.dateTime;
                const end = order.plannedEndTime ??
                    new Date(new Date(start).getTime() + Math.max(1, totalMinutes) * 60 * 1000);
                const baseOverlap = this.orderRepo
                    .createQueryBuilder('order')
                    .where('order.organization_id = :orgId', { orgId })
                    .andWhere('order.id != :oid', { oid: id })
                    .andWhere('order.status NOT IN (:...excluded)', { excluded: ['cancelled', 'done'] })
                    .andWhere('COALESCE(order.planned_start_time, order.date_time) < :newEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :newStart', { newStart: new Date(start).toISOString(), newEnd: end.toISOString() });
                const overlappingBay = await baseOverlap.clone().andWhere('order.bay_id = :bid', { bid: newBayId }).getCount();
                if (overlappingBay > 0) {
                    throw new common_1.BadRequestException('Этот пост занят в это время.');
                }
            }
            patch['bayId'] = newBayId;
        }
        if (Object.keys(patch).length > 0) {
            await this.orderRepo.update(id, patch);
        }
        return this.findOne(id);
    }
    async cancel(id, opts) {
        const order = await this.orderRepo.findOne({ where: { id } });
        if (!order)
            return null;
        if (opts?.organizationId) {
            if (order.organizationId !== opts.organizationId)
                return null;
        }
        else if (opts?.clientPhone) {
            const orderPhone = this.normalizePhoneForCompare(order.clientPhone);
            const userPhone = this.normalizePhoneForCompare(opts.clientPhone);
            if (orderPhone !== userPhone)
                return null;
        }
        await this.orderRepo.update(id, { status: 'cancelled' });
        return this.findOne(id);
    }
    async approveByClient(orderId, clientPhoneNorm, approvedItemIds, _rejectedItemIds, opts) {
        const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['items'] });
        if (!order)
            return null;
        const orderPhone = this.normalizePhoneForCompare(order.clientPhone);
        const userPhone = this.normalizePhoneForCompare(clientPhoneNorm);
        if (orderPhone !== userPhone)
            return null;
        const status = order.status;
        if (status !== 'pending_approval')
            return this.findOne(orderId);
        if (approvedItemIds.length === 0) {
            const previousStatus = order.previousStatus ?? 'in_progress';
            await this.orderRepo.update(orderId, { status: previousStatus, previousStatus: null });
            const chat = await this.chats.getChatByOrderId(orderId);
            if (chat) {
                await this.chats.sendMessage(chat.id, { text: 'Клиент отказался от дополнительных работ.', is_system: true }, false);
            }
            return this.findOne(orderId);
        }
        const approvalMsg = await this.chats.resolveApprovalMessageForOrder(orderId, opts?.approvalMessageId);
        if (!approvalMsg) {
            if (process.env.NODE_ENV === 'development') {
                console.log('[approveByClient] orderId=%s approvalMsg=null (id=%s) → 409', orderId, opts?.approvalMessageId ?? 'last');
            }
            const hint = opts?.approvalMessageId != null && String(opts.approvalMessageId).trim() !== ''
                ? 'Сообщение согласования устарело. Обновите чат и подтвердите снова.'
                : 'Для этого заказа нет активного запроса согласования от сервиса.';
            throw new common_1.ConflictException(hint);
        }
        const rawPayload = approvalMsg.approvalItems;
        let payload = rawPayload;
        if (typeof rawPayload === 'string') {
            try {
                payload = JSON.parse(rawPayload);
            }
            catch {
                payload = null;
            }
        }
        if (payload != null && typeof payload === 'object' && !Array.isArray(payload)) {
            const o = payload;
            if (o.editedItems != null && o.edited_items == null)
                o.edited_items = o.editedItems;
            if (o.newItems != null && o.new_items == null)
                o.new_items = o.newItems;
        }
        const payloadType = Array.isArray(payload) ? 'array' : typeof payload;
        const payloadKeys = payload != null && typeof payload === 'object' && !Array.isArray(payload)
            ? Object.keys(payload).join(',')
            : '';
        const editedCount = (payload != null && typeof payload === 'object' && !Array.isArray(payload))
            ? (payload.edited_items ?? []).length
            : 0;
        const newCount = (payload != null && typeof payload === 'object' && !Array.isArray(payload))
            ? (payload.new_items ?? []).length
            : 0;
        if (process.env.NODE_ENV === 'development') {
            console.log('[approveByClient] orderId=%s lastApprovalId=%s lastApprovalChatId=%s payloadType=%s keys=%s edited=%d new=%d approved_item_ids=%s', orderId, approvalMsg.id, approvalMsg.chatId, payloadType, payloadKeys, editedCount, newCount, JSON.stringify(approvedItemIds));
        }
        const isObjectFormat = payload != null && typeof payload === 'object' && !Array.isArray(payload);
        if (isObjectFormat) {
            const payloadObj = payload;
            const edited = payloadObj?.edited_items ?? [];
            const newItems = payloadObj?.new_items ?? [];
            const acceptAllNew = approvedItemIds.length === 1 && String(approvedItemIds[0]) === '0';
            const approvedSet = new Set(approvedItemIds);
            const approvedSetWithMsg = new Set();
            approvedItemIds.forEach((aid) => {
                approvedSetWithMsg.add(aid);
                if (typeof aid === 'string' && aid.startsWith('msg_')) {
                    const idx = aid.slice(4);
                    if (/^\d+$/.test(idx))
                        approvedSetWithMsg.add('proposed_' + idx);
                }
            });
            console.log('[approveByClient] objectFormat edited=', edited.length, 'newItems=', newItems.length, 'acceptAllNew=', acceptAllNew, 'approvedSet=', [...approvedSet], 'approvedSetWithMsg=', [...approvedSetWithMsg]);
            for (const e of edited) {
                const id = e.id;
                if (!id)
                    continue;
                console.log('[approveByClient] UPDATE item', id);
                await this.itemRepo.update({ id, orderId }, {
                    priceKopecks: e.price_kopecks ?? e.priceKopecks ?? null,
                    estimatedMinutes: e.estimated_minutes ?? e.estimatedMinutes ?? 60,
                });
            }
            let inserted = 0;
            for (let index = 0; index < newItems.length; index++) {
                const n = newItems[index];
                const id = n.id ?? `proposed_${index}`;
                const allowed = acceptAllNew || approvedSet.has(id) || approvedSetWithMsg.has(id);
                if (!allowed) {
                    console.log('[approveByClient] SKIP new_items[' + index + '] id=', id, 'not in approved set');
                    continue;
                }
                console.log('[approveByClient] INSERT new_items[' + index + ']', n.name);
                const entity = this.itemRepo.create({
                    orderId,
                    order: { id: orderId },
                    name: n.name ?? '',
                    priceKopecks: n.price_kopecks ?? n.priceKopecks ?? null,
                    estimatedMinutes: n.estimated_minutes ?? n.estimatedMinutes ?? 60,
                    isCompleted: false,
                    isAdditional: true,
                });
                await this.itemRepo.save(entity);
                inserted++;
            }
            console.log('[approveByClient] INSERT count=', inserted);
            const previousStatus = order.previousStatus ?? 'confirmed';
            const nextStatus = previousStatus === 'in_progress' ? 'in_progress' : 'confirmed';
            await this.orderRepo.update(orderId, { status: nextStatus, previousStatus: null });
            const chat = await this.chats.getChatByOrderId(orderId);
            if (chat) {
                const names = this.buildClientApprovalAppliedDisplayNames(edited, newItems, approvedItemIds);
                const namesText = names.length > 3 ? names.slice(0, 3).join(', ') + ` и ещё ${names.length - 3}` : names.join(', ');
                const text = namesText
                    ? `Изменения применены: ${names.map((n) => '+' + n).join(', ')}`
                    : 'Изменения применены: клиент подтвердил доп.работы.';
                await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
            }
            return this.findOne(orderId);
        }
        const approvalItems = Array.isArray(payload) ? payload : [];
        const approvedSet = new Set(approvedItemIds);
        const currentItems = (order.items || []).map((i) => ({
            name: i.name,
            price_kopecks: i.priceKopecks,
            estimated_minutes: i.estimatedMinutes ?? 60,
            is_completed: i.isCompleted ?? false,
            is_additional: i.isAdditional ?? false,
        }));
        const itemsWithId = approvalItems.map((i, index) => ({
            id: i.id ?? `proposed_${index}`,
            name: i.name ?? '',
            price_kopecks: i.price_kopecks ?? i.priceKopecks ?? null,
            estimated_minutes: i.estimated_minutes ?? i.estimatedMinutes ?? 60,
            is_completed: false,
            is_additional: true,
        }));
        const addAllLegacy = approvedItemIds.length === 1 && approvedItemIds[0] === '0' && itemsWithId.length > 1;
        const newItemsFromMessage = addAllLegacy
            ? itemsWithId
            : itemsWithId.filter((item) => approvedSet.has(item.id));
        await this.updateItems(orderId, [...currentItems, ...newItemsFromMessage]);
        const previousStatus = order.previousStatus ?? 'confirmed';
        const nextStatus = previousStatus === 'in_progress' ? 'in_progress' : 'confirmed';
        await this.orderRepo.update(orderId, { status: nextStatus, previousStatus: null });
        const chat = await this.chats.getChatByOrderId(orderId);
        if (chat) {
            const approvedSource = addAllLegacy
                ? itemsWithId
                : itemsWithId.filter((item) => approvedSet.has(item.id));
            const approvedNames = approvedSource
                .map((item) => item.name ?? '')
                .filter(Boolean);
            const namesText = approvedNames.length > 3
                ? approvedNames.slice(0, 3).join(', ') + ` и ещё ${approvedNames.length - 3}`
                : approvedNames.join(', ');
            const text = namesText ? `Изменения применены: ${approvedNames.map((n) => '+' + n).join(', ')}` : 'Изменения применены: клиент подтвердил доп.работы.';
            await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
        }
        return this.findOne(orderId);
    }
    async approveBySto(orderId, organizationId) {
        const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['items'] });
        if (!order)
            return null;
        if (order.organizationId !== organizationId)
            return null;
        const status = order.status;
        if (status !== 'pending_approval')
            return null;
        const approvalMsg = await this.chats.getLastApprovalMessageForOrder(orderId);
        const rawPayload = approvalMsg?.approvalItems;
        let payload = rawPayload;
        if (typeof rawPayload === 'string') {
            try {
                payload = JSON.parse(rawPayload);
            }
            catch {
                payload = null;
            }
        }
        const isObjectFormat = payload != null && typeof payload === 'object' && !Array.isArray(payload);
        if (isObjectFormat) {
            const payloadObj = payload;
            const edited = payloadObj?.edited_items ?? [];
            const newItems = payloadObj?.new_items ?? [];
            for (const e of edited) {
                const id = e.id;
                if (!id)
                    continue;
                await this.itemRepo.update({ id, orderId }, {
                    priceKopecks: e.price_kopecks ?? e.priceKopecks ?? null,
                    estimatedMinutes: e.estimated_minutes ?? e.estimatedMinutes ?? 60,
                });
            }
            for (let index = 0; index < newItems.length; index++) {
                const n = newItems[index];
                const entity = this.itemRepo.create({
                    orderId,
                    order: { id: orderId },
                    name: n.name ?? '',
                    priceKopecks: n.price_kopecks ?? n.priceKopecks ?? null,
                    estimatedMinutes: n.estimated_minutes ?? n.estimatedMinutes ?? 60,
                    isCompleted: false,
                    isAdditional: true,
                });
                await this.itemRepo.save(entity);
            }
        }
        else {
            const approvalItems = Array.isArray(payload) ? payload : [];
            const currentItems = (order.items || []).map((i) => ({
                name: i.name,
                price_kopecks: i.priceKopecks,
                estimated_minutes: i.estimatedMinutes ?? 60,
                is_completed: i.isCompleted ?? false,
                is_additional: i.isAdditional ?? false,
            }));
            const itemsWithId = approvalItems.map((i, index) => ({
                id: i.id ?? `proposed_${index}`,
                name: i.name ?? '',
                price_kopecks: i.price_kopecks ?? i.priceKopecks ?? null,
                estimated_minutes: i.estimated_minutes ?? i.estimatedMinutes ?? 60,
                is_completed: false,
                is_additional: true,
            }));
            await this.updateItems(orderId, [...currentItems, ...itemsWithId]);
        }
        const previousStatus = order.previousStatus ?? 'confirmed';
        const nextStatus = previousStatus === 'in_progress' ? 'in_progress' : 'confirmed';
        const itemsAfter = await this.itemRepo.find({ where: { orderId } });
        const totalMinutes = itemsAfter.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
        const plannedStart = order.plannedStartTime ?? order.dateTime ?? new Date();
        const plannedEndTime = new Date(new Date(plannedStart).getTime() + totalMinutes * 60 * 1000);
        await this.orderRepo.update(orderId, {
            status: nextStatus,
            previousStatus: null,
            plannedEndTime,
        });
        const chat = await this.chats.getChatByOrderId(orderId);
        if (chat) {
            const payloadObj = payload != null && typeof payload === 'object' && !Array.isArray(payload)
                ? payload
                : null;
            const addedNames = (payloadObj?.new_items ?? []).map((n) => n?.name ?? '').filter(Boolean);
            const namesText = addedNames.length > 3
                ? addedNames.slice(0, 3).join(', ') + ` и ещё ${addedNames.length - 3}`
                : addedNames.join(', ');
            const text = namesText
                ? `Изменения применены: сервис подтвердил по телефону: ${addedNames.map((n) => '+' + n).join(', ')}`
                : 'Изменения применены: сервис подтвердил по телефону.';
            await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
        }
        return this.findOne(orderId);
    }
    async updateItems(id, items, organizationId) {
        const order = await this.orderRepo.findOne({ where: { id }, relations: ['items'] });
        if (!order)
            return null;
        const status = order.status;
        const currentItems = (order.items || []);
        const currentIds = new Set(currentItems.map((i) => i.id));
        const requiresApproval = status !== 'done' && status !== 'cancelled';
        if (organizationId && requiresApproval) {
            const edited = [];
            const newItems = [];
            for (const i of items || []) {
                const incId = i.id != null ? String(i.id) : undefined;
                const priceK = i.price_kopecks ?? i.priceKopecks ?? null;
                const minutes = i.estimated_minutes ?? i.estimatedMinutes ?? 60;
                const name = i.name ?? '';
                if (incId && currentIds.has(incId)) {
                    const cur = currentItems.find((c) => c.id === incId);
                    const same = cur && cur.priceKopecks === priceK && (cur.estimatedMinutes ?? 60) === minutes;
                    if (!same)
                        edited.push({ id: incId, name, price_kopecks: priceK, estimated_minutes: minutes });
                }
                else {
                    newItems.push({ name, price_kopecks: priceK, estimated_minutes: minutes });
                }
            }
            if (edited.length > 0 || newItems.length > 0) {
                let chat = await this.chats.getChatByOrderId(id);
                if (!chat) {
                    console.log('[updateItems] no chat for orderId=' + id + ', creating via createForOrder');
                    chat = await this.chats.createForOrder(id);
                    console.log('[updateItems] createForOrder returned chat.id=', chat.id);
                }
                if (chat) {
                    const chatId = chat.id;
                    console.log('[updateItems] sending approval to chatId=', chatId, 'orderId=', id, 'edited=', edited.length, 'newItems=', newItems.length);
                    await this.chats.sendMessage(chatId, {
                        order_id: id,
                        approval_items: { edited_items: edited, new_items: newItems },
                    }, false);
                    console.log('[updateItems] sendMessage completed for chatId=', chatId);
                    return this.findOne(id);
                }
                else {
                    console.log('[updateItems] chat still null after createForOrder, cannot send message');
                }
            }
        }
        await this.itemRepo.delete({ orderId: id });
        const toInsert = (items || []).map((i) => this.itemRepo.create({
            orderId: id,
            name: i.name,
            priceKopecks: i.price_kopecks ?? i.priceKopecks ?? null,
            estimatedMinutes: i.estimated_minutes ?? i.estimatedMinutes ?? 60,
            isCompleted: i.is_completed ?? false,
            isAdditional: i.is_additional ?? false,
        }));
        await this.itemRepo.save(toInsert);
        return this.findOne(id);
    }
    async getChatForOrder(orderId, opts) {
        const order = await this.orderRepo.findOne({ where: { id: orderId } });
        if (!order)
            throw new common_1.NotFoundException('Order not found');
        if (opts.organizationId != null) {
            if (order.organizationId !== opts.organizationId)
                throw new common_1.NotFoundException('Order not found');
        }
        else if (opts.clientPhone != null) {
            const orderPhone = this.normalizePhoneForCompare(order.clientPhone || '');
            const userPhone = this.normalizePhoneForCompare(opts.clientPhone);
            if (orderPhone !== userPhone)
                throw new common_1.NotFoundException('Order not found');
        }
        else {
            throw new common_1.NotFoundException('Order not found');
        }
        const orgId = order.organizationId;
        const clientPhone = order.clientPhone || '';
        const chat = await this.chats.getOrCreateForClient(orgId, clientPhone);
        if (process.env.NODE_ENV === 'development') {
            const existing = await this.chats.findChatByOrgAndPhone(orgId, clientPhone);
            console.log('[GET /orders/:id/chat] orderId=%s organizationId=%s clientPhone=***%s returnedChatId=%s foundExistingChat=%s', orderId, orgId, (clientPhone || '').slice(-4), chat.id, !!existing);
        }
        return { chat_id: chat.id };
    }
    async getOrderPhotos(orderId) {
        const order = await this.orderRepo.findOne({ where: { id: orderId } });
        if (!order)
            return null;
        const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
        const modern = await this.mediaService.listOrderMediaForApi(orderId, baseUrl);
        const legacyPhotos = await this.photoRepo.find({ where: { orderId }, order: { createdAt: 'ASC' } });
        const legacy = legacyPhotos.map((p) => ({
            id: p.id,
            file_path: p.filePath,
            url: `${baseUrl}/orders/${orderId}/photos/${p.id}/file`,
            created_at: p.createdAt.toISOString(),
            media_type: 'image',
            size_bytes: null,
            width: null,
            height: null,
        }));
        const merged = [...modern, ...legacy].sort((a, b) => a.created_at.localeCompare(b.created_at));
        return { items: merged };
    }
    async addOrderPhoto(orderId, file, opts) {
        const order = await this.orderRepo.findOne({ where: { id: orderId } });
        if (!order)
            return null;
        const organizationId = order.organizationId;
        await this.assertOrderMediaAttachmentLimit(orderId, organizationId);
        const row = await this.mediaService.attachOrderImage({
            orderId,
            organizationId,
            file,
            uploadedByUserId: opts?.uploadedByUserId ?? null,
        });
        const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
        return {
            id: row.id,
            file_path: row.storage_key,
            url: `${baseUrl}/orders/${orderId}/photos/${row.id}/file`,
            created_at: row.created_at,
            media_type: 'image',
            size_bytes: row.size_bytes,
            width: row.width,
            height: row.height,
        };
    }
    async getOrderPhotoFile(orderId, photoId) {
        const fromMedia = await this.mediaService.getLocalFilePathForOrderPhoto(orderId, photoId);
        if (fromMedia && fs.existsSync(fromMedia))
            return fromMedia;
        const photo = await this.photoRepo.findOne({ where: { id: photoId, orderId } });
        if (!photo)
            return null;
        const absolutePath = path.isAbsolute(photo.filePath) ? photo.filePath : path.join(process.cwd(), photo.filePath);
        if (!fs.existsSync(absolutePath))
            return null;
        return absolutePath;
    }
    async clearAllOrders(organizationId) {
        const orders = await this.orderRepo.find({ where: { organizationId }, select: ['id'] });
        const orderIds = orders.map((o) => o.id);
        if (orderIds.length === 0) {
            return { deletedOrders: 0, deletedItems: 0, deletedPhotos: 0 };
        }
        const { deleted_assets: deletedMediaAssets } = await this.mediaService.purgeMediaForOrders(orderIds);
        const photoResult = await this.photoRepo.createQueryBuilder().delete().where('order_id IN (:...ids)', { ids: orderIds }).execute();
        const deletedLegacyPhotos = photoResult.affected ?? 0;
        const deletedPhotos = deletedMediaAssets + deletedLegacyPhotos;
        const itemResult = await this.itemRepo.createQueryBuilder().delete().where('order_id IN (:...ids)', { ids: orderIds }).execute();
        const deletedItems = itemResult.affected ?? 0;
        await this.chatMsgRepo.createQueryBuilder().update().set({ orderId: null }).where('order_id IN (:...ids)', { ids: orderIds }).execute();
        await this.chatRepo.createQueryBuilder().update().set({ lastOrderId: null }).where('order_id IN (:...ids)', { ids: orderIds }).execute();
        const result = await this.orderRepo.delete({ organizationId });
        const deletedOrders = result.affected ?? 0;
        return { deletedOrders, deletedItems, deletedPhotos };
    }
    async listClientCarsAggregatedForInternal() {
        const rows = await this.orderRepo.find({
            order: { dateTime: 'DESC' },
        });
        const map = new Map();
        for (const o of rows) {
            const phone = this.normalizePhoneForCompare(o.clientPhone || '');
            const carId = o.carId || '';
            if (!phone || !carId)
                continue;
            const key = `${phone}|${carId}`;
            if (!map.has(key)) {
                map.set(key, {
                    client_phone: phone,
                    car_id: carId,
                    car_info: o.carInfo || '',
                    client_name: o.clientName ?? null,
                    orders_count: 1,
                    last_order_at: o.dateTime.toISOString(),
                });
            }
            else {
                map.get(key).orders_count += 1;
            }
        }
        const items = [...map.values()].sort((a, b) => b.last_order_at.localeCompare(a.last_order_at));
        return { items };
    }
    async findOrdersByCarForInternal(clientPhoneDigits, carId) {
        const norm = this.normalizePhoneForCompare(clientPhoneDigits);
        const orders = await this.orderRepo.find({
            where: { carId },
            relations: ['items', 'master', 'organization'],
            order: { dateTime: 'DESC' },
        });
        const filtered = orders.filter((o) => this.normalizePhoneForCompare(o.clientPhone || '') === norm);
        const bayCache = new Map();
        return Promise.all(filtered.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache)));
    }
    async toOrderJsonWithApprovalPreview(o, orgBayCaches = new Map()) {
        let orgMap = orgBayCaches.get(o.organizationId);
        if (!orgMap) {
            const raw = await this.orgService.getSettings(o.organizationId);
            orgMap = (0, bay_settings_util_1.bayNameMapFromSlots)(raw.slots);
            orgBayCaches.set(o.organizationId, orgMap);
        }
        const json = this.toOrderJson(o, orgMap);
        const status = o.status;
        if (status !== 'pending_approval') {
            return json;
        }
        const msg = await this.chats.getLastApprovalMessageForOrder(o.id);
        const raw = msg?.approvalItems;
        const preview = this.buildApprovalPreviewFromPayload(o, raw);
        if (preview != null) {
            json.approval_preview = preview;
        }
        return json;
    }
    parseApprovalPayloadLocal(raw) {
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
    buildApprovalPreviewFromPayload(o, rawPayload) {
        const parsed = this.parseApprovalPayloadLocal(rawPayload);
        if (parsed == null)
            return null;
        const dbItems = (o.items || []);
        const dbRows = dbItems.map((i) => ({
            id: String(i.id),
            name: i.name,
            price_kopecks: i.priceKopecks ?? null,
            estimated_minutes: i.estimatedMinutes ?? 60,
            is_additional: !!i.isAdditional,
        }));
        if (Array.isArray(parsed)) {
            const additions = parsed;
            if (additions.length === 0)
                return null;
            const previewItems = [
                ...dbRows,
                ...additions.map((n, index) => ({
                    id: String(n.id ?? `proposed_${index}`),
                    name: n.name ?? '',
                    price_kopecks: n.price_kopecks ?? n.priceKopecks ?? null,
                    estimated_minutes: n.estimated_minutes ?? n.estimatedMinutes ?? 60,
                    is_additional: true,
                })),
            ];
            const total_kopecks = previewItems.reduce((s, i) => s + (Number(i.price_kopecks) || 0), 0);
            const estimated_minutes = previewItems.reduce((s, i) => s + (Number(i.estimated_minutes) || 0), 0);
            return { items: previewItems, total_kopecks, estimated_minutes };
        }
        if (typeof parsed !== 'object' || parsed === null)
            return null;
        const obj = parsed;
        const edited = (obj.edited_items ?? obj.editedItems ?? []);
        const newItems = (obj.new_items ?? obj.newItems ?? []);
        const originalItems = (obj.original_items ?? obj.originalItems ?? []);
        const totalsAfter = obj.totals_after ?? obj.totalsAfter;
        const editedById = new Map();
        for (const e of edited) {
            if (e?.id != null)
                editedById.set(String(e.id), e);
        }
        const baseOrdered = [];
        if (Array.isArray(originalItems) && originalItems.length > 0) {
            for (const orig of originalItems) {
                const id = orig?.id != null ? String(orig.id) : '';
                if (!id)
                    continue;
                const ed = editedById.get(id);
                if (ed) {
                    editedById.delete(id);
                    baseOrdered.push({
                        id,
                        name: ed.name ?? orig.name ?? '',
                        price_kopecks: ed.price_kopecks ?? ed.priceKopecks ?? orig.price_kopecks ?? orig.priceKopecks ?? null,
                        estimated_minutes: ed.estimated_minutes ?? ed.estimatedMinutes ?? orig.estimated_minutes ?? orig.estimatedMinutes ?? 60,
                        is_additional: !!(orig.is_additional ?? orig.isAdditional),
                    });
                }
                else {
                    baseOrdered.push({
                        id,
                        name: orig.name ?? '',
                        price_kopecks: orig.price_kopecks ?? orig.priceKopecks ?? null,
                        estimated_minutes: orig.estimated_minutes ?? orig.estimatedMinutes ?? 60,
                        is_additional: !!(orig.is_additional ?? orig.isAdditional),
                    });
                }
            }
            const seen = new Set(baseOrdered.map((r) => r.id));
            for (const row of dbRows) {
                if (seen.has(row.id))
                    continue;
                const ed = editedById.get(row.id);
                if (ed) {
                    editedById.delete(row.id);
                    baseOrdered.push({
                        id: row.id,
                        name: ed.name ?? row.name,
                        price_kopecks: ed.price_kopecks ?? ed.priceKopecks ?? row.price_kopecks,
                        estimated_minutes: ed.estimated_minutes ?? ed.estimatedMinutes ?? row.estimated_minutes,
                        is_additional: row.is_additional,
                    });
                }
                else {
                    baseOrdered.push(row);
                }
                seen.add(row.id);
            }
        }
        else {
            for (const row of dbRows) {
                const ed = editedById.get(row.id);
                if (ed) {
                    editedById.delete(row.id);
                    baseOrdered.push({
                        id: row.id,
                        name: ed.name ?? row.name,
                        price_kopecks: ed.price_kopecks ?? ed.priceKopecks ?? row.price_kopecks,
                        estimated_minutes: ed.estimated_minutes ?? ed.estimatedMinutes ?? row.estimated_minutes,
                        is_additional: row.is_additional,
                    });
                }
                else {
                    baseOrdered.push(row);
                }
            }
        }
        let ni = 0;
        for (const n of newItems) {
            const pid = n?.id != null ? String(n.id) : `proposed_${ni}`;
            baseOrdered.push({
                id: pid,
                name: n.name ?? '',
                price_kopecks: n.price_kopecks ?? n.priceKopecks ?? null,
                estimated_minutes: n.estimated_minutes ?? n.estimatedMinutes ?? 60,
                is_additional: true,
            });
            ni++;
        }
        let total_kopecks = totalsAfter?.price_kopecks != null
            ? Number(totalsAfter.price_kopecks)
            : totalsAfter?.priceKopecks != null
                ? Number(totalsAfter.priceKopecks)
                : null;
        let estimated_minutes = totalsAfter?.estimated_minutes != null
            ? Number(totalsAfter.estimated_minutes)
            : totalsAfter?.estimatedMinutes != null
                ? Number(totalsAfter.estimatedMinutes)
                : null;
        if (total_kopecks == null || Number.isNaN(total_kopecks)) {
            total_kopecks = baseOrdered.reduce((s, i) => s + (Number(i.price_kopecks) || 0), 0);
        }
        if (estimated_minutes == null || Number.isNaN(estimated_minutes)) {
            estimated_minutes = baseOrdered.reduce((s, i) => s + (Number(i.estimated_minutes) || 0), 0);
        }
        return {
            items: baseOrdered,
            total_kopecks,
            estimated_minutes,
        };
    }
    toOrderJson(o, bayNames = new Map()) {
        const org = o.organization;
        const order = o;
        const bid = o.bayId;
        return {
            id: o.id,
            order_number: o.orderNumber,
            car_id: o.carId,
            car_info: o.carInfo,
            vin: o.vin ?? null,
            license_plate: o.licensePlate ?? null,
            body_type: o.bodyType ?? null,
            color: o.color ?? null,
            mileage: o.mileage ?? null,
            engine_type: o.engineType ?? null,
            client_name: o.clientName,
            client_phone: o.clientPhone,
            status: o.status,
            previous_status: o.previousStatus ?? null,
            first_confirmed_at: o.firstConfirmedAt?.toISOString?.() ?? null,
            date_time: o.dateTime.toISOString(),
            planned_start_time: o.plannedStartTime?.toISOString?.() ?? null,
            planned_end_time: o.plannedEndTime?.toISOString?.() ?? null,
            actual_start_time: o.actualStartTime?.toISOString?.() ?? null,
            actual_end_time: o.actualEndTime?.toISOString?.() ?? null,
            comment: o.comment,
            organization_id: o.organizationId,
            organization_name: org?.name ?? null,
            organization_address: org?.address ?? null,
            organization_phone: org?.phone ?? null,
            organization_business_kind: org
                ? (0, organization_business_kind_1.normalizeOrganizationBusinessKind)(org.businessKind)
                : null,
            organization_scheduling_mode: org ? (0, organization_scheduling_1.normalizeSchedulingMode)(org.schedulingMode) : null,
            master_id: o.masterId,
            master_name: o.master?.name ?? null,
            bay_id: bid ?? null,
            bay_name: bid && bayNames.size ? bayNames.get(bid) ?? null : null,
            created_at: order.createdAt?.toISOString?.() ?? null,
            updated_at: order.updatedAt?.toISOString?.() ?? null,
            items: (o.items || []).map((i) => ({
                id: i.id,
                name: i.name,
                price_kopecks: i.priceKopecks,
                estimated_minutes: i.estimatedMinutes,
                is_completed: i.isCompleted,
                is_additional: i.isAdditional,
                master_id: i.masterId ?? null,
            })),
        };
    }
};
exports.OrdersService = OrdersService;
exports.OrdersService = OrdersService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(order_entity_1.Order)),
    __param(1, (0, typeorm_1.InjectRepository)(order_item_entity_1.OrderItem)),
    __param(2, (0, typeorm_1.InjectRepository)(order_photo_entity_1.OrderPhoto)),
    __param(3, (0, typeorm_1.InjectRepository)(staff_member_entity_1.StaffMember)),
    __param(4, (0, typeorm_1.InjectRepository)(chat_entity_1.Chat)),
    __param(5, (0, typeorm_1.InjectRepository)(chat_message_entity_1.ChatMessage)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        chats_service_1.ChatsService,
        notifications_service_1.NotificationsService,
        organizations_service_1.OrganizationsService,
        subscription_quota_service_1.SubscriptionQuotaService,
        media_service_1.MediaService])
], OrdersService);
//# sourceMappingURL=orders.service.js.map