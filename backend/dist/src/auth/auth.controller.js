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
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const throttler_1 = require("@nestjs/throttler");
const auth_service_1 = require("./auth.service");
const auth_dto_1 = require("./dto/auth.dto");
function audienceFromReq(req) {
    const raw = String(req.headers['x-autohub-app'] ?? '').toLowerCase();
    return raw === 'business' ? 'business' : 'client';
}
function deviceMeta(req, body) {
    const ua = req.headers['user-agent'];
    return {
        deviceId: body.device_id ?? null,
        deviceName: body.device_name ?? null,
        platform: body.platform ?? null,
        userAgent: typeof ua === 'string' ? ua.slice(0, 512) : null,
        ip: req.ip || null,
    };
}
let AuthController = class AuthController {
    constructor(auth) {
        this.auth = auth;
    }
    async sendCode(dto, req, ip) {
        if ((dto.email == null || String(dto.email).trim() === '') &&
            (dto.phone == null || String(dto.phone).trim() === '')) {
            throw new common_1.BadRequestException('Укажите email или phone');
        }
        if (dto.email != null &&
            String(dto.email).trim() !== '' &&
            dto.phone != null &&
            String(dto.phone).trim() !== '') {
            throw new common_1.BadRequestException('Укажите только email или только phone');
        }
        return this.auth.sendCode({
            email: dto.email,
            phone: dto.phone,
            channel: dto.channel,
            ip: ip || null,
        });
    }
    async verifyCode(dto, req) {
        const hasE = dto.email != null && String(dto.email).trim() !== '';
        const hasP = dto.phone != null && String(dto.phone).trim() !== '';
        if (!hasE && !hasP)
            throw new common_1.BadRequestException('Укажите email или phone');
        if (hasE && hasP)
            throw new common_1.BadRequestException('Укажите только email или только phone');
        const aud = audienceFromReq(req);
        return this.auth.verifyCode({
            email: dto.email,
            phone: dto.phone,
            challenge_id: dto.challenge_id,
            code: dto.code,
            phone_unverified: dto.phone_unverified,
            name: dto.name,
        }, aud, deviceMeta(req, dto));
    }
    async refresh(dto, req) {
        const aud = audienceFromReq(req);
        return this.auth.refresh(dto.refresh_token, aud, deviceMeta(req, dto));
    }
    async logout(dto) {
        await this.auth.logoutByRefresh(dto.refresh_token);
        return { ok: true };
    }
    async logoutAll(req) {
        const n = await this.auth.logoutAllSessions(req.user.id);
        return { ok: true, revoked: n };
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('send-code'),
    (0, throttler_1.Throttle)({ default: { limit: 12, ttl: 60000 } }),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Ip)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [auth_dto_1.SendCodeDto, Object, String]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "sendCode", null);
__decorate([
    (0, common_1.Post)('verify-code'),
    (0, throttler_1.Throttle)({ default: { limit: 30, ttl: 60000 } }),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [auth_dto_1.VerifyCodeDto, Object]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "verifyCode", null);
__decorate([
    (0, common_1.Post)('refresh'),
    (0, throttler_1.Throttle)({ default: { limit: 45, ttl: 60000 } }),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [auth_dto_1.RefreshDto, Object]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "refresh", null);
__decorate([
    (0, common_1.Post)('logout'),
    (0, throttler_1.Throttle)({ default: { limit: 20, ttl: 60000 } }),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [auth_dto_1.LogoutDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "logout", null);
__decorate([
    (0, common_1.Post)('logout-all'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    (0, throttler_1.Throttle)({ default: { limit: 10, ttl: 60000 } }),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "logoutAll", null);
exports.AuthController = AuthController = __decorate([
    (0, common_1.Controller)('auth'),
    (0, common_1.UseGuards)(throttler_1.ThrottlerGuard),
    (0, throttler_1.Throttle)({ default: { limit: 60, ttl: 60000 } }),
    __metadata("design:paramtypes", [auth_service_1.AuthService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map