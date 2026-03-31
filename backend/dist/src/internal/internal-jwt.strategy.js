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
exports.InternalJwtStrategy = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const passport_1 = require("@nestjs/passport");
const passport_jwt_1 = require("passport-jwt");
const internal_auth_service_1 = require("./internal-auth.service");
let InternalJwtStrategy = class InternalJwtStrategy extends (0, passport_1.PassportStrategy)(passport_jwt_1.Strategy, 'internal-jwt') {
    constructor(auth, config) {
        super({
            jwtFromRequest: passport_jwt_1.ExtractJwt.fromAuthHeaderAsBearerToken(),
            ignoreExpiration: false,
            secretOrKey: config.get('JWT_SECRET') || 'dev-secret',
        });
        this.auth = auth;
    }
    async validate(payload) {
        if (payload.scope !== 'internal') {
            throw new common_1.UnauthorizedException('Invalid token scope');
        }
        const operator = await this.auth.findById(payload.sub);
        if (!operator)
            throw new common_1.UnauthorizedException('Operator not found');
        return operator;
    }
};
exports.InternalJwtStrategy = InternalJwtStrategy;
exports.InternalJwtStrategy = InternalJwtStrategy = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [internal_auth_service_1.InternalAuthService,
        config_1.ConfigService])
], InternalJwtStrategy);
//# sourceMappingURL=internal-jwt.strategy.js.map