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
exports.InternalAuthController = void 0;
const common_1 = require("@nestjs/common");
const internal_auth_service_1 = require("./internal-auth.service");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const internal_current_operator_decorator_1 = require("./internal-current-operator.decorator");
const internal_operator_entity_1 = require("./internal-operator.entity");
const internal_login_dto_1 = require("./dto/internal-login.dto");
let InternalAuthController = class InternalAuthController {
    constructor(auth) {
        this.auth = auth;
    }
    async login(body) {
        return this.auth.login(body.email.trim().toLowerCase(), body.password);
    }
    async me(operator) {
        return {
            id: operator.id,
            email: operator.email,
            name: operator.name || operator.email.split('@')[0],
            role: operator.role,
        };
    }
};
exports.InternalAuthController = InternalAuthController;
__decorate([
    (0, common_1.Post)('login'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [internal_login_dto_1.InternalLoginDto]),
    __metadata("design:returntype", Promise)
], InternalAuthController.prototype, "login", null);
__decorate([
    (0, common_1.Get)('me'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __param(0, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalAuthController.prototype, "me", null);
exports.InternalAuthController = InternalAuthController = __decorate([
    (0, common_1.Controller)('internal/auth'),
    __metadata("design:paramtypes", [internal_auth_service_1.InternalAuthService])
], InternalAuthController);
//# sourceMappingURL=internal-auth.controller.js.map