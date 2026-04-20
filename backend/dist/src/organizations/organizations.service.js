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
var OrganizationsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const path = require("path");
const fs = require("fs");
const organization_entity_1 = require("./organization.entity");
const organization_subscription_entity_1 = require("./organization-subscription.entity");
const staff_member_entity_1 = require("./staff-member.entity");
const organization_settings_entity_1 = require("./organization-settings.entity");
const organization_business_kind_1 = require("./organization-business-kind");
const organization_scheduling_1 = require("./organization-scheduling");
const master_schedule_entity_1 = require("./master-schedule.entity");
const service_catalog_item_entity_1 = require("../reference/service-catalog-item.entity");
const organization_invitation_entity_1 = require("./organization-invitation.entity");
const subscription_quota_service_1 = require("../subscriptions/subscription-quota.service");
const users_service_1 = require("../users/users.service");
const user_entity_1 = require("../users/user.entity");
const user_organization_membership_entity_1 = require("../users/user-organization-membership.entity");
const notifications_service_1 = require("../notifications/notifications.service");
const transactional_mail_service_1 = require("../mail/transactional-mail.service");
const plan_definitions_1 = require("../subscriptions/plan-definitions");
const ORG_PHOTOS_DIR = path.join(process.cwd(), 'uploads', 'organizations');
const DEFAULT_ORG_INVITE_EXPIRY_DAYS = 14;
let OrganizationsService = OrganizationsService_1 = class OrganizationsService {
    constructor(orgRepo, subRepo, staffRepo, settingsRepo, invitationRepo, scheduleRepo, catalogItemRepo, userRepo, userOrgMembershipRepo, subscriptionQuota, dataSource, usersService, notificationsService, mail) {
        this.orgRepo = orgRepo;
        this.subRepo = subRepo;
        this.staffRepo = staffRepo;
        this.settingsRepo = settingsRepo;
        this.invitationRepo = invitationRepo;
        this.scheduleRepo = scheduleRepo;
        this.catalogItemRepo = catalogItemRepo;
        this.userRepo = userRepo;
        this.userOrgMembershipRepo = userOrgMembershipRepo;
        this.subscriptionQuota = subscriptionQuota;
        this.dataSource = dataSource;
        this.usersService = usersService;
        this.notificationsService = notificationsService;
        this.mail = mail;
        this.log = new common_1.Logger(OrganizationsService_1.name);
    }
    listSubscriptionPlansPublic() {
        return { items: (0, plan_definitions_1.listPublicSubscriptionPlans)() };
    }
    async getPlanKeysForOrganizations(orgIds) {
        if (orgIds.length === 0)
            return {};
        const subs = await this.subRepo.find({ where: { organizationId: (0, typeorm_2.In)(orgIds) } });
        const out = {};
        for (const s of subs) {
            out[s.organizationId] = (0, plan_definitions_1.normalizePlanKey)(s.planKey);
        }
        return out;
    }
    businessKindLabelRu(kind) {
        const k = (0, organization_business_kind_1.normalizeOrganizationBusinessKind)(kind);
        const map = {
            sto: 'СТО',
            car_wash: 'Мойка',
            detailing: 'Детейлинг',
            car_audio: 'Автозвук',
            tire_service: 'Шиномонтаж',
            body_shop: 'Кузовной',
            glass: 'Стёкла',
            tuning: 'Тюнинг',
            ev_service: 'EV-сервис',
            other: 'Сервис',
        };
        return map[k] ?? 'Автосервис';
    }
    async findAll() {
        return this.orgRepo.find({ order: { name: 'ASC' } });
    }
    async findAllSubscriptions() {
        const list = await this.subRepo.find({
            relations: ['organization'],
            order: { endDate: 'DESC' },
        });
        return list.map((s) => ({
            id: s.id,
            organization_id: s.organizationId,
            organization_name: s.organization?.name ?? null,
            start_date: s.startDate instanceof Date ? s.startDate.toISOString().slice(0, 10) : s.startDate,
            end_date: s.endDate instanceof Date ? s.endDate.toISOString().slice(0, 10) : s.endDate,
            is_active: s.isActive,
            status: s.status,
            plan_key: (0, plan_definitions_1.normalizePlanKey)(s.planKey),
            limits_override: s.limitsOverride ?? null,
        }));
    }
    parseLimitsOverridePatch(raw) {
        if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
            throw new common_1.BadRequestException('limits_override должен быть объектом');
        }
        const o = raw;
        const out = {};
        const take = (snake, camel) => {
            if (o[snake] === undefined && o[camel] === undefined)
                return;
            const v = o[snake] !== undefined ? o[snake] : o[camel];
            if (v === null || v === undefined || (typeof v === 'string' && v.trim() === '')) {
                out[camel] = null;
                return;
            }
            const s = (0, plan_definitions_1.sanitizeLimitOverrideValue)(v);
            if (s === undefined) {
                throw new common_1.BadRequestException(`Недопустимое значение лимита: ${snake}`);
            }
            out[camel] = s;
        };
        take('max_active_staff', 'maxActiveStaff');
        take('max_confirmed_orders_per_month', 'maxConfirmedOrdersPerMonth');
        take('max_order_media_attachments', 'maxOrderMediaAttachments');
        take('max_chat_images_per_message', 'maxChatImagesPerMessage');
        return out;
    }
    mergeLimitsOverridePatch(previous, patch) {
        const merged = { ...(previous ?? {}) };
        for (const [k, v] of Object.entries(patch)) {
            if (v === null)
                delete merged[k];
            else
                merged[k] = v;
        }
        return Object.keys(merged).length === 0 ? null : merged;
    }
    async updateSubscription(organizationId, dto) {
        const sub = await this.subRepo.findOne({ where: { organizationId } });
        if (!sub)
            return null;
        const oldKey = (0, plan_definitions_1.normalizePlanKey)(sub.planKey);
        const nextPlanKey = dto.plan_key !== undefined ? (0, plan_definitions_1.normalizePlanKey)(dto.plan_key) : oldKey;
        let nextOverride;
        if (!('limits_override' in dto)) {
            nextOverride = sub.limitsOverride ?? null;
        }
        else if (dto.limits_override === null) {
            nextOverride = null;
        }
        else {
            const patch = this.parseLimitsOverridePatch(dto.limits_override);
            nextOverride = this.mergeLimitsOverridePatch(sub.limitsOverride ?? null, patch);
        }
        const planKeyChanging = dto.plan_key !== undefined && nextPlanKey !== oldKey;
        if (dto.plan_key !== undefined || 'limits_override' in dto) {
            const mergedNext = (0, plan_definitions_1.mergePlanLimitsWithOverride)((0, plan_definitions_1.getPlanLimits)(nextPlanKey), nextOverride);
            const effMaxStaff = mergedNext.maxActiveStaff;
            if (effMaxStaff !== null) {
                const activeCount = await this.subscriptionQuota.countActiveStaff(organizationId);
                if (activeCount > effMaxStaff) {
                    if (planKeyChanging) {
                        const staffRows = await this.staffRepo.find({
                            where: { organizationId },
                            order: { name: 'ASC' },
                        });
                        throw new common_1.ConflictException({
                            code: 'STAFF_DOWNGRADE_REQUIRED',
                            message: `Активных сотрудников: ${activeCount}, эффективный лимит при тарифе «${nextPlanKey}»: ${effMaxStaff}. Используйте apply-plan-with-staff или увеличьте лимит в переопределении.`,
                            organization_id: organizationId,
                            current_plan_key: oldKey,
                            requested_plan_key: nextPlanKey,
                            max_active_staff: effMaxStaff,
                            active_staff_count: activeCount,
                            staff: staffRows.map((s) => ({
                                id: s.id,
                                name: s.name,
                                role: s.role,
                                is_active: s.isActive !== false,
                            })),
                        });
                    }
                    throw new common_1.BadRequestException(`Активных сотрудников: ${activeCount}, эффективный лимит: ${effMaxStaff}. Уменьшите активных или увеличьте лимит.`);
                }
            }
        }
        if (dto.is_active !== undefined)
            sub.isActive = dto.is_active;
        if (dto.status !== undefined)
            sub.status = dto.status;
        if (dto.plan_key !== undefined)
            sub.planKey = nextPlanKey;
        if ('limits_override' in dto)
            sub.limitsOverride = nextOverride;
        await this.subRepo.save(sub);
        return sub;
    }
    async applySubscriptionPlanWithActiveStaff(organizationId, dto) {
        const newKey = (0, plan_definitions_1.normalizePlanKey)(dto.plan_key);
        const subRow = await this.subRepo.findOne({ where: { organizationId } });
        const merged = (0, plan_definitions_1.mergePlanLimitsWithOverride)((0, plan_definitions_1.getPlanLimits)(newKey), subRow?.limitsOverride ?? null);
        const max = merged.maxActiveStaff;
        const keep = [...new Set((dto.keep_active_staff_ids ?? []).map((x) => String(x).trim()).filter(Boolean))];
        if (max !== null && keep.length > max) {
            throw new common_1.BadRequestException(`Можно оставить активными не более ${max} сотрудник(ов) для тарифа «${newKey}».`);
        }
        const allStaff = await this.staffRepo.find({ where: { organizationId } });
        const idSet = new Set(allStaff.map((s) => s.id));
        for (const sid of keep) {
            if (!idSet.has(sid)) {
                throw new common_1.BadRequestException(`Сотрудник не найден в организации: ${sid}`);
            }
        }
        await this.dataSource.transaction(async (em) => {
            for (const s of allStaff) {
                const active = keep.includes(s.id);
                if (s.isActive !== active) {
                    await em.update(staff_member_entity_1.StaffMember, { id: s.id, organizationId }, { isActive: active });
                }
            }
            const sub = await em.findOne(organization_subscription_entity_1.OrganizationSubscription, { where: { organizationId } });
            if (!sub) {
                throw new common_1.BadRequestException('Подписка организации не найдена');
            }
            sub.planKey = newKey;
            await em.save(sub);
        });
        return this.getSubscriptionUsageSummary(organizationId);
    }
    async getSubscriptionUsageSummary(organizationId) {
        return this.subscriptionQuota.getSubscriptionUsageSummary(organizationId);
    }
    async isSubscriptionActive(organizationId) {
        const sub = await this.subRepo.findOne({ where: { organizationId } });
        if (!sub)
            return true;
        if (!sub.isActive)
            return false;
        if (sub.status === 'deactivated' || sub.status === 'expired')
            return false;
        if (sub.endDate && new Date(sub.endDate) < new Date())
            return false;
        return true;
    }
    async findOne(id) {
        return this.orgRepo.findOne({ where: { id } });
    }
    async createOrganizationWithDefaults(dto) {
        const org = this.orgRepo.create({
            name: (dto.name && dto.name.trim()) || 'Новая организация',
            address: dto.address != null ? String(dto.address).trim() : '',
            phone: dto.phone != null ? String(dto.phone).trim() : '',
            workingHours: 'Пн–Пт 9:00–19:00',
            timezone: 'Europe/Moscow',
        });
        await this.orgRepo.save(org);
        const startDate = new Date();
        const endDate = new Date(startDate);
        endDate.setFullYear(endDate.getFullYear() + 1);
        const planKey = (0, plan_definitions_1.normalizePlanKey)(dto.plan_key);
        const sub = this.subRepo.create({
            organizationId: org.id,
            startDate,
            endDate,
            isActive: true,
            status: 'active',
            planKey,
            limitsOverride: null,
        });
        await this.subRepo.save(sub);
        const settings = this.settingsRepo.create({ organizationId: org.id, data: {} });
        await this.settingsRepo.save(settings);
        return org;
    }
    async update(id, dto) {
        const updateData = {};
        if (dto.name != null)
            updateData['name'] = dto.name;
        if (dto.address != null)
            updateData['address'] = dto.address;
        if (dto.phone != null)
            updateData['phone'] = dto.phone;
        if (dto.working_hours != null)
            updateData['workingHours'] = dto.working_hours;
        if (dto.timezone != null)
            updateData['timezone'] = dto.timezone;
        if (dto.latitude !== undefined)
            updateData['latitude'] = dto.latitude;
        if (dto.longitude !== undefined)
            updateData['longitude'] = dto.longitude;
        if (dto.business_kind != null) {
            const nk = (0, organization_business_kind_1.normalizeOrganizationBusinessKind)(dto.business_kind);
            updateData['businessKind'] = nk;
            if (dto.scheduling_mode == null) {
                updateData['schedulingMode'] = (0, organization_scheduling_1.defaultSchedulingModeForBusinessKind)(nk);
            }
        }
        if (dto.scheduling_mode != null) {
            updateData['schedulingMode'] = (0, organization_scheduling_1.normalizeSchedulingMode)(dto.scheduling_mode);
        }
        if (Object.keys(updateData).length > 0) {
            await this.orgRepo.update(id, updateData);
        }
        return this.orgRepo.findOne({ where: { id } });
    }
    async getStaff(orgId) {
        const list = await this.staffRepo.find({
            where: { organizationId: orgId },
            relations: ['schedule'],
            order: { invitedAt: 'DESC' },
        });
        return { items: list.map((s) => this._staffToItem(s)) };
    }
    ensureCallerCanManageOrganizationStaff(caller) {
        this.assertCanManageOrganizationStaff(caller);
    }
    assertCanManageOrganizationStaff(caller) {
        if (caller.role === 'master') {
            throw new common_1.ForbiddenException('Управление персоналом и приглашениями доступно владельцу, администратору или самозанятому.');
        }
    }
    async getStaffForCaller(orgId, caller) {
        await this.ensureSoloStaffMember(orgId, caller);
        await this.promoteSoloToOwnerIfNeeded(orgId);
        if (caller.role === 'master') {
            const byUser = await this.staffRepo.find({
                where: { organizationId: orgId, userId: caller.id },
                relations: ['schedule'],
                order: { invitedAt: 'DESC' },
            });
            if (byUser.length > 0) {
                return { items: byUser.map((s) => this._staffToItem(s)) };
            }
            const p = this.normalizePhoneLoose(caller.phone);
            if (p) {
                const all = await this.staffRepo.find({
                    where: { organizationId: orgId },
                    relations: ['schedule'],
                    order: { invitedAt: 'DESC' },
                });
                const matched = all.filter((s) => this.normalizePhoneLoose(s.phone) === p);
                return { items: matched.map((s) => this._staffToItem(s)) };
            }
            return { items: [] };
        }
        return this.getStaff(orgId);
    }
    async promoteSoloToOwnerIfNeeded(orgId) {
        await this.promoteSoloToOwner(orgId);
    }
    async countActiveMasters(orgId) {
        return this.staffRepo.count({
            where: { organizationId: orgId, isActive: true, role: 'master' },
        });
    }
    async isSoloSingleMasterOrg(orgId) {
        const solo = await this.userRepo.findOne({ where: { organizationId: orgId, role: 'solo' } });
        if (!solo)
            return false;
        const n = await this.countActiveMasters(orgId);
        return n === 1;
    }
    parseHHMMToMinutes(raw) {
        const m = String(raw || '09:00').match(/^(\d{1,2}):(\d{2})$/);
        if (!m)
            return 9 * 60;
        const h = Math.min(23, Math.max(0, parseInt(m[1], 10)));
        const min = Math.min(59, Math.max(0, parseInt(m[2], 10)));
        return h * 60 + min;
    }
    formatMinutesAsHHMM(mins) {
        const h = Math.floor(mins / 60) % 24;
        const m = mins % 60;
        return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
    }
    async syncOrgSlotsFromMasterSchedule(orgId, slots) {
        const working = slots.filter((s) => s.is_working_day !== false);
        if (working.length === 0)
            return;
        let minM = 24 * 60;
        let maxM = 0;
        for (const s of working) {
            const st = s.start_time != null ? String(s.start_time).slice(0, 5) : '09:00';
            const en = s.end_time != null ? String(s.end_time).slice(0, 5) : '18:00';
            minM = Math.min(minM, this.parseHHMMToMinutes(st));
            maxM = Math.max(maxM, this.parseHHMMToMinutes(en));
        }
        if (maxM <= minM)
            return;
        let row = await this.settingsRepo.findOne({ where: { organizationId: orgId } });
        if (!row) {
            row = this.settingsRepo.create({ organizationId: orgId, data: {} });
        }
        const data = { ...(typeof row.data === 'object' && row.data !== null ? row.data : {}) };
        const prevSlots = typeof data.slots === 'object' && data.slots !== null ? { ...data.slots } : {};
        data.slots = {
            ...prevSlots,
            work_day_start: this.formatMinutesAsHHMM(minM),
            work_day_end: this.formatMinutesAsHHMM(maxM),
        };
        row.data = data;
        await this.settingsRepo.save(row);
    }
    async syncSoloMasterTimesFromOrgSlots(orgId, slots) {
        if (!(await this.isSoloSingleMasterOrg(orgId)))
            return;
        const ws = String(slots['work_day_start'] ?? slots['workDayStart'] ?? '09:00').slice(0, 5);
        const we = String(slots['work_day_end'] ?? slots['workDayEnd'] ?? '18:00').slice(0, 5);
        const masters = await this.staffRepo.find({
            where: { organizationId: orgId, isActive: true, role: 'master' },
        });
        if (masters.length !== 1)
            return;
        const masterId = masters[0].id;
        const rows = await this.scheduleRepo.find({ where: { masterId } });
        for (const sch of rows) {
            if (!sch.isWorkingDay)
                continue;
            sch.startTime = /^\d{1,2}:\d{2}$/.test(ws) ? ws : '09:00';
            sch.endTime = /^\d{1,2}:\d{2}$/.test(we) ? we : '18:00';
            await this.scheduleRepo.save(sch);
        }
    }
    async ensureSoloStaffMember(orgId, caller) {
        if (caller.role !== 'solo' || caller.organizationId !== orgId)
            return;
        const existing = await this.staffRepo.findOne({ where: { organizationId: orgId, userId: caller.id } });
        if (existing)
            return;
        const settings = await this.getSettings(orgId);
        const slots = settings.slots ?? {};
        const ws = String(slots['work_day_start'] ?? slots['workDayStart'] ?? '09:00').slice(0, 5);
        const we = String(slots['work_day_end'] ?? slots['workDayEnd'] ?? '18:00').slice(0, 5);
        const startT = /^\d{1,2}:\d{2}$/.test(ws) ? ws : '09:00';
        const endT = /^\d{1,2}:\d{2}$/.test(we) ? we : '18:00';
        const staff = this.staffRepo.create({
            organizationId: orgId,
            userId: caller.id,
            name: caller.name || 'Мастер',
            phone: caller.phone || null,
            role: 'master',
            isActive: true,
            invitedAt: new Date(),
            skills: [],
        });
        await this.staffRepo.save(staff);
        for (let dow = 0; dow <= 6; dow++) {
            const working = dow >= 1 && dow <= 5;
            const row = this.scheduleRepo.create({
                masterId: staff.id,
                dayOfWeek: dow,
                startTime: startT,
                endTime: endT,
                isWorkingDay: working,
            });
            await this.scheduleRepo.save(row);
        }
        this.log.log(`ensureSoloStaffMember: created staff ${staff.id} for solo user ${caller.id} org ${orgId}`);
    }
    async promoteSoloToOwner(orgId) {
        const n = await this.countActiveMasters(orgId);
        if (n < 2)
            return;
        const soloUsers = await this.userRepo.find({ where: { organizationId: orgId, role: 'solo' } });
        for (const u of soloUsers) {
            u.role = 'owner';
            await this.userRepo.save(u);
        }
        const memberships = await this.userOrgMembershipRepo.find({
            where: { organizationId: orgId, role: 'solo' },
        });
        for (const m of memberships) {
            m.role = 'owner';
            await this.userOrgMembershipRepo.save(m);
        }
        if (soloUsers.length > 0) {
            this.log.log(`promoteSoloToOwner: org ${orgId} now has ${n} masters; promoted ${soloUsers.length} solo user(s) to owner`);
        }
    }
    async addCurrentUserAsMaster(orgId, user) {
        if (user.role === 'master') {
            throw new common_1.ForbiddenException('Мастер не может управлять составом персонала.');
        }
        if (user.organizationId !== orgId) {
            throw new common_1.BadRequestException('Пользователь не принадлежит этой организации');
        }
        const existing = await this.staffRepo.findOne({
            where: { organizationId: orgId, userId: user.id },
        });
        if (existing) {
            throw new common_1.ConflictException('Вы уже добавлены как мастер в этой организации');
        }
        const staff = this.staffRepo.create({
            organizationId: orgId,
            userId: user.id,
            name: user.name || 'Мастер',
            phone: user.phone || null,
            role: 'master',
            isActive: true,
            invitedAt: new Date(),
            skills: [],
        });
        await this.staffRepo.save(staff);
        const withSchedule = await this.staffRepo.findOne({
            where: { id: staff.id },
            relations: ['schedule'],
        });
        await this.promoteSoloToOwnerIfNeeded(orgId);
        return this._staffToItem(withSchedule);
    }
    _staffToItem(s) {
        const caps = s;
        return {
            id: s.id,
            user_id: s.userId ?? null,
            name: s.name,
            phone: s.phone,
            email: s.email ?? null,
            role: s.role,
            is_active: s.isActive !== false,
            invited_at: s.invitedAt?.toISOString?.(),
            skills: Array.isArray(s.skills) ? s.skills : [],
            can_see_chats: caps.canSeeChats === true,
            can_write_chats: caps.canWriteChats === true,
            can_manage_org_settings: caps.canManageOrgSettings === true,
            schedule: Array.isArray(s.schedule)
                ? s.schedule.map((sch) => ({
                    id: sch.id,
                    day_of_week: sch.dayOfWeek,
                    start_time: sch.startTime,
                    end_time: sch.endTime,
                    is_working_day: sch.isWorkingDay,
                }))
                : [],
        };
    }
    normalizePhoneLoose(raw) {
        if (!raw)
            return null;
        const d = String(raw).replace(/\D/g, '');
        if (!d)
            return null;
        if (d.length === 11 && d.startsWith('8'))
            return '7' + d.slice(1);
        if (d.length === 10 && !d.startsWith('7'))
            return '7' + d;
        return d;
    }
    normalizeEmail(raw) {
        if (!raw)
            return null;
        const v = String(raw).trim().toLowerCase();
        return v || null;
    }
    invitationToItem(inv) {
        return {
            id: inv.id,
            organization_id: inv.organizationId,
            invited_by_user_id: inv.invitedByUserId,
            accepted_by_user_id: inv.acceptedByUserId,
            staff_member_id: inv.staffMemberId,
            role: inv.role,
            invited_name: inv.invitedName,
            invited_email: inv.invitedEmail,
            invited_phone: inv.invitedPhone,
            status: inv.status,
            message: inv.message,
            expires_at: inv.expiresAt?.toISOString() ?? null,
            responded_at: inv.respondedAt?.toISOString() ?? null,
            created_at: inv.createdAt?.toISOString() ?? null,
            updated_at: inv.updatedAt?.toISOString() ?? null,
            organization_name: inv.organization?.name ?? null,
        };
    }
    async dispatchInvitationSideEffects(inv, invitedByUserId) {
        const orgName = inv.organization?.name ?? 'Организация';
        const recipientId = await this.usersService.findUserIdForInviteContact(inv.invitedEmailNorm, inv.invitedPhoneNorm);
        if (recipientId) {
            await this.notificationsService.notifyOrganizationInvite({
                userId: recipientId,
                organizationName: orgName,
                role: inv.role,
                invitationId: inv.id,
                organizationId: inv.organizationId,
            });
        }
        const toEmail = inv.invitedEmail?.trim();
        if (toEmail && this.mail.isConfigured()) {
            const inviter = await this.usersService.findById(invitedByUserId);
            const inviterName = inviter?.name?.trim() || 'Сотрудник';
            const expiresText = inv.expiresAt
                ? `Срок действия: до ${inv.expiresAt.toISOString().slice(0, 10)} (UTC).`
                : '';
            const text = [
                'Здравствуйте!',
                '',
                `${inviterName} приглашает вас в организацию «${orgName}» (роль: ${inv.role}).`,
                expiresText,
                '',
                'Откройте приложение MP-Servis Business, войдите под этим email и перейдите: Профиль → Входящие приглашения.',
                '',
                '— MP-Servis',
            ]
                .filter((line) => line !== '')
                .join('\n');
            try {
                await this.mail.send({
                    to: toEmail,
                    subject: `Приглашение в «${orgName}» — MP-Servis`,
                    text,
                });
            }
            catch (e) {
                this.log.warn(`Не удалось отправить письмо с приглашением: ${e}`);
            }
        }
    }
    async createInvitation(orgId, caller, dto) {
        this.assertCanManageOrganizationStaff(caller);
        const invitedByUserId = caller.id;
        const emailNorm = this.normalizeEmail(dto.email);
        const phoneNorm = this.normalizePhoneLoose(dto.phone);
        if (!emailNorm && !phoneNorm) {
            throw new common_1.BadRequestException('Укажите email и/или телефон');
        }
        await this.subscriptionQuota.assertCanAddOrActivateStaff(orgId);
        if (emailNorm) {
            const dup = await this.invitationRepo.findOne({
                where: { organizationId: orgId, invitedEmailNorm: emailNorm, status: 'pending' },
            });
            if (dup)
                throw new common_1.ConflictException('Приглашение на этот email уже отправлено и ожидает подтверждения');
        }
        if (phoneNorm) {
            const dup = await this.invitationRepo.findOne({
                where: { organizationId: orgId, invitedPhoneNorm: phoneNorm, status: 'pending' },
            });
            if (dup)
                throw new common_1.ConflictException('Приглашение на этот телефон уже отправлено и ожидает подтверждения');
        }
        const expiresInDays = Number(dto.expires_in_days);
        const expiresAt = Number.isFinite(expiresInDays) && expiresInDays > 0
            ? new Date(Date.now() + Math.floor(expiresInDays) * 24 * 60 * 60 * 1000)
            : new Date(Date.now() + DEFAULT_ORG_INVITE_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
        const row = this.invitationRepo.create({
            organizationId: orgId,
            invitedByUserId,
            role: String(dto.role || 'master'),
            invitedName: dto.name?.trim() || null,
            invitedEmail: dto.email?.trim() || null,
            invitedEmailNorm: emailNorm,
            invitedPhone: dto.phone?.trim() || null,
            invitedPhoneNorm: phoneNorm,
            message: dto.message?.trim() || null,
            status: 'pending',
            expiresAt,
            respondedAt: null,
            acceptedByUserId: null,
            staffMemberId: null,
        });
        await this.invitationRepo.save(row);
        const fresh = await this.invitationRepo.findOne({
            where: { id: row.id },
            relations: ['organization'],
        });
        if (fresh) {
            void this.dispatchInvitationSideEffects(fresh, invitedByUserId).catch((e) => this.log.warn(String(e)));
        }
        return this.invitationToItem(fresh);
    }
    async listInvitations(orgId, caller, status) {
        this.assertCanManageOrganizationStaff(caller);
        const qb = this.invitationRepo
            .createQueryBuilder('inv')
            .leftJoinAndSelect('inv.organization', 'org')
            .where('inv.organization_id = :orgId', { orgId })
            .orderBy('inv.created_at', 'DESC');
        if (status) {
            qb.andWhere('inv.status = :status', { status });
        }
        if (status === 'pending') {
            qb.andWhere('(inv.expires_at IS NULL OR inv.expires_at > :now)', { now: new Date() });
        }
        const rows = await qb.getMany();
        return { items: rows.map((x) => this.invitationToItem(x)) };
    }
    async cancelInvitation(orgId, invitationId, caller) {
        this.assertCanManageOrganizationStaff(caller);
        const inv = await this.invitationRepo.findOne({ where: { id: invitationId, organizationId: orgId } });
        if (!inv) {
            throw new common_1.BadRequestException('Приглашение не найдено');
        }
        if (inv.status !== 'pending') {
            throw new common_1.BadRequestException('Можно отменить только приглашение в статусе pending');
        }
        inv.status = 'cancelled';
        inv.respondedAt = new Date();
        await this.invitationRepo.save(inv);
        const fresh = await this.invitationRepo.findOne({ where: { id: invitationId }, relations: ['organization'] });
        return this.invitationToItem(fresh);
    }
    async inviteStaff(orgId, dto) {
        await this.subscriptionQuota.assertCanAddOrActivateStaff(orgId);
        const s = this.staffRepo.create({ ...dto, organizationId: orgId, invitedAt: new Date() });
        await this.staffRepo.save(s);
        const isAdmin = String(dto.role).toLowerCase() === 'admin';
        await this.staffRepo.update({ id: s.id }, {
            canSeeChats: isAdmin,
            canWriteChats: isAdmin,
            canManageOrgSettings: isAdmin,
        });
        const withSchedule = await this.staffRepo.findOne({ where: { id: s.id }, relations: ['schedule'] });
        return withSchedule ? this._staffToItem(withSchedule) : this._staffToItem(s);
    }
    async updateStaffMember(orgId, staffId, dto, caller) {
        this.assertCanManageOrganizationStaff(caller);
        const staff = await this.staffRepo.findOne({ where: { id: staffId, organizationId: orgId }, relations: ['schedule'] });
        if (!staff)
            return null;
        const newRole = dto.role !== undefined ? String(dto.role) : staff.role;
        const scheduleFromDto = Array.isArray(dto.schedule) ? dto.schedule : null;
        const effectiveSchedule = scheduleFromDto ?? staff.schedule ?? [];
        const wasActive = staff.isActive !== false;
        if (dto.is_active === true && !wasActive) {
            await this.subscriptionQuota.assertCanAddOrActivateStaff(orgId, staffId);
        }
        if (newRole === 'master') {
            const workingSlots = scheduleFromDto
                ? scheduleFromDto.filter((slot) => slot.is_working_day !== false)
                : (Array.isArray(staff.schedule) ? staff.schedule : []).filter((sch) => sch.isWorkingDay);
            if (workingSlots.length === 0) {
                throw new common_1.BadRequestException('У мастера должен быть указан график работы: выберите хотя бы один рабочий день');
            }
        }
        const setObj = {};
        if (dto.name !== undefined)
            setObj.name = String(dto.name);
        if (dto.phone !== undefined)
            setObj.phone = dto.phone === null ? null : String(dto.phone);
        if (dto.email !== undefined)
            setObj.email = dto.email === null ? null : String(dto.email);
        if (dto.role !== undefined)
            setObj.role = String(dto.role);
        if (dto.is_active !== undefined)
            setObj.isActive = Boolean(dto.is_active);
        if (Array.isArray(dto.skills))
            setObj.skills = dto.skills;
        if (dto.can_see_chats !== undefined)
            setObj.canSeeChats = Boolean(dto.can_see_chats);
        if (dto.can_write_chats !== undefined)
            setObj.canWriteChats = Boolean(dto.can_write_chats);
        if (dto.can_manage_org_settings !== undefined)
            setObj.canManageOrgSettings = Boolean(dto.can_manage_org_settings);
        try {
            if (Object.keys(setObj).length > 0) {
                await this.staffRepo.update({ id: staffId, organizationId: orgId }, setObj);
            }
            if (Array.isArray(dto.schedule)) {
                await this.scheduleRepo.delete({ masterId: staffId });
                const slots = dto.schedule;
                for (const slot of slots) {
                    const dayOfWeek = Number(slot.day_of_week);
                    if (Number.isNaN(dayOfWeek) || dayOfWeek < 0 || dayOfWeek > 6)
                        continue;
                    const startTime = slot.start_time != null ? String(slot.start_time).slice(0, 5) : '09:00';
                    const endTime = slot.end_time != null ? String(slot.end_time).slice(0, 5) : '18:00';
                    const row = this.scheduleRepo.create({
                        masterId: staffId,
                        dayOfWeek,
                        startTime: /^\d{1,2}:\d{2}$/.test(startTime) ? startTime : '09:00',
                        endTime: /^\d{1,2}:\d{2}$/.test(endTime) ? endTime : '18:00',
                        isWorkingDay: slot.is_working_day !== false,
                    });
                    await this.scheduleRepo.save(row);
                }
            }
        }
        catch (err) {
            if (err instanceof common_1.BadRequestException)
                throw err;
            throw new common_1.BadRequestException(err?.message ?? 'Не удалось обновить сотрудника');
        }
        const s = await this.staffRepo.findOne({ where: { id: staffId }, relations: ['schedule'] });
        if (!s)
            return null;
        if (Array.isArray(dto.schedule) && (await this.isSoloSingleMasterOrg(orgId))) {
            try {
                await this.syncOrgSlotsFromMasterSchedule(orgId, dto.schedule);
            }
            catch (e) {
                this.log.warn(`syncOrgSlotsFromMasterSchedule: ${e}`);
            }
        }
        await this.promoteSoloToOwnerIfNeeded(orgId);
        return this._staffToItem(s);
    }
    async getSettings(orgId) {
        let row = await this.settingsRepo.findOne({ where: { organizationId: orgId } });
        if (!row) {
            row = this.settingsRepo.create({ organizationId: orgId, data: {} });
            await this.settingsRepo.save(row);
        }
        const data = row.data;
        if (data === null || typeof data !== 'object')
            return {};
        const out = data;
        return {
            ...out,
            categories: Array.isArray(out.categories) ? out.categories : [],
            services: Array.isArray(out.services) ? out.services : [],
        };
    }
    async updateSettings(orgId, data) {
        await this.assertServicesAllowedForOrganizationKind(orgId, data);
        let row = await this.settingsRepo.findOne({ where: { organizationId: orgId } });
        if (!row) {
            row = this.settingsRepo.create({ organizationId: orgId, data });
            await this.settingsRepo.save(row);
        }
        else {
            row.data = data;
            await this.settingsRepo.save(row);
        }
        const slotsPatch = data['slots'];
        if (slotsPatch && typeof slotsPatch === 'object') {
            try {
                await this.syncSoloMasterTimesFromOrgSlots(orgId, slotsPatch);
            }
            catch (e) {
                this.log.warn(`syncSoloMasterTimesFromOrgSlots: ${e}`);
            }
        }
        return row.data;
    }
    async assertServicesAllowedForOrganizationKind(orgId, data) {
        const org = await this.orgRepo.findOne({ where: { id: orgId } });
        if (!org)
            return;
        const kind = (0, organization_business_kind_1.normalizeOrganizationBusinessKind)(org.businessKind);
        const services = data['services'];
        if (!Array.isArray(services))
            return;
        const catalogIds = [];
        for (const s of services) {
            if (s && typeof s === 'object' && 'id' in s) {
                const id = String(s.id ?? '');
                if (id.startsWith('svc_'))
                    catalogIds.push(id);
            }
        }
        if (catalogIds.length === 0)
            return;
        const rows = await this.catalogItemRepo.find({ where: { id: (0, typeorm_2.In)(catalogIds) } });
        const byId = new Map(rows.map((r) => [r.id, r]));
        for (const id of catalogIds) {
            const row = byId.get(id);
            if (!row) {
                throw new common_1.BadRequestException(`Неизвестная позиция справочника (${id}). Выберите услугу из актуального каталога или уберите эту строку.`);
            }
            const allowed = Array.isArray(row.allowedBusinessKinds) ? row.allowedBusinessKinds : ['sto'];
            if (!allowed.includes(kind)) {
                throw new common_1.BadRequestException(`Услуга «${row.name}» из справочника недоступна для типа организации «${this.businessKindLabelRu(kind)}». Выберите другой тип точки в настройках или уберите услугу.`);
            }
        }
    }
    async addPhoto(orgId, file) {
        const org = await this.orgRepo.findOne({ where: { id: orgId } });
        if (!org)
            return null;
        const dir = path.join(ORG_PHOTOS_DIR, orgId);
        if (!fs.existsSync(dir))
            fs.mkdirSync(dir, { recursive: true });
        const ext = path.extname(file.originalname) || '.jpg';
        const filename = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
        const filePath = path.join(dir, filename);
        if (file.buffer?.length) {
            fs.writeFileSync(filePath, file.buffer);
        }
        else if (file.path && fs.existsSync(file.path)) {
            fs.copyFileSync(file.path, filePath);
        }
        else {
            return null;
        }
        const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
        const url = `${baseUrl}/organizations/${orgId}/photos/${filename}`;
        const photoUrls = Array.isArray(org.photoUrls) ? [...org.photoUrls] : [];
        photoUrls.push(url);
        await this.orgRepo.update(orgId, { photoUrls });
        return { url };
    }
    async removePhoto(orgId, photoUrlOrInput) {
        const org = await this.orgRepo.findOne({ where: { id: orgId } });
        if (!org)
            return false;
        const urls = this.getPhotoUrls(org);
        if (urls.length === 0)
            return false;
        const input = photoUrlOrInput.trim().split('?')[0];
        if (!input)
            return false;
        const inputBase = path.basename(input);
        if (!inputBase || inputBase === '.' || inputBase === '..' || inputBase.includes('..')) {
            return false;
        }
        const idx = urls.findIndex((stored) => {
            const u = stored.trim().split('?')[0];
            if (u === input)
                return true;
            const base = path.basename(u);
            return base === inputBase && u.includes(`/organizations/${orgId}/photos/`);
        });
        if (idx < 0)
            return false;
        const removed = urls[idx];
        const filename = path.basename(removed.split('?')[0]);
        if (!filename || filename.includes('..'))
            return false;
        const newUrls = urls.filter((_, i) => i !== idx);
        const fullPath = path.join(ORG_PHOTOS_DIR, orgId, filename);
        try {
            if (fs.existsSync(fullPath))
                fs.unlinkSync(fullPath);
        }
        catch {
        }
        await this.orgRepo.update(orgId, { photoUrls: newUrls });
        return true;
    }
    async getPhotoPath(orgId, filename) {
        const org = await this.orgRepo.findOne({ where: { id: orgId } });
        if (!org)
            return null;
        const fullPath = path.join(ORG_PHOTOS_DIR, orgId, filename);
        if (!fs.existsSync(fullPath))
            return null;
        return fullPath;
    }
    getPhotoUrls(org) {
        const urls = org.photoUrls;
        return Array.isArray(urls) ? urls : [];
    }
    async clearAllOrganizationPhotos(orgId) {
        const org = await this.orgRepo.findOne({ where: { id: orgId } });
        if (!org)
            return false;
        const urls = [...this.getPhotoUrls(org)];
        for (const u of urls) {
            await this.removePhoto(orgId, u);
        }
        return true;
    }
};
exports.OrganizationsService = OrganizationsService;
exports.OrganizationsService = OrganizationsService = OrganizationsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(organization_entity_1.Organization)),
    __param(1, (0, typeorm_1.InjectRepository)(organization_subscription_entity_1.OrganizationSubscription)),
    __param(2, (0, typeorm_1.InjectRepository)(staff_member_entity_1.StaffMember)),
    __param(3, (0, typeorm_1.InjectRepository)(organization_settings_entity_1.OrganizationSettings)),
    __param(4, (0, typeorm_1.InjectRepository)(organization_invitation_entity_1.OrganizationInvitation)),
    __param(5, (0, typeorm_1.InjectRepository)(master_schedule_entity_1.MasterSchedule)),
    __param(6, (0, typeorm_1.InjectRepository)(service_catalog_item_entity_1.ServiceCatalogItem)),
    __param(7, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(8, (0, typeorm_1.InjectRepository)(user_organization_membership_entity_1.UserOrganizationMembership)),
    __param(11, (0, common_1.Inject)((0, common_1.forwardRef)(() => users_service_1.UsersService))),
    __param(12, (0, common_1.Inject)((0, common_1.forwardRef)(() => notifications_service_1.NotificationsService))),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        subscription_quota_service_1.SubscriptionQuotaService,
        typeorm_2.DataSource,
        users_service_1.UsersService,
        notifications_service_1.NotificationsService,
        transactional_mail_service_1.TransactionalMailService])
], OrganizationsService);
//# sourceMappingURL=organizations.service.js.map