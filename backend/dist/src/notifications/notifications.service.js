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
exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const push_device_entity_1 = require("./push-device.entity");
const notification_entity_1 = require("./notification.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const fcm_push_service_1 = require("./fcm-push.service");
const users_service_1 = require("../users/users.service");
const client_notification_preferences_1 = require("./client-notification-preferences");
let NotificationsService = class NotificationsService {
    constructor(pushRepo, notificationRepo, staffRepo, fcm, users) {
        this.pushRepo = pushRepo;
        this.notificationRepo = notificationRepo;
        this.staffRepo = staffRepo;
        this.fcm = fcm;
        this.users = users;
    }
    async registerDevice(userId, deviceToken, platform, fcmApp = 'client') {
        const app = fcmApp === 'business' ? 'business' : 'client';
        const existing = await this.pushRepo.findOne({ where: { userId, deviceToken } });
        if (existing) {
            if (existing.fcmApp !== app || existing.platform !== platform) {
                existing.fcmApp = app;
                existing.platform = platform;
                await this.pushRepo.save(existing);
            }
            return;
        }
        const d = this.pushRepo.create({ userId, deviceToken, platform, fcmApp: app });
        await this.pushRepo.save(d);
    }
    payloadToFcmData(payload) {
        const out = {};
        if (!payload || typeof payload !== 'object')
            return out;
        for (const [k, v] of Object.entries(payload)) {
            if (v == null)
                continue;
            out[k] = typeof v === 'string' ? v : JSON.stringify(v);
        }
        return out;
    }
    async notifyOrganizationInvite(params) {
        return this.create({
            userId: params.userId,
            type: 'organization_invite',
            title: `Приглашение в «${params.organizationName}»`,
            body: `Роль: ${params.role}. Откройте MP-Servis Business → Профиль → Входящие приглашения.`,
            payload: {
                invitation_id: params.invitationId,
                organization_id: params.organizationId,
                organization_name: params.organizationName,
                role: params.role,
            },
        });
    }
    async create(data) {
        const prefs = await this.fcm.getUserPrefs(data.userId);
        if (!(0, client_notification_preferences_1.prefsAllowType)(prefs, data.type)) {
            return null;
        }
        const n = this.notificationRepo.create({
            userId: data.userId,
            carId: data.carId ?? null,
            type: data.type,
            title: data.title,
            body: data.body ?? null,
            payload: data.payload ?? null,
        });
        const saved = await this.notificationRepo.save(n);
        const bodyText = (data.body ?? '').trim() || data.title;
        await this.fcm.sendToUser(data.userId, (0, client_notification_preferences_1.channelForNotificationType)(data.type), data.title, bodyText, {
            type: data.type,
            notification_id: saved.id,
            ...this.payloadToFcmData(data.payload ?? null),
        });
        return saved;
    }
    async createForClientPhone(phoneDigits, data) {
        const userId = await this.users.findIdByNormalizedPhone(phoneDigits);
        if (!userId)
            return null;
        return this.create({ userId, ...data });
    }
    async notifyOrganizationStaffOrderEvent(organizationId, data) {
        const oid = (organizationId || '').trim();
        if (!oid)
            return;
        const staff = await this.staffRepo.find({
            where: { organizationId: oid, isActive: true },
            select: ['userId'],
        });
        const userIds = [
            ...new Set(staff
                .map((s) => (s.userId ?? '').trim())
                .filter((id) => id.length > 0)),
        ];
        const basePayload = { ...data.payload, organization_id: oid };
        for (const userId of userIds) {
            await this.create({
                userId,
                type: 'order',
                title: data.title,
                body: data.body,
                payload: basePayload,
            });
        }
    }
    async createOrRefreshChatMessageForClientPhone(phoneDigits, data) {
        const userId = await this.users.findIdByNormalizedPhone(phoneDigits);
        if (!userId)
            return null;
        const prefs = await this.fcm.getUserPrefs(userId);
        if (!(0, client_notification_preferences_1.prefsAllowType)(prefs, 'chat'))
            return null;
        const chatId = String(data.payload.chat_id ?? '').trim();
        if (!chatId)
            return null;
        const dupes = await this.notificationRepo
            .createQueryBuilder('n')
            .where('n.user_id = :userId', { userId })
            .andWhere('n.type = :type', { type: 'chat' })
            .andWhere('n.is_read = false')
            .andWhere("(n.payload->>'chat_id') = :chatId", { chatId })
            .orderBy('n.created_at', 'DESC')
            .getMany();
        const existing = dupes[0];
        if (dupes.length > 1) {
            const extraIds = dupes.slice(1).map((d) => d.id);
            await this.notificationRepo.delete(extraIds);
        }
        const mergedBody = this.mergeChatNotificationBodies(existing?.body ?? null, data.messageLine);
        const mergedPayload = { ...(existing?.payload && typeof existing.payload === 'object' ? existing.payload : {}), ...data.payload };
        let saved;
        if (existing) {
            await this.notificationRepo.query(`UPDATE notifications SET title = $1, body = $2, payload = $3::jsonb, created_at = NOW() WHERE id = $4`, [data.title, mergedBody, JSON.stringify(mergedPayload), existing.id]);
            const reloaded = await this.notificationRepo.findOne({ where: { id: existing.id } });
            if (!reloaded)
                return null;
            saved = reloaded;
        }
        else {
            const n = this.notificationRepo.create({
                userId,
                carId: null,
                type: 'chat',
                title: data.title,
                body: mergedBody,
                payload: mergedPayload,
            });
            saved = await this.notificationRepo.save(n);
        }
        const bodyText = mergedBody.trim() || data.title;
        await this.fcm.sendToUser(userId, 'chat', data.title, bodyText, {
            type: 'chat',
            notification_id: saved.id,
            ...this.payloadToFcmData(saved.payload ?? null),
        }, { androidTag: `chat_${chatId}`, apnsThreadId: chatId });
        return saved;
    }
    mergeChatNotificationBodies(prev, nextLine) {
        const line = (nextLine || '').trim();
        if (!line)
            return (prev ?? '').trim();
        const lines = (prev ?? '')
            .split('\n')
            .map((l) => l.trimEnd())
            .filter((l) => l.length > 0);
        lines.push(line);
        const maxLines = 6;
        while (lines.length > maxLines)
            lines.shift();
        let s = lines.join('\n');
        const maxChars = 450;
        if (s.length > maxChars) {
            s = '…\n' + s.slice(s.length - maxChars + 2);
        }
        return s;
    }
    async getNotifications(userId, carId, respectClientPrefs = false) {
        let types = null;
        if (respectClientPrefs) {
            const prefs = await this.fcm.getUserPrefs(userId);
            types = (0, client_notification_preferences_1.notificationTypesAllowedByPrefs)(prefs);
            if (types.length === 0)
                return { items: [] };
        }
        const qb = this.notificationRepo
            .createQueryBuilder('n')
            .where('n.user_id = :userId', { userId })
            .orderBy('n.created_at', 'DESC');
        if (carId != null && carId !== '') {
            qb.andWhere('(n.car_id = :carId OR n.car_id IS NULL)', { carId });
        }
        if (types) {
            qb.andWhere('n.type IN (:...types)', { types });
        }
        const list = await qb.getMany();
        return {
            items: list.map((n) => ({
                id: n.id,
                carId: n.carId,
                type: n.type,
                title: n.title,
                body: n.body,
                isRead: n.isRead,
                payload: n.payload,
                createdAt: n.createdAt,
            })),
        };
    }
    async markAsRead(userId, notificationId) {
        const n = await this.notificationRepo.findOne({ where: { id: notificationId, userId } });
        if (!n)
            throw new common_1.NotFoundException('Уведомление не найдено');
        n.isRead = true;
        await this.notificationRepo.save(n);
    }
    async markAllAsRead(userId, carId) {
        const qb = this.notificationRepo.createQueryBuilder().update(notification_entity_1.Notification).set({ isRead: true }).where('user_id = :userId', { userId });
        if (carId != null && carId !== '') {
            qb.andWhere('(car_id = :carId OR car_id IS NULL)', { carId });
        }
        await qb.execute();
    }
    async markUnreadAsReadByOrderId(userId, orderId) {
        const oid = (orderId || '').trim();
        if (!oid)
            return;
        await this.notificationRepo
            .createQueryBuilder()
            .update(notification_entity_1.Notification)
            .set({ isRead: true })
            .where('user_id = :userId', { userId })
            .andWhere('is_read = false')
            .andWhere("(payload->>'order_id') = :oid", { oid })
            .execute();
    }
    async markUnreadAsReadByChatId(userId, chatId) {
        const cid = (chatId || '').trim();
        if (!cid)
            return;
        await this.notificationRepo
            .createQueryBuilder()
            .update(notification_entity_1.Notification)
            .set({ isRead: true })
            .where('user_id = :userId', { userId })
            .andWhere('is_read = false')
            .andWhere("(payload->>'chat_id') = :cid", { cid })
            .execute();
    }
    async delete(userId, notificationId) {
        const n = await this.notificationRepo.findOne({ where: { id: notificationId, userId } });
        if (!n)
            throw new common_1.NotFoundException('Уведомление не найдено');
        await this.notificationRepo.remove(n);
    }
    async getUnreadCount(userId, respectClientPrefs = false) {
        let types = null;
        if (respectClientPrefs) {
            const prefs = await this.fcm.getUserPrefs(userId);
            types = (0, client_notification_preferences_1.notificationTypesAllowedByPrefs)(prefs);
            if (types.length === 0)
                return 0;
        }
        const qb = this.notificationRepo
            .createQueryBuilder('n')
            .where('n.user_id = :userId', { userId })
            .andWhere('n.is_read = false');
        if (types) {
            qb.andWhere('n.type IN (:...types)', { types });
        }
        return qb.getCount();
    }
    async getUnreadCountPerCar(userId, respectClientPrefs = false) {
        let types = null;
        if (respectClientPrefs) {
            const prefs = await this.fcm.getUserPrefs(userId);
            types = (0, client_notification_preferences_1.notificationTypesAllowedByPrefs)(prefs);
            if (types.length === 0)
                return {};
        }
        const qb = this.notificationRepo
            .createQueryBuilder('n')
            .select('n.car_id', 'carId')
            .addSelect('COUNT(*)', 'cnt')
            .where('n.user_id = :userId', { userId })
            .andWhere('n.is_read = false');
        if (types) {
            qb.andWhere('n.type IN (:...types)', { types });
        }
        qb.groupBy('n.car_id');
        const rows = await qb.getRawMany();
        const out = {};
        for (const r of rows) {
            const key = r.carId ?? '';
            out[key] = parseInt(r.cnt, 10) || 0;
        }
        return out;
    }
};
exports.NotificationsService = NotificationsService;
exports.NotificationsService = NotificationsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(push_device_entity_1.PushDevice)),
    __param(1, (0, typeorm_1.InjectRepository)(notification_entity_1.Notification)),
    __param(2, (0, typeorm_1.InjectRepository)(staff_member_entity_1.StaffMember)),
    __param(4, (0, common_1.Inject)((0, common_1.forwardRef)(() => users_service_1.UsersService))),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        fcm_push_service_1.FcmPushService,
        users_service_1.UsersService])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map