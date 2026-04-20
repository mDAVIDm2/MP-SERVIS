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
exports.AuthSecurityEventService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const security_event_entity_1 = require("./security-event.entity");
const notifications_service_1 = require("../notifications/notifications.service");
const CRITICAL_TYPES = new Set([
    'refresh_reuse_detected',
    'sessions_revoked_all_except',
    'session_revoked',
    'login_failed',
]);
const REFRESH_REUSE_PUSH_COOLDOWN_MS = 15 * 60 * 1000;
let AuthSecurityEventService = class AuthSecurityEventService {
    constructor(repo, notifications) {
        this.repo = repo;
        this.notifications = notifications;
        this._lastRefreshReusePush = new Map();
    }
    async record(userId, type, opts) {
        const row = this.repo.create({
            userId,
            type,
            sessionId: opts.sessionId ?? null,
            ip: opts.ip ?? null,
            userAgent: opts.userAgent ?? null,
            metadata: opts.metadata ?? null,
        });
        await this.repo.save(row);
        if (!CRITICAL_TYPES.has(type))
            return;
        if (type === 'refresh_reuse_detected') {
            const now = Date.now();
            const prev = this._lastRefreshReusePush.get(userId) ?? 0;
            if (now - prev < REFRESH_REUSE_PUSH_COOLDOWN_MS) {
                return;
            }
            this._lastRefreshReusePush.set(userId, now);
        }
        const titles = {
            refresh_reuse_detected: 'Безопасность: попытка повторного использования сессии',
            sessions_revoked_all_except: 'Завершены другие сессии',
            session_revoked: 'Сессия завершена',
            login_failed: 'Неудачная попытка входа',
        };
        await this.notifications.create({
            userId,
            type: 'security',
            title: titles[type] || 'Событие безопасности',
            body: type,
            payload: { security_event_type: type, ...opts.metadata },
        });
    }
    async listForUser(userId, limit = 50) {
        const rows = await this.repo.find({
            where: { userId },
            order: { createdAt: 'DESC' },
            take: limit,
        });
        return rows.map((r) => ({
            id: r.id,
            type: r.type,
            metadata: r.metadata,
            session_id: r.sessionId,
            created_at: r.createdAt instanceof Date ? r.createdAt.toISOString() : r.createdAt,
        }));
    }
};
exports.AuthSecurityEventService = AuthSecurityEventService;
exports.AuthSecurityEventService = AuthSecurityEventService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(security_event_entity_1.SecurityEvent)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        notifications_service_1.NotificationsService])
], AuthSecurityEventService);
//# sourceMappingURL=auth-security-event.service.js.map