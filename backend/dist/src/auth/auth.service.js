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
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_entity_1 = require("../users/user.entity");
const organization_entity_1 = require("../organizations/organization.entity");
const users_service_1 = require("../users/users.service");
const auth_otp_service_1 = require("./auth-otp.service");
const auth_session_service_1 = require("./auth-session.service");
const auth_security_event_service_1 = require("./auth-security-event.service");
const TEST_ORG_NAME = 'Тестовый автосервис';
const TEST_PHONES = {
    '79001111111': { role: 'owner', name: 'Владелец (тест)' },
    '79002222222': { role: 'admin', name: 'Администратор (тест)' },
    '79003333333': { role: 'master', name: 'Мастер (тест)' },
    '79004444444': { role: 'solo', name: 'Самозанятый (тест)' },
    '79197341904': { role: 'owner', name: 'Владелец' },
};
const TEST_EMAILS = {
    'owner@mpservis.test': { role: 'owner', name: 'Владелец (тест)' },
    'admin@mpservis.test': { role: 'admin', name: 'Администратор (тест)' },
    'master@mpservis.test': { role: 'master', name: 'Мастер (тест)' },
    'solo@mpservis.test': { role: 'solo', name: 'Самозанятый (тест)' },
};
function userAuthJson(user, organizations) {
    return {
        id: user.id,
        email: user.email,
        email_verified_at: user.emailVerifiedAt ? user.emailVerifiedAt.toISOString() : null,
        phone: user.phone,
        phone_verified_at: user.phoneVerifiedAt ? user.phoneVerifiedAt.toISOString() : null,
        name: user.name,
        avatar_url: user.avatarUrl ?? null,
        account_realm: user.accountRealm ?? 'business',
        role: user.role,
        organization_id: user.organizationId,
        organizations,
    };
}
function realmFromAudience(aud) {
    return aud === 'business' ? 'business' : 'client';
}
let AuthService = class AuthService {
    constructor(userRepo, orgRepo, usersService, otp, sessions, securityEvents) {
        this.userRepo = userRepo;
        this.orgRepo = orgRepo;
        this.usersService = usersService;
        this.otp = otp;
        this.sessions = sessions;
        this.securityEvents = securityEvents;
    }
    async getOrCreateTestOrg() {
        let org = await this.orgRepo.findOne({ where: { name: TEST_ORG_NAME } });
        if (!org) {
            org = this.orgRepo.create({
                name: TEST_ORG_NAME,
                address: 'ул. Тестовая, 1',
                phone: '+7 900 000-00-00',
                workingHours: 'Пн–Пт 9:00–19:00',
            });
            await this.orgRepo.save(org);
        }
        return org;
    }
    async findUserByEmailNormalized(normalizedEmail, realm, withOrganization = false) {
        const e = normalizedEmail.trim().toLowerCase();
        if (!e)
            return null;
        const qb = this.userRepo
            .createQueryBuilder('u')
            .where('u.email IS NOT NULL AND LOWER(TRIM(u.email)) = :e', { e })
            .andWhere('u.account_realm = :realm', { realm });
        if (withOrganization) {
            qb.leftJoinAndSelect('u.organization', 'organization');
        }
        return qb.getOne();
    }
    async findUserByPhoneDigits(phoneDigits, realm, withOrganization = false) {
        const qb = this.userRepo
            .createQueryBuilder('u')
            .where('u.phone = :p', { p: phoneDigits })
            .andWhere('u.account_realm = :realm', { realm });
        if (withOrganization) {
            qb.leftJoinAndSelect('u.organization', 'organization');
        }
        return qb.getOne();
    }
    async sendCode(params) {
        const realm = realmFromAudience(params.audience);
        const base = await this.otp.createChallenge({
            email: params.email,
            phone: params.phone,
            requestedChannel: params.channel,
            ip: params.ip,
        });
        let accountExists = false;
        try {
            if (params.email != null && String(params.email).trim() !== '') {
                const e = this.otp.normalizeEmail(params.email);
                accountExists = !!(await this.findUserByEmailNormalized(e, realm));
            }
            else if (params.phone != null && String(params.phone).trim() !== '') {
                const p = this.otp.normalizePhoneDigits(params.phone);
                accountExists = !!(await this.userRepo.findOne({ where: { phone: p, accountRealm: realm }, select: ['id'] }));
            }
        }
        catch {
        }
        return { ...base, account_exists: accountExists };
    }
    applyPhoneUnverified(user, raw, otpKind) {
        if (otpKind !== 'email' || raw == null || !String(raw).trim())
            return;
        let digits;
        try {
            digits = this.otp.normalizePhoneDigits(raw);
        }
        catch {
            throw new common_1.BadRequestException('Некорректный номер телефона (неподтверждённый)');
        }
        if (user.phoneVerifiedAt != null)
            return;
        user.phone = digits;
        user.phoneVerifiedAt = null;
    }
    async verifyCode(dto, audience, meta) {
        let expectedRecipient;
        let expectedKind;
        if (dto.email != null && String(dto.email).trim() !== '') {
            expectedRecipient = this.otp.normalizeEmail(dto.email);
            expectedKind = 'email';
        }
        else if (dto.phone != null && String(dto.phone).trim() !== '') {
            expectedRecipient = this.otp.normalizePhoneDigits(dto.phone);
            expectedKind = 'phone';
        }
        else {
            throw new common_1.BadRequestException('Укажите email или phone (как при отправке кода)');
        }
        await this.otp.verifyChallenge(dto.challenge_id, dto.code, expectedRecipient, expectedKind);
        const realm = realmFromAudience(audience);
        let user = null;
        if (expectedKind === 'email') {
            user = await this.findUserByEmailNormalized(expectedRecipient, realm, true);
            const testEntry = audience === 'business' ? TEST_EMAILS[expectedRecipient] : undefined;
            if (!user) {
                if (!testEntry) {
                    if (!dto.name?.trim())
                        throw new common_1.BadRequestException('Укажите имя');
                    if (!dto.phone_unverified?.trim())
                        throw new common_1.BadRequestException('Укажите телефон');
                    try {
                        this.otp.normalizePhoneDigits(dto.phone_unverified);
                    }
                    catch {
                        throw new common_1.BadRequestException('Некорректный номер телефона');
                    }
                }
                const displayName = testEntry ? testEntry.name : dto.name.trim();
                user = this.userRepo.create({
                    email: expectedRecipient,
                    emailVerifiedAt: new Date(),
                    name: displayName,
                    role: testEntry?.role ?? 'solo',
                    phone: null,
                    phoneVerifiedAt: null,
                    organizationId: null,
                    accountRealm: realm,
                });
                this.applyPhoneUnverified(user, dto.phone_unverified, 'email');
                if (testEntry) {
                    const org = await this.getOrCreateTestOrg();
                    user.organizationId = org.id;
                    user.name = testEntry.name;
                    user.role = testEntry.role;
                }
                try {
                    await this.userRepo.save(user);
                }
                catch (e) {
                    const err = e;
                    if (err?.code === '23505') {
                        throw new common_1.ConflictException(realm === 'client'
                            ? 'Этот email или телефон уже занят в клиентском аккаунте'
                            : 'Этот email или телефон уже занят в бизнес-аккаунте');
                    }
                    throw e;
                }
            }
            else {
                user.email = expectedRecipient;
                if (!user.emailVerifiedAt) {
                    user.emailVerifiedAt = new Date();
                }
                this.applyPhoneUnverified(user, dto.phone_unverified, 'email');
                if (testEntry) {
                    const org = await this.getOrCreateTestOrg();
                    user.role = testEntry.role;
                    user.organizationId = org.id;
                    user.name = testEntry.name;
                }
                try {
                    await this.userRepo.save(user);
                }
                catch (e) {
                    const err = e;
                    if (err?.code === '23505') {
                        throw new common_1.ConflictException(realm === 'client'
                            ? 'Этот email или телефон уже занят в клиентском аккаунте'
                            : 'Этот email или телефон уже занят в бизнес-аккаунте');
                    }
                    throw e;
                }
            }
        }
        else {
            const n = expectedRecipient;
            const testEntry = audience === 'business' ? TEST_PHONES[n] : undefined;
            user = await this.findUserByPhoneDigits(n, realm, true);
            if (testEntry) {
                const org = await this.getOrCreateTestOrg();
                if (!user) {
                    user = this.userRepo.create({
                        phone: n,
                        phoneVerifiedAt: new Date(),
                        name: testEntry.name,
                        role: testEntry.role,
                        organizationId: org.id,
                        email: null,
                        emailVerifiedAt: null,
                        accountRealm: realm,
                    });
                    await this.userRepo.save(user);
                }
                else {
                    user.role = testEntry.role;
                    user.organizationId = org.id;
                    user.name = testEntry.name;
                    user.phoneVerifiedAt = new Date();
                    await this.userRepo.save(user);
                }
            }
            else {
                if (!user) {
                    user = this.userRepo.create({
                        phone: n,
                        phoneVerifiedAt: new Date(),
                        name: 'User',
                        role: 'solo',
                        email: null,
                        emailVerifiedAt: null,
                        organizationId: null,
                        accountRealm: realm,
                    });
                    await this.userRepo.save(user);
                }
                else {
                    user.phoneVerifiedAt = new Date();
                    await this.userRepo.save(user);
                }
            }
        }
        if (user.accountRealm === 'business') {
            await this.usersService.ensureMembership(user.id, user.organizationId ?? undefined, user.role);
        }
        const pair = await this.sessions.createSession(user, audience, meta);
        const organizations = await this.usersService.getOrganizationSummariesForUser(user);
        await this.securityEvents.record(user.id, 'login_success', {
            sessionId: pair.session_id,
            ip: meta.ip ?? null,
            userAgent: meta.userAgent ?? null,
        });
        const userPayload = userAuthJson(user, organizations);
        await this.usersService.appendStaffCapabilities(user, userPayload);
        return {
            access_token: pair.access_token,
            refresh_token: pair.refresh_token,
            expires_in: pair.expires_in,
            session_id: pair.session_id,
            user: userPayload,
        };
    }
    async refresh(refreshToken, audience, meta) {
        const pair = await this.sessions.refreshTokens(refreshToken, audience, meta);
        const user = await this.userRepo.findOne({ where: { id: pair.userId }, relations: ['organization'] });
        if (!user)
            throw new Error('User not found');
        const organizations = await this.usersService.getOrganizationSummariesForUser(user);
        const userPayload = userAuthJson(user, organizations);
        await this.usersService.appendStaffCapabilities(user, userPayload);
        return {
            access_token: pair.access_token,
            refresh_token: pair.refresh_token,
            expires_in: pair.expires_in,
            session_id: pair.session_id,
            user: userPayload,
        };
    }
    async logoutByRefresh(refreshToken) {
        await this.sessions.revokeByRefreshToken(refreshToken);
    }
    async logoutAllSessions(userId) {
        return this.sessions.revokeAllForUser(userId);
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(1, (0, typeorm_1.InjectRepository)(organization_entity_1.Organization)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        users_service_1.UsersService,
        auth_otp_service_1.AuthOtpService,
        auth_session_service_1.AuthSessionService,
        auth_security_event_service_1.AuthSecurityEventService])
], AuthService);
//# sourceMappingURL=auth.service.js.map