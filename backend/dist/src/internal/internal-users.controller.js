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
                const isBusiness = u.organizationId != null || (u.role !== 'solo');
                return {
                    id: u.id,
                    phone: u.phone,
                    name: u.name,
                    role: u.role,
                    role_label: ROLE_LABELS[u.role] ?? u.role,
                    account_type: isBusiness ? 'business' : 'client',
                    organization_id: u.organizationId,
                    organization_name: u.organization?.name ?? null,
                };
            }),
        };
    }
};
exports.InternalUsersController = InternalUsersController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalUsersController.prototype, "list", null);
exports.InternalUsersController = InternalUsersController = __decorate([
    (0, common_1.Controller)('internal/users'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [users_service_1.UsersService])
], InternalUsersController);
//# sourceMappingURL=internal-users.controller.js.map