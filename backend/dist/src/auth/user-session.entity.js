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
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserSession = void 0;
const typeorm_1 = require("typeorm");
let UserSession = class UserSession {
};
exports.UserSession = UserSession;
__decorate([
    (0, typeorm_1.PrimaryColumn)('uuid'),
    __metadata("design:type", String)
], UserSession.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'family_id', type: 'uuid' }),
    __metadata("design:type", String)
], UserSession.prototype, "familyId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id', type: 'uuid' }),
    __metadata("design:type", String)
], UserSession.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'refresh_hash', type: 'varchar', length: 128 }),
    __metadata("design:type", String)
], UserSession.prototype, "refreshHash", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'device_id', type: 'varchar', length: 128, nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "deviceId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'device_name', type: 'varchar', length: 256, nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "deviceName", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "platform", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_agent', type: 'varchar', length: 512, nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "userAgent", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 64, nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "ip", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], UserSession.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'last_seen_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "lastSeenAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'revoked_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "revokedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'replaced_by_session_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], UserSession.prototype, "replacedBySessionId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'jwt_audience', type: 'varchar', length: 16, default: 'client' }),
    __metadata("design:type", String)
], UserSession.prototype, "jwtAudience", void 0);
exports.UserSession = UserSession = __decorate([
    (0, typeorm_1.Entity)('user_sessions'),
    (0, typeorm_1.Index)(['userId', 'revokedAt']),
    (0, typeorm_1.Index)(['familyId'])
], UserSession);
//# sourceMappingURL=user-session.entity.js.map