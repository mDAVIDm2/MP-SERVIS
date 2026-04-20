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
exports.OrganizationsController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const platform_express_1 = require("@nestjs/platform-express");
const organizations_service_1 = require("./organizations.service");
let OrganizationsController = class OrganizationsController {
    constructor(org) {
        this.org = org;
    }
    assertActiveOrganizationAccess(user, orgId) {
        if (!user.organizationId || user.organizationId !== orgId) {
            throw new common_1.ForbiddenException('Выберите эту организацию как активную в приложении');
        }
    }
    listSubscriptionPlans() {
        return this.org.listSubscriptionPlansPublic();
    }
    async applyPlanWithStaff(id, req, body) {
        this.assertActiveOrganizationAccess(req.user, id);
        this.org.ensureCallerCanManageOrganizationStaff(req.user);
        const pk = body?.plan_key?.trim();
        if (!pk)
            throw new common_1.BadRequestException('Укажите plan_key');
        return this.org.applySubscriptionPlanWithActiveStaff(id, {
            plan_key: pk,
            keep_active_staff_ids: Array.isArray(body?.keep_active_staff_ids) ? body.keep_active_staff_ids : [],
        });
    }
    async get(id, req) {
        this.assertActiveOrganizationAccess(req.user, id);
        const o = await this.org.findOne(id);
        if (!o)
            throw new Error('Not found');
        const photoUrls = this.org.getPhotoUrls(o);
        const subscription_usage = await this.org.getSubscriptionUsageSummary(id);
        return {
            name: o.name,
            address: o.address,
            phone: o.phone,
            working_hours: o.workingHours,
            timezone: o.timezone ?? 'Europe/Moscow',
            photo_urls: photoUrls,
            latitude: o.latitude ?? null,
            longitude: o.longitude ?? null,
            business_kind: o.businessKind ?? 'sto',
            scheduling_mode: o.schedulingMode ?? 'staff_based',
            subscription_usage,
        };
    }
    async addPhoto(id, req, file) {
        this.assertActiveOrganizationAccess(req.user, id);
        if (!file || (!file.buffer && !file.path))
            throw new Error('No file');
        const result = await this.org.addPhoto(id, file);
        if (!result)
            throw new Error('Not found');
        return result;
    }
    async deletePhoto(id, req, body) {
        this.assertActiveOrganizationAccess(req.user, id);
        const url = typeof body?.url === 'string' ? body.url.trim() : '';
        if (!url)
            throw new common_1.BadRequestException('Укажите url фото');
        const ok = await this.org.removePhoto(id, url);
        if (!ok)
            throw new common_1.NotFoundException('Фото не найдено или уже удалено');
        return { ok: true };
    }
    async update(id, req, body) {
        this.assertActiveOrganizationAccess(req.user, id);
        const o = await this.org.update(id, body);
        if (!o)
            throw new Error('Not found');
        const subscription_usage = await this.org.getSubscriptionUsageSummary(id);
        return {
            name: o.name,
            address: o.address,
            phone: o.phone,
            working_hours: o.workingHours,
            timezone: o.timezone ?? 'Europe/Moscow',
            latitude: o.latitude ?? null,
            longitude: o.longitude ?? null,
            business_kind: o.businessKind ?? 'sto',
            scheduling_mode: o.schedulingMode ?? 'staff_based',
            subscription_usage,
        };
    }
    async getStaff(id, req) {
        this.assertActiveOrganizationAccess(req.user, id);
        return this.org.getStaffForCaller(id, req.user);
    }
    async addMeAsMaster(id, req) {
        this.assertActiveOrganizationAccess(req.user, id);
        const user = req.user;
        return this.org.addCurrentUserAsMaster(id, {
            id: user.id,
            name: user.name,
            phone: user.phone,
            organizationId: user.organizationId,
            role: user.role,
        });
    }
    async inviteStaff(id, req, body) {
        this.assertActiveOrganizationAccess(req.user, id);
        return this.org.createInvitation(id, req.user, body);
    }
    async updateStaff(id, staffId, req, body) {
        this.assertActiveOrganizationAccess(req.user, id);
        return this.org.updateStaffMember(id, staffId, body, req.user);
    }
    async getInvitations(id, req, status) {
        this.assertActiveOrganizationAccess(req.user, id);
        return this.org.listInvitations(id, req.user, status);
    }
    async cancelInvitation(id, invitationId, req) {
        this.assertActiveOrganizationAccess(req.user, id);
        return this.org.cancelInvitation(id, invitationId, req.user);
    }
    async getSettings(id, req) {
        this.assertActiveOrganizationAccess(req.user, id);
        return { data: await this.org.getSettings(id) };
    }
    async updateSettings(id, req, body) {
        this.assertActiveOrganizationAccess(req.user, id);
        return { data: await this.org.updateSettings(id, body) };
    }
};
exports.OrganizationsController = OrganizationsController;
__decorate([
    (0, common_1.Get)('subscription-plans'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], OrganizationsController.prototype, "listSubscriptionPlans", null);
__decorate([
    (0, common_1.Post)(':id/subscription/apply-plan-with-staff'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "applyPlanWithStaff", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "get", null);
__decorate([
    (0, common_1.Post)(':id/photos'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('file')),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.UploadedFile)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "addPhoto", null);
__decorate([
    (0, common_1.Delete)(':id/photos'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "deletePhoto", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "update", null);
__decorate([
    (0, common_1.Get)(':id/staff'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "getStaff", null);
__decorate([
    (0, common_1.Post)(':id/staff/add-me-as-master'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "addMeAsMaster", null);
__decorate([
    (0, common_1.Post)(':id/staff'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "inviteStaff", null);
__decorate([
    (0, common_1.Patch)(':id/staff/:staffId'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Param)('staffId')),
    __param(2, (0, common_1.Req)()),
    __param(3, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "updateStaff", null);
__decorate([
    (0, common_1.Get)(':id/invitations'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Query)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "getInvitations", null);
__decorate([
    (0, common_1.Post)(':id/invitations/:invitationId/cancel'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Param)('invitationId')),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "cancelInvitation", null);
__decorate([
    (0, common_1.Get)(':id/settings'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "getSettings", null);
__decorate([
    (0, common_1.Patch)(':id/settings'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], OrganizationsController.prototype, "updateSettings", null);
exports.OrganizationsController = OrganizationsController = __decorate([
    (0, common_1.Controller)('organizations'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __metadata("design:paramtypes", [organizations_service_1.OrganizationsService])
], OrganizationsController);
//# sourceMappingURL=organizations.controller.js.map