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
exports.AuthOtpChallenge = void 0;
const typeorm_1 = require("typeorm");
let AuthOtpChallenge = class AuthOtpChallenge {
};
exports.AuthOtpChallenge = AuthOtpChallenge;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], AuthOtpChallenge.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 320 }),
    __metadata("design:type", String)
], AuthOtpChallenge.prototype, "recipient", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'recipient_kind', type: 'varchar', length: 16 }),
    __metadata("design:type", String)
], AuthOtpChallenge.prototype, "recipientKind", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 24, default: 'email' }),
    __metadata("design:type", String)
], AuthOtpChallenge.prototype, "channel", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'code_hash', type: 'varchar', length: 128 }),
    __metadata("design:type", String)
], AuthOtpChallenge.prototype, "codeHash", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expires_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], AuthOtpChallenge.prototype, "expiresAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 24, default: 'pending' }),
    __metadata("design:type", String)
], AuthOtpChallenge.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'consumed_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], AuthOtpChallenge.prototype, "consumedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'attempts_count', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], AuthOtpChallenge.prototype, "attemptsCount", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'send_count', type: 'int', default: 1 }),
    __metadata("design:type", Number)
], AuthOtpChallenge.prototype, "sendCount", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], AuthOtpChallenge.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'created_ip', type: 'varchar', length: 64, nullable: true }),
    __metadata("design:type", Object)
], AuthOtpChallenge.prototype, "createdIp", void 0);
exports.AuthOtpChallenge = AuthOtpChallenge = __decorate([
    (0, typeorm_1.Entity)('auth_otp_challenges'),
    (0, typeorm_1.Index)(['recipient', 'recipientKind', 'createdAt'])
], AuthOtpChallenge);
//# sourceMappingURL=auth-otp-challenge.entity.js.map