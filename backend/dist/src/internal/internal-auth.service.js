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
exports.InternalAuthService = void 0;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const bcrypt = require("bcrypt");
const audit_log_entity_1 = require("../audit/audit-log.entity");
const internal_operator_entity_1 = require("./internal-operator.entity");
const SALT_ROUNDS = 10;
let InternalAuthService = class InternalAuthService {
    constructor(operatorRepo, auditRepo, jwtService) {
        this.operatorRepo = operatorRepo;
        this.auditRepo = auditRepo;
        this.jwtService = jwtService;
    }
    async login(email, password) {
        const normalizedEmail = email.trim().toLowerCase();
        const operator = await this.operatorRepo.findOne({
            where: { email: normalizedEmail, isActive: true },
        });
        if (!operator) {
            if (process.env.NODE_ENV !== 'production') {
                console.log('[Internal] Login failed: operator not found for email:', normalizedEmail);
            }
            throw new common_1.UnauthorizedException('Неверный email или пароль');
        }
        const valid = await bcrypt.compare(password, operator.passwordHash);
        if (!valid) {
            if (process.env.NODE_ENV !== 'production') {
                console.log('[Internal] Login failed: invalid password for email:', normalizedEmail);
            }
            throw new common_1.UnauthorizedException('Неверный email или пароль');
        }
        const payload = {
            sub: operator.id,
            email: operator.email,
            scope: 'internal',
            internal_role: operator.role,
        };
        const access_token = this.jwtService.sign(payload);
        const actorName = operator.name || operator.email;
        this.auditRepo
            .save(this.auditRepo.create({
            actorId: operator.id,
            actorType: 'internal',
            actorName,
            action: 'login',
            resourceType: null,
            resourceId: null,
            details: { email: operator.email },
        }))
            .catch(() => { });
        return {
            access_token,
            user: {
                id: operator.id,
                email: operator.email,
                name: operator.name || operator.email.split('@')[0],
                role: operator.role,
            },
        };
    }
    async findById(id) {
        return this.operatorRepo.findOne({ where: { id, isActive: true } });
    }
    async hashPassword(password) {
        return bcrypt.hash(password, SALT_ROUNDS);
    }
};
exports.InternalAuthService = InternalAuthService;
exports.InternalAuthService = InternalAuthService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(internal_operator_entity_1.InternalOperator)),
    __param(1, (0, typeorm_1.InjectRepository)(audit_log_entity_1.AuditLog)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        jwt_1.JwtService])
], InternalAuthService);
//# sourceMappingURL=internal-auth.service.js.map