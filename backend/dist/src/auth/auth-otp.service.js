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
exports.AuthOtpService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const bcrypt = require("bcrypt");
const crypto_1 = require("crypto");
const auth_otp_challenge_entity_1 = require("./auth-otp-challenge.entity");
const otp_delivery_aggregator_1 = require("./otp-delivery/otp-delivery.aggregator");
const DEFAULT_OTP_TTL_SEC = 300;
const DEFAULT_OTP_MAX_ATTEMPTS = 5;
const MAX_CHALLENGES_PER_RECIPIENT_PER_HOUR = 8;
const RESEND_COOLDOWN_MS = 60 * 1000;
const BCRYPT_ROUNDS = 10;
let AuthOtpService = class AuthOtpService {
    constructor(repo, delivery, config) {
        this.repo = repo;
        this.delivery = delivery;
        this.config = config;
    }
    otpTtlMs() {
        const raw = this.config.get('OTP_TTL_SECONDS');
        const sec = raw != null && raw.trim() !== '' ? parseInt(raw, 10) : DEFAULT_OTP_TTL_SEC;
        const clamped = Number.isFinite(sec) ? Math.min(3600, Math.max(60, sec)) : DEFAULT_OTP_TTL_SEC;
        return clamped * 1000;
    }
    otpMaxAttempts() {
        const raw = this.config.get('OTP_MAX_ATTEMPTS');
        const n = raw != null && raw.trim() !== '' ? parseInt(raw, 10) : DEFAULT_OTP_MAX_ATTEMPTS;
        return Number.isFinite(n) ? Math.min(20, Math.max(3, n)) : DEFAULT_OTP_MAX_ATTEMPTS;
    }
    normalizeEmail(email) {
        const e = email.trim().toLowerCase();
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) {
            throw new common_1.BadRequestException('Некорректный email');
        }
        if (e.length > 320)
            throw new common_1.BadRequestException('Email слишком длинный');
        return e;
    }
    normalizePhoneDigits(phone) {
        const n = phone.replace(/\D/g, '');
        if (n.length < 10)
            throw new common_1.BadRequestException('Некорректный номер телефона');
        return n.length === 10 ? `7${n}` : n;
    }
    resolveRecipient(params) {
        const hasEmail = params.email != null && String(params.email).trim() !== '';
        const hasPhone = params.phone != null && String(params.phone).trim() !== '';
        if (hasEmail === hasPhone) {
            throw new common_1.BadRequestException('Укажите ровно одно: email или phone');
        }
        if (hasEmail) {
            return { recipient: this.normalizeEmail(params.email), recipientKind: 'email' };
        }
        return { recipient: this.normalizePhoneDigits(params.phone), recipientKind: 'phone' };
    }
    generateNumericCode(length) {
        const min = 10 ** (length - 1);
        const max = 10 ** length - 1;
        return String((0, crypto_1.randomInt)(min, max + 1));
    }
    async createChallenge(params) {
        const { recipient, recipientKind } = this.resolveRecipient(params);
        const requestedChannel = (params.requestedChannel || (recipientKind === 'email' ? 'email' : 'sms')).toLowerCase();
        const hourAgo = new Date(Date.now() - 60 * 60 * 1000);
        const recent = await this.repo.count({
            where: { recipient, recipientKind, createdAt: (0, typeorm_2.MoreThan)(hourAgo) },
        });
        if (recent >= MAX_CHALLENGES_PER_RECIPIENT_PER_HOUR) {
            throw new common_1.HttpException('Слишком много запросов кода. Попробуйте позже.', common_1.HttpStatus.TOO_MANY_REQUESTS);
        }
        const last = await this.repo.findOne({
            where: { recipient, recipientKind },
            order: { createdAt: 'DESC' },
        });
        if (last &&
            last.status === 'pending' &&
            last.expiresAt.getTime() > Date.now() &&
            Date.now() - last.createdAt.getTime() < RESEND_COOLDOWN_MS) {
            const waitSec = Math.ceil((RESEND_COOLDOWN_MS - (Date.now() - last.createdAt.getTime())) / 1000);
            throw new common_1.HttpException(`Повторная отправка через ${waitSec} с`, common_1.HttpStatus.TOO_MANY_REQUESTS);
        }
        await this.repo.update({ recipient, recipientKind, status: 'pending', consumedAt: (0, typeorm_2.IsNull)() }, { status: 'consumed', consumedAt: new Date() });
        const ttlMs = this.otpTtlMs();
        const code = this.generateNumericCode(6);
        const codeHash = await bcrypt.hash(code, BCRYPT_ROUNDS);
        const expiresAt = new Date(Date.now() + ttlMs);
        const row = this.repo.create({
            recipient,
            recipientKind,
            channel: requestedChannel,
            codeHash,
            expiresAt,
            status: 'pending',
            consumedAt: null,
            attemptsCount: 0,
            sendCount: 1,
            createdIp: params.ip,
        });
        await this.repo.save(row);
        await this.delivery.deliver({
            code,
            ttlSeconds: Math.floor(ttlMs / 1000),
            recipient: recipientKind === 'email' ? recipient : `+${recipient}`,
            recipientKind,
            requestedChannel,
        });
        return {
            challenge_id: row.id,
            expires_in: Math.floor(ttlMs / 1000),
            resend_after: Math.floor(RESEND_COOLDOWN_MS / 1000),
        };
    }
    async verifyChallenge(challengeId, code, expectedRecipient, expectedKind) {
        const row = await this.repo.findOne({ where: { id: challengeId } });
        if (!row || row.recipient !== expectedRecipient || row.recipientKind !== expectedKind) {
            throw new common_1.BadRequestException('Неверный код или сессия подтверждения');
        }
        if (row.status === 'consumed') {
            throw new common_1.BadRequestException('Код уже использован. Запросите новый.');
        }
        if (row.status === 'locked') {
            throw new common_1.BadRequestException('Превышено число попыток. Запросите новый код.');
        }
        if (row.expiresAt.getTime() < Date.now()) {
            row.status = 'consumed';
            row.consumedAt = new Date();
            await this.repo.save(row);
            throw new common_1.BadRequestException('Срок действия кода истёк');
        }
        const maxAttempts = this.otpMaxAttempts();
        if (row.attemptsCount >= maxAttempts) {
            row.status = 'locked';
            await this.repo.save(row);
            throw new common_1.BadRequestException('Превышено число попыток. Запросите новый код.');
        }
        const ok = await bcrypt.compare(code.trim(), row.codeHash);
        if (!ok) {
            row.attemptsCount += 1;
            if (row.attemptsCount >= maxAttempts) {
                row.status = 'locked';
            }
            await this.repo.save(row);
            throw new common_1.BadRequestException('Неверный код');
        }
        row.status = 'consumed';
        row.consumedAt = new Date();
        await this.repo.save(row);
        return row;
    }
};
exports.AuthOtpService = AuthOtpService;
exports.AuthOtpService = AuthOtpService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(auth_otp_challenge_entity_1.AuthOtpChallenge)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        otp_delivery_aggregator_1.OtpDeliveryAggregator,
        config_1.ConfigService])
], AuthOtpService);
//# sourceMappingURL=auth-otp.service.js.map