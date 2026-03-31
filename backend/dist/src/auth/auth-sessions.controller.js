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
exports.AuthSessionsController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const jwt_1 = require("@nestjs/jwt");
const passport_jwt_1 = require("passport-jwt");
const auth_session_service_1 = require("./auth-session.service");
const auth_security_event_service_1 = require("./auth-security-event.service");
const throttler_1 = require("@nestjs/throttler");
let AuthSessionsController = class AuthSessionsController {
    constructor(sessions, securityEvents, jwt) {
        this.sessions = sessions;
        this.securityEvents = securityEvents;
        this.jwt = jwt;
    }
    currentSessionId(req) {
        const extractor = passport_jwt_1.ExtractJwt.fromAuthHeaderAsBearerToken();
        const token = extractor(req);
        if (!token)
            return null;
        try {
            const p = this.jwt.decode(token);
            return p?.sid ?? null;
        }
        catch {
            return null;
        }
    }
    async listSessions(req) {
        const sid = this.currentSessionId(req);
        return { items: await this.sessions.listSessions(req.user.id, sid) };
    }
    async listSecurityEvents(req) {
        return { items: await this.securityEvents.listForUser(req.user.id) };
    }
    async revokeSession(req, id) {
        const sid = this.currentSessionId(req);
        if (id === sid) {
            throw new common_1.UnauthorizedException('Используйте «Выйти» для текущего устройства');
        }
        const ok = await this.sessions.revokeSession(req.user.id, id);
        if (!ok)
            throw new common_1.NotFoundException('Сессия не найдена');
        return { ok: true };
    }
    async revokeOthers(req) {
        const sid = this.currentSessionId(req);
        if (!sid)
            throw new common_1.UnauthorizedException('Нет активной сессии в токене');
        const n = await this.sessions.revokeAllExcept(req.user.id, sid);
        return { ok: true, revoked: n };
    }
};
exports.AuthSessionsController = AuthSessionsController;
__decorate([
    (0, common_1.Get)('sessions'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], AuthSessionsController.prototype, "listSessions", null);
__decorate([
    (0, common_1.Get)('security-events'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], AuthSessionsController.prototype, "listSecurityEvents", null);
__decorate([
    (0, common_1.Delete)('sessions/:id'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AuthSessionsController.prototype, "revokeSession", null);
__decorate([
    (0, common_1.Post)('sessions/revoke-others'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], AuthSessionsController.prototype, "revokeOthers", null);
exports.AuthSessionsController = AuthSessionsController = __decorate([
    (0, common_1.Controller)('auth'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt'), throttler_1.ThrottlerGuard),
    (0, throttler_1.Throttle)({ default: { limit: 120, ttl: 60000 } }),
    __metadata("design:paramtypes", [auth_session_service_1.AuthSessionService,
        auth_security_event_service_1.AuthSecurityEventService,
        jwt_1.JwtService])
], AuthSessionsController);
//# sourceMappingURL=auth-sessions.controller.js.map