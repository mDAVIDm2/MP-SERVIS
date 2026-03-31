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
exports.SubscriptionQuotaService = void 0;
exports.subscriptionLimitsToSnake = subscriptionLimitsToSnake;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const luxon_1 = require("luxon");
const order_entity_1 = require("../orders/order.entity");
const organization_entity_1 = require("../organizations/organization.entity");
const organization_subscription_entity_1 = require("../organizations/organization-subscription.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const plan_definitions_1 = require("./plan-definitions");
function subscriptionLimitsToSnake(l) {
    return {
        max_active_staff: l.maxActiveStaff,
        max_confirmed_orders_per_month: l.maxConfirmedOrdersPerMonth,
        max_order_media_attachments: l.maxOrderMediaAttachments,
        max_chat_images_per_message: l.maxChatImagesPerMessage,
    };
}
let SubscriptionQuotaService = class SubscriptionQuotaService {
    constructor(orderRepo, orgRepo, subRepo, staffRepo) {
        this.orderRepo = orderRepo;
        this.orgRepo = orgRepo;
        this.subRepo = subRepo;
        this.staffRepo = staffRepo;
    }
    async getPlanKeyForOrganization(organizationId) {
        const sub = await this.subRepo.findOne({ where: { organizationId } });
        return (0, plan_definitions_1.normalizePlanKey)(sub?.planKey);
    }
    async getLimitsForOrganization(organizationId) {
        const sub = await this.getSubscription(organizationId);
        const key = (0, plan_definitions_1.normalizePlanKey)(sub?.planKey);
        const base = (0, plan_definitions_1.getPlanLimits)(key);
        return (0, plan_definitions_1.mergePlanLimitsWithOverride)(base, sub?.limitsOverride ?? null);
    }
    async isSoloPlan(organizationId) {
        const key = await this.getPlanKeyForOrganization(organizationId);
        return key === 'solo';
    }
    isSubscriptionRecordActive(sub) {
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
    async getSubscription(organizationId) {
        return this.subRepo.findOne({ where: { organizationId } });
    }
    async assertSubscriptionAllowsWrites(organizationId) {
        const sub = await this.getSubscription(organizationId);
        if (!this.isSubscriptionRecordActive(sub)) {
            throw new common_1.BadRequestException('Подписка организации неактивна или истекла. Продлите подписку, чтобы продолжить работу.');
        }
    }
    async getBillingMonthUtcRange(organizationId, now = new Date()) {
        const org = await this.orgRepo.findOne({ where: { id: organizationId }, select: ['id', 'timezone'] });
        const zone = org?.timezone && String(org.timezone).trim() ? String(org.timezone).trim() : 'Europe/Moscow';
        const localNow = luxon_1.DateTime.fromJSDate(now, { zone: 'utc' }).setZone(zone);
        const startLocal = localNow.startOf('month');
        const endLocal = startLocal.plus({ months: 1 });
        return {
            startUtc: startLocal.toUTC().toJSDate(),
            endExclusiveUtc: endLocal.toUTC().toJSDate(),
        };
    }
    async countConfirmedOrdersInBillingMonth(organizationId, now) {
        const { startUtc, endExclusiveUtc } = await this.getBillingMonthUtcRange(organizationId, now);
        return this.orderRepo
            .createQueryBuilder('o')
            .where('o.organization_id = :orgId', { orgId: organizationId })
            .andWhere('o.first_confirmed_at IS NOT NULL')
            .andWhere('o.first_confirmed_at >= :start', { start: startUtc })
            .andWhere('o.first_confirmed_at < :end', { end: endExclusiveUtc })
            .getCount();
    }
    async assertCanConsumeConfirmedOrderSlot(organizationId) {
        await this.assertSubscriptionAllowsWrites(organizationId);
        const limits = await this.getLimitsForOrganization(organizationId);
        const max = limits.maxConfirmedOrdersPerMonth;
        if (max == null)
            return;
        const used = await this.countConfirmedOrdersInBillingMonth(organizationId);
        if (used >= max) {
            throw new common_1.BadRequestException('Достигнут лимит подтверждённых записей по тарифу на этот месяц. Обновите тариф или дождитесь следующего расчётного периода.');
        }
    }
    async countActiveStaff(organizationId) {
        return this.staffRepo.count({
            where: { organizationId, isActive: true },
        });
    }
    async assertCanAddOrActivateStaff(organizationId, excludeStaffId) {
        await this.assertSubscriptionAllowsWrites(organizationId);
        const limits = await this.getLimitsForOrganization(organizationId);
        const max = limits.maxActiveStaff;
        if (max == null)
            return;
        const qb = this.staffRepo
            .createQueryBuilder('s')
            .where('s.organization_id = :orgId', { orgId: organizationId })
            .andWhere('s.is_active = true');
        if (excludeStaffId) {
            qb.andWhere('s.id != :sid', { sid: excludeStaffId });
        }
        const active = await qb.getCount();
        if (active >= max) {
            throw new common_1.BadRequestException(`Достигнут лимит сотрудников по тарифу (${max}). Обновите тариф, чтобы добавить ещё.`);
        }
    }
    async getSubscriptionUsageSummary(organizationId) {
        const sub = await this.getSubscription(organizationId);
        const planKey = (0, plan_definitions_1.normalizePlanKey)(sub?.planKey);
        const planLimits = (0, plan_definitions_1.getPlanLimits)(planKey);
        const override = sub?.limitsOverride ?? null;
        const limits = (0, plan_definitions_1.mergePlanLimitsWithOverride)(planLimits, override);
        const [confirmed_orders_this_month, active_staff] = await Promise.all([
            this.countConfirmedOrdersInBillingMonth(organizationId),
            this.countActiveStaff(organizationId),
        ]);
        return {
            plan_key: planKey,
            limits: subscriptionLimitsToSnake(limits),
            plan_limits: subscriptionLimitsToSnake(planLimits),
            limits_override: override,
            subscription_active: this.isSubscriptionRecordActive(sub),
            subscription_status: sub?.status ?? null,
            subscription_end_date: sub?.endDate instanceof Date ? sub.endDate.toISOString().slice(0, 10) : sub?.endDate ? String(sub.endDate).slice(0, 10) : null,
            confirmed_orders_this_month,
            active_staff,
        };
    }
};
exports.SubscriptionQuotaService = SubscriptionQuotaService;
exports.SubscriptionQuotaService = SubscriptionQuotaService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(order_entity_1.Order)),
    __param(1, (0, typeorm_1.InjectRepository)(organization_entity_1.Organization)),
    __param(2, (0, typeorm_1.InjectRepository)(organization_subscription_entity_1.OrganizationSubscription)),
    __param(3, (0, typeorm_1.InjectRepository)(staff_member_entity_1.StaffMember)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], SubscriptionQuotaService);
//# sourceMappingURL=subscription-quota.service.js.map