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
exports.InternalSubscriptionsController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const organizations_service_1 = require("../organizations/organizations.service");
let InternalSubscriptionsController = class InternalSubscriptionsController {
    constructor(org) {
        this.org = org;
    }
    async list() {
        const items = await this.org.findAllSubscriptions();
        return { items };
    }
    subscriptionPlans() {
        return this.org.listSubscriptionPlansPublic();
    }
    async applyPlanWithStaff(organizationId, body) {
        const pk = body?.plan_key?.trim();
        if (!pk)
            throw new common_1.BadRequestException('plan_key обязателен');
        const summary = await this.org.applySubscriptionPlanWithActiveStaff(organizationId, {
            plan_key: pk,
            keep_active_staff_ids: Array.isArray(body.keep_active_staff_ids) ? body.keep_active_staff_ids : [],
        });
        return { ok: true, subscription_usage: summary };
    }
    async update(organizationId, body) {
        const sub = await this.org.updateSubscription(organizationId, {
            is_active: body.is_active,
            status: body.status,
            plan_key: body.plan_key,
            limits_override: body.limits_override,
        });
        if (!sub)
            return { ok: false, message: 'Подписка не найдена' };
        const subscription_usage = await this.org.getSubscriptionUsageSummary(organizationId);
        return {
            ok: true,
            subscription: {
                id: sub.id,
                organization_id: sub.organizationId,
                is_active: sub.isActive,
                status: sub.status,
                plan_key: sub.planKey ?? 'team',
                limits_override: sub.limitsOverride ?? null,
            },
            subscription_usage,
        };
    }
};
exports.InternalSubscriptionsController = InternalSubscriptionsController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalSubscriptionsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)('plans'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], InternalSubscriptionsController.prototype, "subscriptionPlans", null);
__decorate([
    (0, common_1.Post)(':organizationId/apply-plan-with-staff'),
    __param(0, (0, common_1.Param)('organizationId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], InternalSubscriptionsController.prototype, "applyPlanWithStaff", null);
__decorate([
    (0, common_1.Patch)(':organizationId'),
    __param(0, (0, common_1.Param)('organizationId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], InternalSubscriptionsController.prototype, "update", null);
exports.InternalSubscriptionsController = InternalSubscriptionsController = __decorate([
    (0, common_1.Controller)('internal/subscriptions'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [organizations_service_1.OrganizationsService])
], InternalSubscriptionsController);
//# sourceMappingURL=internal-subscriptions.controller.js.map