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
exports.UsersController = void 0;
const common_1 = require("@nestjs/common");
const platform_express_1 = require("@nestjs/platform-express");
const passport_1 = require("@nestjs/passport");
const users_service_1 = require("./users.service");
const organizations_service_1 = require("../organizations/organizations.service");
let UsersController = class UsersController {
    constructor(users, organizations) {
        this.users = users;
        this.organizations = organizations;
    }
    listSubscriptionPlans() {
        return this.organizations.listSubscriptionPlansPublic();
    }
    async getProfile(req) {
        const u = req.user;
        const summaries = await this.users.getOrganizationSummariesForUser(u);
        const payload = { ...this.users.profileResponse(u, summaries) };
        await this.users.appendStaffCapabilities(u, payload);
        return payload;
    }
    async uploadAvatar(req, file) {
        if (!file || (!file.buffer && !file.path)) {
            throw new common_1.BadRequestException('Передайте изображение в поле file');
        }
        const user = await this.users.saveUserAvatar(req.user.id, file);
        const summaries = await this.users.getOrganizationSummariesForUser(user);
        const payload = { ...this.users.profileResponse(user, summaries) };
        await this.users.appendStaffCapabilities(user, payload);
        return payload;
    }
    async getAvatarFile(userId, filename, req, res) {
        if (req.user.id !== userId) {
            const ok = await this.users.canStaffFetchClientAvatar(req.user, userId);
            if (!ok) {
                throw new common_1.ForbiddenException('Нет доступа к этому аватару');
            }
        }
        const filePath = this.users.getUserAvatarFilePath(userId, filename);
        if (!filePath) {
            return res.status(404).send('Not found');
        }
        res.setHeader('Cache-Control', 'private, no-store, no-cache, must-revalidate');
        return res.sendFile(filePath);
    }
    async patchProfile(req, body) {
        if ((body.name == null || String(body.name).trim() === '') &&
            (body.phone == null || String(body.phone).trim() === '')) {
            throw new common_1.BadRequestException('Передайте name и/или phone');
        }
        const user = await this.users.updateOwnProfile(req.user.id, {
            name: body.name,
            phone: body.phone,
        });
        const summaries = await this.users.getOrganizationSummariesForUser(user);
        const payload = { ...this.users.profileResponse(user, summaries) };
        await this.users.appendStaffCapabilities(user, payload);
        return payload;
    }
    async deleteAccount(req) {
        await this.users.deleteOwnAccount(req.user.id);
        return { ok: true };
    }
    async switchOrganization(req, body) {
        const orgId = body?.organization_id?.trim();
        if (!orgId)
            throw new common_1.BadRequestException('organization_id обязателен');
        const next = await this.users.switchActiveOrganization(req.user.id, orgId);
        const summaries = await this.users.getOrganizationSummariesForUser(next);
        const payload = { ...this.users.profileResponse(next, summaries) };
        await this.users.appendStaffCapabilities(next, payload);
        return payload;
    }
    async getNotificationPreferences(req) {
        return this.users.getNotificationPreferences(req.user.id);
    }
    async patchNotificationPreferences(req, body) {
        return this.users.updateNotificationPreferences(req.user.id, body ?? {});
    }
    async getClientAppState(req) {
        return this.users.getClientAppState(req.user.id);
    }
    async putClientAppState(req, body) {
        const payload = body?.payload;
        if (payload == null || typeof payload !== 'object' || Array.isArray(payload)) {
            throw new common_1.BadRequestException('Передайте объект payload');
        }
        return this.users.putClientAppState(req.user.id, payload);
    }
    async createOrganization(req, body) {
        const name = body?.name?.trim();
        if (!name)
            throw new common_1.BadRequestException('Укажите название организации');
        const { user, summaries } = await this.users.createOwnedOrganization(req.user.id, {
            name,
            address: body?.address,
            phone: body?.phone,
            plan_key: body?.plan_key,
        });
        const payload = { ...this.users.profileResponse(user, summaries) };
        await this.users.appendStaffCapabilities(user, payload);
        return payload;
    }
    async incomingInvitations(req) {
        return this.users.getIncomingInvitations(req.user.id);
    }
    async acceptInvitation(invitationId, req, body) {
        if (!invitationId)
            throw new common_1.BadRequestException('id приглашения обязателен');
        const { user, summaries } = await this.users.acceptInvitation(req.user.id, invitationId, {
            set_active_organization: body?.set_active_organization !== false,
        });
        const payload = { ...this.users.profileResponse(user, summaries) };
        await this.users.appendStaffCapabilities(user, payload);
        return payload;
    }
    async declineInvitation(invitationId, req) {
        if (!invitationId)
            throw new common_1.BadRequestException('id приглашения обязателен');
        return this.users.declineInvitation(req.user.id, invitationId);
    }
};
exports.UsersController = UsersController;
__decorate([
    (0, common_1.Get)('subscription-plans'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], UsersController.prototype, "listSubscriptionPlans", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "getProfile", null);
__decorate([
    (0, common_1.Post)('avatar'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('file', { limits: { fileSize: 5 * 1024 * 1024 } })),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.UploadedFile)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "uploadAvatar", null);
__decorate([
    (0, common_1.Get)('avatar/:userId/:filename'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Param)('filename')),
    __param(2, (0, common_1.Req)()),
    __param(3, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "getAvatarFile", null);
__decorate([
    (0, common_1.Patch)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "patchProfile", null);
__decorate([
    (0, common_1.Delete)('delete'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "deleteAccount", null);
__decorate([
    (0, common_1.Post)('switch-organization'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "switchOrganization", null);
__decorate([
    (0, common_1.Get)('notification-preferences'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "getNotificationPreferences", null);
__decorate([
    (0, common_1.Patch)('notification-preferences'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "patchNotificationPreferences", null);
__decorate([
    (0, common_1.Get)('client-app-state'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "getClientAppState", null);
__decorate([
    (0, common_1.Put)('client-app-state'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "putClientAppState", null);
__decorate([
    (0, common_1.Post)('organizations'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "createOrganization", null);
__decorate([
    (0, common_1.Get)('invitations'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "incomingInvitations", null);
__decorate([
    (0, common_1.Post)('invitations/:id/accept'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "acceptInvitation", null);
__decorate([
    (0, common_1.Post)('invitations/:id/decline'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "declineInvitation", null);
exports.UsersController = UsersController = __decorate([
    (0, common_1.Controller)('profile'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __metadata("design:paramtypes", [users_service_1.UsersService,
        organizations_service_1.OrganizationsService])
], UsersController);
//# sourceMappingURL=users.controller.js.map