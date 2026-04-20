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
exports.InternalUsersController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const users_service_1 = require("../users/users.service");
const ROLE_LABELS = {
    owner: 'Владелец',
    admin: 'Администратор',
    master: 'Мастер',
    solo: 'Клиент',
};
let InternalUsersController = class InternalUsersController {
    constructor(users) {
        this.users = users;
    }
    async list() {
        const list = await this.users.findAll();
        return {
            items: list.map((u) => {
                const isBusiness = u.organizationId != null || u.role !== 'solo';
                return {
                    id: u.id,
                    phone: u.phone,
                    name: u.name,
                    role: u.role,
                    role_label: ROLE_LABELS[u.role] ?? u.role,
                    account_type: isBusiness ? 'business' : 'client',
                    organization_id: u.organizationId,
                    organization_name: u.organization?.name ?? null,
                    avatar_url: u.avatarUrl ?? null,
                };
            }),
        };
    }
    async avatarFile(userId, filename, res) {
        const fp = this.users.getUserAvatarFilePath(userId, filename);
        if (!fp)
            throw new common_1.NotFoundException();
        return res.sendFile(fp);
    }
    async getOne(id) {
        return this.users.getInternalUserDetail(id);
    }
    async patch(id, body) {
        const exists = await this.users.findById(id);
        if (!exists)
            throw new common_1.NotFoundException('Пользователь не найден');
        if (body.clear_avatar === true) {
            await this.users.clearUserAvatar(id);
        }
        if (body.name != null && String(body.name).trim().length > 0) {
            const ok = await this.users.updateInternalUserDisplayName(id, String(body.name).trim());
            if (!ok)
                throw new common_1.NotFoundException('Пользователь не найден');
        }
        return this.users.getInternalUserDetail(id);
    }
};
exports.InternalUsersController = InternalUsersController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalUsersController.prototype, "list", null);
__decorate([
    (0, common_1.Get)(':id/avatar/:filename'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Param)('filename')),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], InternalUsersController.prototype, "avatarFile", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InternalUsersController.prototype, "getOne", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], InternalUsersController.prototype, "patch", null);
exports.InternalUsersController = InternalUsersController = __decorate([
    (0, common_1.Controller)('internal/users'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [users_service_1.UsersService])
], InternalUsersController);
//# sourceMappingURL=internal-users.controller.js.map