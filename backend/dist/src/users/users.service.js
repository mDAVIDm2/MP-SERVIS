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
const fs = require("fs");
const path = require("path");
const crypto_1 = require("crypto");
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
const chat_entity_1 = require("../chats/chat.entity");
const order_entity_1 = require("../orders/order.entity");
const USER_AVATAR_DIR = path.join(process.cwd(), 'uploads', 'user-avatars');
function clearUserAvatarFiles(userId) {
    const dir = path.join(USER_AVATAR_DIR, userId);
    if (!fs.existsSync(dir))
        return;
    for (const name of fs.readdirSync(dir)) {
        const lower = name.toLowerCase();
        if (!lower.startsWith('avatar'))
            continue;
        try {
            fs.unlinkSync(path.join(dir, name));
        }
        catch {
        }
    }
}
let UsersService = class UsersService {
    constructor(repo, membershipRepo, staffRepo, invitationRepo, chatRepo, orderRepo, orgService, dataSource) {
        this.repo = repo;
        this.membershipRepo = membershipRepo;
        this.staffRepo = staffRepo;
        this.invitationRepo = invitationRepo;
        this.chatRepo = chatRepo;
        this.orderRepo = orderRepo;
        this.orgService = orgService;
        this.dataSource = dataSource;
    }
    async canStaffFetchClientAvatar(viewer, avatarOwnerUserId) {
        if (!viewer || !avatarOwnerUserId)
            return false;
        if (viewer.id === avatarOwnerUserId)
            return true;
        if (viewer.accountRealm !== 'business' || !viewer.organizationId)
            return false;
        const target = await this.repo.findOne({
            where: { id: avatarOwnerUserId },
            select: ['id', 'accountRealm', 'phone'],
        });
        if (!target || target.accountRealm !== 'client')
            return false;
        const tKey = this.clientPhoneMatchKey(target.phone || '');
        if (!tKey)
            return false;
        const orgId = viewer.organizationId;
        const chats = await this.chatRepo.find({
            where: { organizationId: orgId },
            select: ['clientPhone'],
        });
        for (const c of chats) {
            if (this.clientPhoneMatchKey(c.clientPhone || '') === tKey)
                return true;
        }
        const rows = await this.orderRepo
            .createQueryBuilder('o')
            .select('DISTINCT o.client_phone', 'phone')
            .where('o.organization_id = :orgId', { orgId })
            .andWhere('o.client_phone IS NOT NULL')
            .andWhere("TRIM(o.client_phone) <> ''")
            .getRawMany();
        for (const r of rows) {
            if (this.clientPhoneMatchKey(r.phone || '') === tKey)
                return true;
        }
        return false;
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
            avatar_url: user.avatarUrl ?? null,
            account_realm: user.accountRealm ?? 'business',
            role: user.role,
            organization_id: user.organizationId,
            organizations: organizations ?? [],
        };
    }
    async appendStaffCapabilities(user, payload) {
        const orgId = user.organizationId?.trim();
        if (!orgId)
            return;
        const role = user.role;
        if (role === 'owner' || role === 'solo') {
            payload['staff_capabilities'] = {
                can_see_chats: true,
                can_write_chats: true,
                can_manage_org_settings: true,
            };
            return;
        }
        const staff = await this.staffRepo.findOne({
            where: { userId: user.id, organizationId: orgId },
        });
        if (!staff) {
            if (role === 'admin') {
                payload['staff_capabilities'] = {
                    can_see_chats: true,
                    can_write_chats: true,
                    can_manage_org_settings: true,
                };
            }
            else {
                payload['staff_capabilities'] = {
                    can_see_chats: false,
                    can_write_chats: false,
                    can_manage_org_settings: false,
                };
            }
            return;
        }
        const s = staff;
        payload['staff_capabilities'] = {
            can_see_chats: s.canSeeChats === true,
            can_write_chats: s.canWriteChats === true,
            can_manage_org_settings: s.canManageOrgSettings === true,
        };
    }
    async saveUserAvatar(userId, file) {
        const user = await this.repo.findOne({ where: { id: userId } });
        if (!user)
            throw new common_1.NotFoundException('Пользователь не найден');
        const extRaw = path.extname(file.originalname || '').toLowerCase();
        const ext = extRaw && extRaw.length <= 6 && /^\.[a-z0-9]+$/.test(extRaw) ? extRaw : '.jpg';
        const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
        if (!allowed.includes(ext)) {
            throw new common_1.BadRequestException('Допустимы изображения: jpg, png, webp');
        }
        const filename = `avatar-${(0, crypto_1.randomUUID)()}${ext}`;
        const dir = path.join(USER_AVATAR_DIR, userId);
        if (!fs.existsSync(dir))
            fs.mkdirSync(dir, { recursive: true });
        clearUserAvatarFiles(userId);
        const filePath = path.join(dir, filename);
        if (file.buffer?.length) {
            fs.writeFileSync(filePath, file.buffer);
        }
        else if (file.path && fs.existsSync(file.path)) {
            fs.copyFileSync(file.path, filePath);
        }
        else {
            throw new common_1.BadRequestException('Пустой файл');
        }
        const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
        const url = `${baseUrl}/profile/avatar/${userId}/${encodeURIComponent(filename)}`;
        user.avatarUrl = url;
        await this.repo.save(user);
        return user;
    }
    getUserAvatarFilePath(userId, filename) {
        const safeName = path.basename(filename);
        if (!safeName || safeName.includes('..'))
            return null;
        const fullPath = path.join(USER_AVATAR_DIR, userId, safeName);
        if (!fs.existsSync(fullPath))
            return null;
        return fullPath;
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
        if (user.accountRealm !== 'business') {
            throw new common_1.ForbiddenException('Смена организации доступна только в бизнес-аккаунте');
        }
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
        if (user.accountRealm !== 'business') {
            throw new common_1.ForbiddenException('Создание организации доступно только в бизнес-приложении');
        }
        if (!(await this.canCreateAdditionalOrganization(user))) {
            throw new common_1.ForbiddenException('Создавать организации могут владелец или самозанятый');
        }
        const org = await this.orgService.createOrganizationWithDefaults(dto);
        await this.ensureMembership(userId, org.id, 'owner');
        user.organizationId = org.id;
        if (user.role !== 'solo') {
            user.role = 'owner';
        }
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
    assertClientRealm(user) {
        if (user.accountRealm !== 'client') {
            throw new common_1.ForbiddenException('Доступно только для клиентского аккаунта');
        }
    }
    async getClientAppState(userId) {
        const u = await this.repo.findOne({
            where: { id: userId },
            select: ['id', 'accountRealm', 'clientAppState', 'clientAppStateUpdatedAt'],
        });
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        if (u.accountRealm !== 'client') {
            return { payload: null, updated_at: null };
        }
        return {
            payload: u.clientAppState ?? null,
            updated_at: u.clientAppStateUpdatedAt ? u.clientAppStateUpdatedAt.toISOString() : null,
        };
    }
    async putClientAppState(userId, payload) {
        const u = await this.repo.findOne({ where: { id: userId } });
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        this.assertClientRealm(u);
        const json = JSON.stringify(payload);
        const max = 600 * 1024;
        if (json.length > max) {
            throw new common_1.BadRequestException(`Слишком большой объём настроек (>${max} байт)`);
        }
        u.clientAppState = payload;
        u.clientAppStateUpdatedAt = new Date();
        await this.repo.save(u);
        return { ok: true, updated_at: u.clientAppStateUpdatedAt.toISOString() };
    }
    async findIdByNormalizedPhone(phoneDigits, realm = 'client') {
        if (!phoneDigits)
            return null;
        const norm = (p) => {
            const d = String(p || '').replace(/\D/g, '');
            if (d.length === 11 && d.startsWith('8'))
                return '7' + d.slice(1);
            return d;
        };
        const users = await this.repo.find({ where: { accountRealm: realm }, select: ['id', 'phone'] });
        for (const row of users) {
            if (row.phone != null && norm(row.phone) === phoneDigits)
                return row.id;
        }
        return null;
    }
    clientPhoneMatchKey(raw) {
        const d = String(raw || '').replace(/\D/g, '');
        if (d.length === 11 && d.startsWith('8'))
            return '7' + d.slice(1);
        if (d.length === 10)
            return '7' + d;
        return d;
    }
    async mapClientAvatarUrlsByPhoneKeys(keys) {
        const m = new Map();
        for (const k of keys)
            m.set(k, null);
        if (keys.size === 0)
            return m;
        const users = await this.repo.find({
            where: { accountRealm: 'client' },
            select: ['phone', 'avatarUrl'],
        });
        for (const u of users) {
            if (u.phone == null)
                continue;
            const uk = this.clientPhoneMatchKey(u.phone);
            if (keys.has(uk))
                m.set(uk, u.avatarUrl ?? null);
        }
        return m;
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
            const u = await this.repo.findOne({ where: { email: emailNorm, accountRealm: 'business' } });
            if (u)
                return u.id;
        }
        if (phoneNorm) {
            return this.findIdByNormalizedPhone(phoneNorm, 'business');
        }
        return null;
    }
    async getIncomingInvitations(userId) {
        const u = await this.findById(userId);
        if (!u)
            throw new common_1.NotFoundException('Пользователь не найден');
        if (u.accountRealm !== 'business')
            return { items: [] };
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
        if (u.accountRealm !== 'business') {
            throw new common_1.ForbiddenException('Приглашения в организацию доступны только в бизнес-аккаунте');
        }
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
        try {
            await this.orgService.promoteSoloToOwnerIfNeeded(result);
        }
        catch (e) {
        }
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
        if (u.accountRealm !== 'business') {
            throw new common_1.ForbiddenException('Приглашения в организацию доступны только в бизнес-аккаунте');
        }
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
            const realm = (user.accountRealm ?? 'business');
            const ownerId = await this.findIdByNormalizedPhone(digits, realm);
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
    normalizePhoneForOrdersCompare(phone) {
        const digits = String(phone || '').replace(/\D/g, '');
        if (digits.length === 11 && digits.startsWith('8'))
            return '7' + digits.slice(1);
        return digits;
    }
    async getOrderCarsSummaryForInternalUser(phone) {
        if (!phone)
            return [];
        const norm = this.normalizePhoneForOrdersCompare(phone);
        const rows = await this.orderRepo.find({ order: { dateTime: 'DESC' } });
        const map = new Map();
        for (const o of rows) {
            const p = this.normalizePhoneForOrdersCompare(o.clientPhone || '');
            if (p !== norm)
                continue;
            const carId = String(o.carId || '').trim();
            if (!carId)
                continue;
            if (!map.has(carId)) {
                const dt = o.dateTime;
                map.set(carId, {
                    car_id: carId,
                    car_info: o.carInfo || '',
                    vin: o.vin ?? null,
                    license_plate: o.licensePlate ?? null,
                    car_photo_url: o.carPhotoUrl ?? null,
                    orders_count: 1,
                    last_order_at: dt instanceof Date ? dt.toISOString() : String(dt),
                });
            }
            else {
                map.get(carId).orders_count += 1;
            }
        }
        return [...map.values()].sort((a, b) => b.last_order_at.localeCompare(a.last_order_at));
    }
    async getInternalUserDetail(userId) {
        const user = await this.findById(userId);
        if (!user)
            throw new common_1.NotFoundException('Пользователь не найден');
        const isBusiness = user.organizationId != null || user.role !== 'solo';
        const ROLE_LABELS = {
            owner: 'Владелец',
            admin: 'Администратор',
            master: 'Мастер',
            solo: 'Клиент',
        };
        const cars = await this.getOrderCarsSummaryForInternalUser(user.phone);
        return {
            id: user.id,
            phone: user.phone,
            email: user.email,
            name: user.name,
            role: user.role,
            role_label: ROLE_LABELS[user.role] ?? user.role,
            account_type: isBusiness ? 'business' : 'client',
            account_realm: user.accountRealm ?? 'business',
            organization_id: user.organizationId,
            organization_name: user.organization?.name ?? null,
            avatar_url: user.avatarUrl ?? null,
            cars_from_orders: cars,
        };
    }
    async updateInternalUserDisplayName(userId, name) {
        const user = await this.repo.findOne({ where: { id: userId } });
        if (!user)
            return false;
        const n = name.trim().slice(0, 255);
        if (!n)
            return false;
        user.name = n;
        await this.repo.save(user);
        return true;
    }
    async clearUserAvatar(userId) {
        const user = await this.repo.findOne({ where: { id: userId } });
        if (!user)
            return false;
        const dir = path.join(USER_AVATAR_DIR, userId);
        try {
            if (fs.existsSync(dir))
                fs.rmSync(dir, { recursive: true, force: true });
        }
        catch {
        }
        user.avatarUrl = null;
        await this.repo.save(user);
        return true;
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
    __param(4, (0, typeorm_1.InjectRepository)(chat_entity_1.Chat)),
    __param(5, (0, typeorm_1.InjectRepository)(order_entity_1.Order)),
    __param(6, (0, common_1.Inject)((0, common_1.forwardRef)(() => organizations_service_1.OrganizationsService))),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        organizations_service_1.OrganizationsService,
        typeorm_2.DataSource])
], UsersService);
//# sourceMappingURL=users.service.js.map