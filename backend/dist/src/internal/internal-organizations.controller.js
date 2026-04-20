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
exports.InternalOrganizationsController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const organizations_service_1 = require("../organizations/organizations.service");
const plan_definitions_1 = require("../subscriptions/plan-definitions");
function toOrgDto(o) {
    return {
        id: o.id,
        name: o.name,
        address: o.address ?? '',
        phone: o.phone ?? '',
        working_hours: o.workingHours ?? '',
        timezone: o.timezone ?? 'Europe/Moscow',
        latitude: o.latitude ?? null,
        longitude: o.longitude ?? null,
        photo_urls: o.photoUrls ?? null,
    };
}
let InternalOrganizationsController = class InternalOrganizationsController {
    constructor(org) {
        this.org = org;
    }
    async list() {
        const list = await this.org.findAll();
        const subs = await this.org.findAllSubscriptions();
        const subByOrg = new Map(subs.map((s) => [s.organization_id, s]));
        return {
            items: list.map((o) => ({
                ...toOrgDto(o),
                subscription: subByOrg.get(o.id)
                    ? {
                        is_active: subByOrg.get(o.id).is_active,
                        status: subByOrg.get(o.id).status,
                        end_date: subByOrg.get(o.id).end_date,
                        plan_key: (0, plan_definitions_1.normalizePlanKey)(subByOrg.get(o.id).plan_key),
                        limits_override: subByOrg.get(o.id).limits_override ?? null,
                    }
                    : null,
            })),
        };
    }
    async getOne(id) {
        const org = await this.org.findOne(id);
        if (!org)
            throw new common_1.NotFoundException('Организация не найдена');
        const [staff, subs, subscription_usage] = await Promise.all([
            this.org.getStaff(id),
            this.org.findAllSubscriptions(),
            this.org.getSubscriptionUsageSummary(id).catch(() => null),
        ]);
        const sub = subs.find((s) => s.organization_id === id);
        return {
            ...toOrgDto(org),
            staff: staff.items,
            subscription: sub
                ? {
                    id: sub.id,
                    is_active: sub.is_active,
                    status: sub.status,
                    start_date: sub.start_date,
                    end_date: sub.end_date,
                    plan_key: sub.plan_key ?? 'team',
                    limits_override: sub.limits_override ?? null,
                }
                : null,
            subscription_usage,
        };
    }
    async deletePhotos(id, all, url) {
        if (all === '1' || all === 'true') {
            await this.org.clearAllOrganizationPhotos(id);
            return { ok: true };
        }
        const u = String(url || '').trim();
        if (u.length > 0) {
            const ok = await this.org.removePhoto(id, u);
            return { ok };
        }
        throw new common_1.BadRequestException('Укажите query all=1 или url=<полный URL фото>');
    }
    async update(id, body) {
        const updated = await this.org.update(id, {
            name: body.name,
            address: body.address,
            phone: body.phone,
            working_hours: body.working_hours,
            timezone: body.timezone,
            latitude: body.latitude,
            longitude: body.longitude,
        });
        return updated ? toOrgDto(updated) : null;
    }
    async getStaff(id) {
        return this.org.getStaff(id);
    }
};
exports.InternalOrganizationsController = InternalOrganizationsController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalOrganizationsController.prototype, "list", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InternalOrganizationsController.prototype, "getOne", null);
__decorate([
    (0, common_1.Delete)(':id/photos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('all')),
    __param(2, (0, common_1.Query)('url')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", Promise)
], InternalOrganizationsController.prototype, "deletePhotos", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], InternalOrganizationsController.prototype, "update", null);
__decorate([
    (0, common_1.Get)(':id/staff'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InternalOrganizationsController.prototype, "getStaff", null);
exports.InternalOrganizationsController = InternalOrganizationsController = __decorate([
    (0, common_1.Controller)('internal/organizations'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [organizations_service_1.OrganizationsService])
], InternalOrganizationsController);
//# sourceMappingURL=internal-organizations.controller.js.map