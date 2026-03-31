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
exports.AuthSessionService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const jwt_1 = require("@nestjs/jwt");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const bcrypt = require("bcrypt");
const crypto_1 = require("crypto");
const user_session_entity_1 = require("./user-session.entity");
const auth_security_event_service_1 = require("./auth-security-event.service");
let AuthSessionService = class AuthSessionService {
    constructor(repo, jwt, config, securityEvents) {
        this.repo = repo;
        this.jwt = jwt;
        this.config = config;
        this.securityEvents = securityEvents;
        this.refreshBcryptRounds = 10;
    }
    pepper() {
        return this.config.get('REFRESH_TOKEN_PEPPER') || '';
    }
    hashKey(sessionId, secret) {
        return `${this.pepper()}${sessionId}:${secret}`;
    }
    parseRefreshToken(refreshToken) {
        const t = refreshToken.trim();
        const dot = t.indexOf('.');
        if (dot <= 0 || dot >= t.length - 1)
            return null;
        const sessionId = t.slice(0, dot);
        const secret = t.slice(dot + 1);
        if (!/^[0-9a-f-]{36}$/i.test(sessionId) || !secret)
            return null;
        return { sessionId, secret };
    }
    accessExpiresIn() {
        return this.config.get('JWT_ACCESS_EXPIRES_IN') || this.config.get('JWT_EXPIRES_IN') || '15m';
    }
    accessExpiresInSeconds() {
        const raw = this.accessExpiresIn();
        if (raw.endsWith('m'))
            return parseInt(raw.slice(0, -1), 10) * 60;
        if (raw.endsWith('h'))
            return parseInt(raw.slice(0, -1), 10) * 3600;
        if (raw.endsWith('d'))
            return parseInt(raw.slice(0, -1), 10) * 86400;
        const n = parseInt(raw, 10);
        return Number.isFinite(n) ? n : 900;
    }
    async createSession(user, audience, meta) {
        const sessionId = (0, crypto_1.randomUUID)();
        const familyId = (0, crypto_1.randomUUID)();
        const secret = (0, crypto_1.randomBytes)(32).toString('hex');
        const refreshPlain = `${sessionId}.${secret}`;
        const refreshHash = await bcrypt.hash(this.hashKey(sessionId, secret), this.refreshBcryptRounds);
        const row = this.repo.create({
            id: sessionId,
            familyId,
            userId: user.id,
            refreshHash,
            deviceId: meta.deviceId ?? null,
            deviceName: meta.deviceName ?? null,
            platform: meta.platform ?? null,
            userAgent: meta.userAgent ?? null,
            ip: meta.ip ?? null,
            lastSeenAt: new Date(),
            revokedAt: null,
            replacedBySessionId: null,
            jwtAudience: audience,
        });
        await this.repo.save(row);
        const expiresIn = this.accessExpiresInSeconds();
        const access_token = await this.jwt.signAsync({ sub: user.id, sid: sessionId, aud: audience }, { expiresIn: this.accessExpiresIn() });
        return {
            access_token,
            refresh_token: refreshPlain,
            session_id: sessionId,
            expires_in: expiresIn,
        };
    }
    async refreshTokens(refreshToken, audience, meta) {
        const parsed = this.parseRefreshToken(refreshToken);
        if (!parsed)
            throw new common_1.UnauthorizedException('Неверный refresh token');
        const { sessionId, secret } = parsed;
        const session = await this.repo.findOne({ where: { id: sessionId } });
        if (!session)
            throw new common_1.UnauthorizedException('Сессия не найдена');
        const key = this.hashKey(sessionId, secret);
        const match = await bcrypt.compare(key, session.refreshHash);
        if (!match)
            throw new common_1.UnauthorizedException('Неверный refresh token');
        if (session.jwtAudience !== audience) {
            throw new common_1.UnauthorizedException('Неверная аудитория токена');
        }
        if (session.revokedAt) {
            await this.revokeFamily(session.familyId, session.userId);
            await this.securityEvents.record(session.userId, 'refresh_reuse_detected', {
                sessionId: session.id,
                ip: meta.ip ?? null,
                userAgent: meta.userAgent ?? null,
            });
            throw new common_1.UnauthorizedException('Токен отозван (возможна компрометация)');
        }
        const newSessionId = (0, crypto_1.randomUUID)();
        const newSecret = (0, crypto_1.randomBytes)(32).toString('hex');
        const newPlain = `${newSessionId}.${newSecret}`;
        const newHash = await bcrypt.hash(this.hashKey(newSessionId, newSecret), this.refreshBcryptRounds);
        session.revokedAt = new Date();
        session.replacedBySessionId = newSessionId;
        await this.repo.save(session);
        const newRow = this.repo.create({
            id: newSessionId,
            familyId: session.familyId,
            userId: session.userId,
            refreshHash: newHash,
            deviceId: meta.deviceId ?? session.deviceId,
            deviceName: meta.deviceName ?? session.deviceName,
            platform: meta.platform ?? session.platform,
            userAgent: meta.userAgent ?? session.userAgent,
            ip: meta.ip ?? session.ip,
            lastSeenAt: new Date(),
            revokedAt: null,
            replacedBySessionId: null,
            jwtAudience: audience,
        });
        await this.repo.save(newRow);
        const userId = session.userId;
        const expiresIn = this.accessExpiresInSeconds();
        const access_token = await this.jwt.signAsync({ sub: userId, sid: newSessionId, aud: audience }, { expiresIn: this.accessExpiresIn() });
        await this.securityEvents.record(userId, 'refresh_rotated', {
            sessionId: newSessionId,
            ip: meta.ip ?? null,
            userAgent: meta.userAgent ?? null,
        });
        return {
            access_token,
            refresh_token: newPlain,
            session_id: newSessionId,
            expires_in: expiresIn,
            userId,
        };
    }
    async revokeByRefreshToken(refreshToken) {
        const parsed = this.parseRefreshToken(refreshToken);
        if (!parsed)
            return null;
        const session = await this.repo.findOne({ where: { id: parsed.sessionId } });
        if (!session || session.revokedAt)
            return session ? { userId: session.userId } : null;
        const key = this.hashKey(parsed.sessionId, parsed.secret);
        const match = await bcrypt.compare(key, session.refreshHash);
        if (!match)
            return null;
        session.revokedAt = new Date();
        await this.repo.save(session);
        await this.securityEvents.record(session.userId, 'logout', {
            sessionId: session.id,
        });
        return { userId: session.userId };
    }
    async revokeSession(userId, sessionId) {
        const session = await this.repo.findOne({ where: { id: sessionId, userId } });
        if (!session || session.revokedAt)
            return false;
        session.revokedAt = new Date();
        await this.repo.save(session);
        await this.securityEvents.record(userId, 'session_revoked', { sessionId });
        return true;
    }
    async revokeAllForUser(userId) {
        const res = await this.repo
            .createQueryBuilder()
            .update(user_session_entity_1.UserSession)
            .set({ revokedAt: () => 'NOW()' })
            .where('user_id = :userId', { userId })
            .andWhere('revoked_at IS NULL')
            .execute();
        await this.securityEvents.record(userId, 'logout_all', {});
        return res.affected ?? 0;
    }
    async revokeAllExcept(userId, exceptSessionId) {
        const res = await this.repo
            .createQueryBuilder()
            .update(user_session_entity_1.UserSession)
            .set({ revokedAt: () => 'NOW()' })
            .where('user_id = :userId', { userId })
            .andWhere('id != :except', { except: exceptSessionId })
            .andWhere('revoked_at IS NULL')
            .execute();
        await this.securityEvents.record(userId, 'sessions_revoked_all_except', {
            metadata: { except_session_id: exceptSessionId },
        });
        return res.affected ?? 0;
    }
    async revokeFamily(familyId, userId) {
        await this.repo
            .createQueryBuilder()
            .update(user_session_entity_1.UserSession)
            .set({ revokedAt: () => 'NOW()' })
            .where('family_id = :familyId', { familyId })
            .andWhere('user_id = :userId', { userId })
            .andWhere('revoked_at IS NULL')
            .execute();
    }
    async assertSessionActive(sessionId, userId) {
        return this.repo.findOne({
            where: { id: sessionId, userId, revokedAt: (0, typeorm_2.IsNull)() },
        });
    }
    async listSessions(userId, currentSessionId) {
        const rows = await this.repo.find({
            where: { userId },
            order: { createdAt: 'DESC' },
            take: 50,
        });
        return rows.map((r) => ({
            id: r.id,
            created_at: r.createdAt instanceof Date ? r.createdAt.toISOString() : r.createdAt,
            last_seen_at: r.lastSeenAt ? (r.lastSeenAt instanceof Date ? r.lastSeenAt.toISOString() : r.lastSeenAt) : null,
            device_name: r.deviceName,
            platform: r.platform,
            revoked: r.revokedAt != null,
            is_current: currentSessionId != null && r.id === currentSessionId,
        }));
    }
    async touchSession(sessionId, userId) {
        await this.repo.update({ id: sessionId, userId, revokedAt: (0, typeorm_2.IsNull)() }, { lastSeenAt: new Date() });
    }
};
exports.AuthSessionService = AuthSessionService;
exports.AuthSessionService = AuthSessionService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_session_entity_1.UserSession)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        jwt_1.JwtService,
        config_1.ConfigService,
        auth_security_event_service_1.AuthSecurityEventService])
], AuthSessionService);
//# sourceMappingURL=auth-session.service.js.map