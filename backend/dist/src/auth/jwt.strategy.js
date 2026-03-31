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
exports.JwtStrategy = exports.SUBSCRIPTION_DEACTIVATED_CODE = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const passport_1 = require("@nestjs/passport");
const passport_jwt_1 = require("passport-jwt");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const users_service_1 = require("../users/users.service");
const organizations_service_1 = require("../organizations/organizations.service");
const user_session_entity_1 = require("./user-session.entity");
exports.SUBSCRIPTION_DEACTIVATED_CODE = 'subscription_deactivated';
let JwtStrategy = class JwtStrategy extends (0, passport_1.PassportStrategy)(passport_jwt_1.Strategy) {
    constructor(users, org, config, sessionRepo) {
        super({
            jwtFromRequest: passport_jwt_1.ExtractJwt.fromAuthHeaderAsBearerToken(),
            ignoreExpiration: false,
            secretOrKey: config.get('JWT_SECRET') || 'dev-secret',
        });
        this.users = users;
        this.org = org;
        this.sessionRepo = sessionRepo;
    }
    async validate(payload) {
        const user = await this.users.findById(payload.sub);
        if (!user)
            return null;
        if (payload.sid) {
            const s = await this.sessionRepo.findOne({
                where: { id: payload.sid, userId: user.id, revokedAt: (0, typeorm_2.IsNull)() },
            });
            if (!s) {
                throw new common_1.UnauthorizedException({
                    code: 'session_revoked',
                    message: 'Сессия завершена. Войдите снова.',
                });
            }
        }
        if (user.organizationId) {
            const active = await this.org.isSubscriptionActive(user.organizationId);
            if (!active) {
                throw new common_1.ForbiddenException({
                    code: exports.SUBSCRIPTION_DEACTIVATED_CODE,
                    message: 'Подписка деактивирована. Обратитесь к администратору.',
                });
            }
        }
        return user;
    }
};
exports.JwtStrategy = JwtStrategy;
exports.JwtStrategy = JwtStrategy = __decorate([
    (0, common_1.Injectable)(),
    __param(3, (0, typeorm_1.InjectRepository)(user_session_entity_1.UserSession)),
    __metadata("design:paramtypes", [users_service_1.UsersService,
        organizations_service_1.OrganizationsService,
        config_1.ConfigService,
        typeorm_2.Repository])
], JwtStrategy);
//# sourceMappingURL=jwt.strategy.js.map