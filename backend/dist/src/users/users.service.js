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
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_entity_1 = require("./user.entity");
const user_session_entity_1 = require("../auth/user-session.entity");
const security_event_entity_1 = require("../auth/security-event.entity");
const notification_entity_1 = require("../notifications/notification.entity");
const push_device_entity_1 = require("../notifications/push-device.entity");
const client_notification_preferences_1 = require("../notifications/client-notification-preferences");
const user_organization_membership_entity_1 = require("./user-organization-membership.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const organizations_service_1 = require("../organizations/organizations.service");
const organization_invitation_entity_1 = require("../organizations/organization-invitation.entity");
let UsersService = class UsersService {
    constructor(repo, membershipRepo, staffRepo, invitationRepo, orgService, dataSource) {
        this.repo = repo;
        this.membershipRepo = membershipRepo;
        this.staffRepo = staffRepo;
        this.invitationRepo = invitationRepo;
        this.orgService = orgService;
        this.dataSource = dataSource;
    }
    async findById(id) {
        return this.repo.findOne({ where: { id }, relations: ['organization'] });
    }
    async findAll() {
        return this.repo.find({
            relations: ['organization'],
            order: { name: 'ASC', phone: 'ASC' },
        });
    }
    profileResponse(user, organizations) {
        return {
            id: user.id,
            email: user.email,
            email_verified_at: user.emailVerifiedAt ? user.emailVerifiedAt.toISOString() : null,
            phone: user.phone,
            phone_verified_at: user.phoneVerifiedAt ? user.phoneVerifiedAt.toISOString() : null,
            name: user.name,
            role: user.role,
            organization_id: user.organizationId,
            organizations: organizations ?? [],
        };
    }
    async ensureMembership(userId, organizationId, role) {
        if (!organizationId)
            return;
        const exists = await this.membershipRepo.findOne({ where: { userId, organizationId } });
        if (exists)
            return;
        await this.membershipRepo.save(this.membershipRepo.create({ userId, organizationId, role: role || 'owner' }));
    }
    async getOrganizationSummariesForUser(user) {
        const map = new Map();
        const memberships = await this.membershipRepo.find({
            where: { userId: user.id },
            relations: ['organization'],
        });
        for (const m of memberships) {
            const o = m.organization;
            map.set(m.organizationId, {
                id: m.organizationId,
                name: o?.name ?? 'Организация',
                role: m.role,
            });
        }
        const staffRows = await this.staffRepo.find({
            where: { userId: user.id },
            relations: ['organization'],
        });
        for (const s of staffRows) {
            if (!s.organizationId || map.has(s.organizationId))
                continue;
            const o = s.organization;
            map.set(s.organizationId, {
                id: s.organizationId,
                name: o?.name ?? 'Организация',
                role: s.role || 'master',
            });
        }
        if (user.organizationId && !map.has(user.organizationId)) {
            const org = await this.orgService.findOne(user.organizationId);
            if (org) {
                map.set(org.id, { id: org.id, name: org.name, role: user.role });
            }
        }
        const orgIds = [...map.keys()];
        const planKeys = await this.orgService.getPlanKeysForOrganizations(orgIds);
        for (const oid of orgIds) {
            const row = map.get(oid);
            if (row)
                row.plan_key = planKeys[oid] ?? 'team';
        }
        return [...map.values()].sort((a, b) => a.name.localeCompare(b.name, 'ru'));
    }
    async canAccessOrganization(userId, organizationId) {
        const m = await this.membershipRepo.findOne({ where: { userId, organizationId } });
        if (m)
            return true;
        const staff = await this.staffRepo.findOne({ where: { userId, organizationId } });
        return !!staff;
    }
    async switchActiveOrganization(userId, organizationId) {
        const user = await this.findById(userId);
        if (!user)
            throw new common_1.NotFoundException('Пользователь не найден');
        if (!(await this.canAccessOrganization(userId, organizationId))) {
            throw new common_1.ForbiddenException('Нет доступа к этой организации');
        }
        const membership = await this.membershipRepo.findOne({ where: { userId, organizationId } });
        let nextRole = user.role;
        if (membership) {
            nextRole = membership.role;
        }
        else {
            const staff = await this.staffRepo.findOne({ where: { userId, organizationId } });
            if (staff?.role)
                nextRole = staff.role;
        }
        user.organizationId = organizationId;
        user.role = nextRole;
        await this.repo.save(user);
        const fresh = await this.findById(userId);
        return fresh;
    }
    async canCreateAdditionalOrganization(user) {
        if (user.role === 'owner' || user.role === 'solo')
            return true;
        const ownerMembership = await this.membershipRepo.findOne({ where: { userId: user.id, role: 'owner' } });
        return !!ownerMembership;
    }
    async createOwnedOrganization(userId, dto) {
        const user = await this.findById(userId);
        if (!user)
            throw new common_1.NotFoundException('Пользователь не найден');
        if (!(await this.canCreateAdditionalOrganization(user))) {
            throw new common_1.ForbiddenException('Создавать организации могут владелец или самозанятый');
        }
        const org = await this.orgService.createOrganizationWithDefaults(dto);
        await this.ensureMembership(userId, org.id, 'owner');
        user.organizationId = org.id;
        user.role = 'owner';
        await this.repo.save(user);
        const fresh = await this.findById(userId);
        const summaries = await this.getOrganizationSummariesForUser(fresh);
        return { user: fresh, summaries };
    }
    async getNotificationPreferences(userId) {
        const u = await this.findById(userId);
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        return (0, client_notification_preferences_1.mergeClientNotificationPrefs)(u.notificationPreferences);
    }
    async updateNotificationPreferences(userId, patch) {
        const u = await this.findById(userId);
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        const cur = (0, client_notification_preferences_1.mergeClientNotificationPrefs)(u.notificationPreferences);
        const next = { ...cur, ...patch };
        u.notificationPreferences = next;
        await this.repo.save(u);
        return next;
    }
    async findIdByNormalizedPhone(phoneDigits) {
        if (!phoneDigits)
            return null;
        const norm = (p) => {
            const d = String(p || '').replace(/\D/g, '');
            if (d.length === 11 && d.startsWith('8'))
                return '7' + d.slice(1);
            return d;
        };
        const users = await this.repo.find({ select: ['id', 'phone'] });
        for (const row of users) {
            if (row.phone != null && norm(row.phone) === phoneDigits)
                return row.id;
        }
        return null;
    }
    normalizePhoneLoose(raw) {
        const d = String(raw).replace(/\D/g, '');
        if (d.length === 11 && d.startsWith('8'))
            return '7' + d.slice(1);
        if (d.length === 10 && !d.startsWith('7'))
            return '7' + d;
        return d;
    }
    normalizeEmail(raw) {
        if (!raw)
            return null;
        const e = String(raw).trim().toLowerCase();
        return e || null;
    }
    invitationToDto(inv) {
        return {
            id: inv.id,
            organization_id: inv.organizationId,
            organization_name: inv.organization?.name ?? 'Организация',
            role: inv.role,
            invited_name: inv.invitedName,
            invited_email: inv.invitedEmail,
            invited_phone: inv.invitedPhone,
            message: inv.message,
            status: inv.status,
            created_at: inv.createdAt?.toISOString() ?? null,
            expires_at: inv.expiresAt?.toISOString() ?? null,
            responded_at: inv.respondedAt?.toISOString() ?? null,
        };
    }
    async findUserIdForInviteContact(emailNorm, phoneNorm) {
        if (emailNorm) {
            const u = await this.repo.findOne({ where: { email: emailNorm } });
            if (u)
                return u.id;
        }
        if (phoneNorm) {
            return this.findIdByNormalizedPhone(phoneNorm);
        }
        return null;
    }
    async getIncomingInvitations(userId) {
        const u = await this.findById(userId);
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        const emailNorm = this.normalizeEmail(u.email);
        const phoneNorm = u.phone ? this.normalizePhoneLoose(u.phone) : null;
        if (!emailNorm && !phoneNorm)
            return { items: [] };
        const now = new Date();
        const qb = this.invitationRepo
            .createQueryBuilder('inv')
            .leftJoinAndSelect('inv.organization', 'org')
            .where('inv.status = :status', { status: 'pending' })
            .andWhere('(inv.expires_at IS NULL OR inv.expires_at > :now)', { now });
        if (emailNorm && phoneNorm) {
            qb.andWhere('(inv.invited_email_norm = :email OR inv.invited_phone_norm = :phone)', {
                email: emailNorm,
                phone: phoneNorm,
            });
        }
        else if (emailNorm) {
            qb.andWhere('inv.invited_email_norm = :email', { email: emailNorm });
        }
        else if (phoneNorm) {
            qb.andWhere('inv.invited_phone_norm = :phone', { phone: phoneNorm });
        }
        const rows = await qb.orderBy('inv.created_at', 'DESC').getMany();
        return { items: rows.map((x) => this.invitationToDto(x)) };
    }
    async acceptInvitation(userId, invitationId, opts) {
        const u = await this.findById(userId);
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        const setActive = opts?.set_active_organization !== false;
        const emailNorm = this.normalizeEmail(u.email);
        const phoneNorm = u.phone ? this.normalizePhoneLoose(u.phone) : null;
        const result = await this.dataSource.transaction(async (em) => {
            const inviteRepo = em.getRepository(organization_invitation_entity_1.OrganizationInvitation);
            const membershipRepo = em.getRepository(user_organization_membership_entity_1.UserOrganizationMembership);
            const staffRepo = em.getRepository(staff_member_entity_1.StaffMember);
            const userRepo = em.getRepository(user_entity_1.User);
            const inv = await inviteRepo.findOne({ where: { id: invitationId } });
            if (!inv)
                throw new common_1.NotFoundException('Приглашение не найдено');
            if (inv.status !== 'pending')
                throw new common_1.BadRequestException('Приглашение уже обработано');
            if (inv.expiresAt && inv.expiresAt.getTime() < Date.now()) {
                inv.status = 'expired';
                inv.respondedAt = new Date();
                await inviteRepo.save(inv);
                throw new common_1.BadRequestException('Срок действия приглашения истёк');
            }
            const emailMatches = !!(emailNorm && inv.invitedEmailNorm && emailNorm === inv.invitedEmailNorm);
            const phoneMatches = !!(phoneNorm && inv.invitedPhoneNorm && phoneNorm === inv.invitedPhoneNorm);
            if (!emailMatches && !phoneMatches) {
                throw new common_1.ForbiddenException('Это приглашение не принадлежит вашему аккаунту');
            }
            if (emailMatches && !u.emailVerifiedAt) {
                throw new common_1.ForbiddenException('Подтвердите email, чтобы принять приглашение');
            }
            if (phoneMatches && !u.phoneVerifiedAt) {
                throw new common_1.ForbiddenException('Подтвердите телефон, чтобы принять приглашение');
            }
            const role = String(inv.role || 'master');
            const existingMembership = await membershipRepo.findOne({
                where: { userId, organizationId: inv.organizationId },
            });
            if (!existingMembership) {
                await membershipRepo.save(membershipRepo.create({
                    userId,
                    organizationId: inv.organizationId,
                    role,
                }));
            }
            const existingStaff = await staffRepo.findOne({
                where: { userId, organizationId: inv.organizationId },
            });
            let staffId = existingStaff?.id ?? null;
            if (!existingStaff) {
                const row = staffRepo.create({
                    organizationId: inv.organizationId,
                    userId,
                    name: u.name || inv.invitedName || 'Сотрудник',
                    phone: u.phone ?? inv.invitedPhone ?? null,
                    email: u.email ?? inv.invitedEmail ?? null,
                    role,
                    isActive: true,
                    invitedAt: new Date(),
                    skills: [],
                });
                const saved = await staffRepo.save(row);
                staffId = saved.id;
            }
            inv.status = 'accepted';
            inv.acceptedByUserId = userId;
            inv.respondedAt = new Date();
            inv.staffMemberId = staffId;
            await inviteRepo.save(inv);
            if (setActive) {
                u.organizationId = inv.organizationId;
                u.role = role;
                await userRepo.save(u);
            }
            return inv.organizationId;
        });
        const fresh = await this.findById(userId);
        const summaries = await this.getOrganizationSummariesForUser(fresh);
        if (setActive && result && fresh) {
            fresh.organizationId = result;
        }
        return { user: fresh, summaries };
    }
    async declineInvitation(userId, invitationId) {
        const u = await this.findById(userId);
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        const emailNorm = this.normalizeEmail(u.email);
        const phoneNorm = u.phone ? this.normalizePhoneLoose(u.phone) : null;
        const inv = await this.invitationRepo.findOne({ where: { id: invitationId } });
        if (!inv)
            throw new common_1.NotFoundException('Приглашение не найдено');
        if (inv.status !== 'pending')
            throw new common_1.BadRequestException('Приглашение уже обработано');
        const emailMatches = !!(emailNorm && inv.invitedEmailNorm && emailNorm === inv.invitedEmailNorm);
        const phoneMatches = !!(phoneNorm && inv.invitedPhoneNorm && phoneNorm === inv.invitedPhoneNorm);
        if (!emailMatches && !phoneMatches) {
            throw new common_1.ForbiddenException('Это приглашение не принадлежит вашему аккаунту');
        }
        inv.status = 'declined';
        inv.respondedAt = new Date();
        await this.invitationRepo.save(inv);
        return this.invitationToDto(inv);
    }
    async updateOwnProfile(userId, dto) {
        const user = await this.findById(userId);
        if (!user)
            throw new common_1.NotFoundException('Пользователь не найден');
        if (dto.name != null) {
            const n = dto.name.trim();
            if (n.length > 0)
                user.name = n;
        }
        if (dto.phone != null && dto.phone.trim()) {
            const digits = this.normalizePhoneLoose(dto.phone);
            if (digits.length < 10 || digits.length > 15) {
                throw new common_1.BadRequestException('Некорректный номер телефона');
            }
            const ownerId = await this.findIdByNormalizedPhone(digits);
            if (ownerId != null && ownerId !== userId) {
                throw new common_1.ConflictException('Этот номер уже привязан к другому аккаунту. Укажите другой телефон.');
            }
            user.phone = digits;
            if (user.phoneVerifiedAt == null)
                user.phoneVerifiedAt = null;
        }
        try {
            await this.repo.save(user);
        }
        catch (e) {
            const err = e;
            if (err?.code === '23505') {
                throw new common_1.ConflictException('Этот номер уже привязан к другому аккаунту. Укажите другой телефон.');
            }
            throw e;
        }
        const fresh = await this.findById(userId);
        return fresh;
    }
    async deleteOwnAccount(userId) {
        await this.dataSource.transaction(async (em) => {
            await em.delete(user_session_entity_1.UserSession, { userId });
            await em.delete(security_event_entity_1.SecurityEvent, { userId });
            await em.delete(notification_entity_1.Notification, { userId });
            await em.delete(push_device_entity_1.PushDevice, { userId });
            await em.delete(user_organization_membership_entity_1.UserOrganizationMembership, { userId });
            await em.getRepository(staff_member_entity_1.StaffMember).update({ userId }, { userId: null });
            await em.delete(user_entity_1.User, { id: userId });
        });
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(1, (0, typeorm_1.InjectRepository)(user_organization_membership_entity_1.UserOrganizationMembership)),
    __param(2, (0, typeorm_1.InjectRepository)(staff_member_entity_1.StaffMember)),
    __param(3, (0, typeorm_1.InjectRepository)(organization_invitation_entity_1.OrganizationInvitation)),
    __param(4, (0, common_1.Inject)((0, common_1.forwardRef)(() => organizations_service_1.OrganizationsService))),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        organizations_service_1.OrganizationsService,
        typeorm_2.DataSource])
], UsersService);
//# sourceMappingURL=users.service.js.map