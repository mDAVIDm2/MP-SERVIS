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
exports.InternalSeedService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const internal_operator_entity_1 = require("./internal-operator.entity");
const internal_auth_service_1 = require("./internal-auth.service");
const ENV_INITIAL_EMAIL = 'INITIAL_SUPERADMIN_EMAIL';
const ENV_INITIAL_PASSWORD = 'INITIAL_SUPERADMIN_PASSWORD';
let InternalSeedService = class InternalSeedService {
    constructor(operatorRepo, auth) {
        this.operatorRepo = operatorRepo;
        this.auth = auth;
    }
    async onApplicationBootstrap() {
        const email = process.env[ENV_INITIAL_EMAIL]?.trim();
        const password = process.env[ENV_INITIAL_PASSWORD]?.trim();
        if (!email || !password) {
            if (process.env.NODE_ENV !== 'production') {
                console.log('[Internal] Seed skipped: set INITIAL_SUPERADMIN_EMAIL and INITIAL_SUPERADMIN_PASSWORD in .env to create/update superadmin');
            }
            return;
        }
        const normalizedEmail = email.toLowerCase();
        const passwordHash = await this.auth.hashPassword(password);
        const existing = await this.operatorRepo.findOne({
            where: { email: normalizedEmail },
        });
        if (existing) {
            existing.passwordHash = passwordHash;
            existing.name = 'Суперадмин';
            existing.role = 'superadmin';
            existing.isActive = true;
            await this.operatorRepo.save(existing);
            if (process.env.NODE_ENV !== 'production') {
                console.log('[Internal] Updated initial superadmin from env:', normalizedEmail);
            }
            return;
        }
        const operator = this.operatorRepo.create({
            email: normalizedEmail,
            passwordHash,
            name: 'Суперадмин',
            role: 'superadmin',
            isActive: true,
        });
        await this.operatorRepo.save(operator);
        if (process.env.NODE_ENV !== 'production') {
            console.log('[Internal] Created initial superadmin from env:', normalizedEmail);
        }
    }
};
exports.InternalSeedService = InternalSeedService;
exports.InternalSeedService = InternalSeedService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(internal_operator_entity_1.InternalOperator)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        internal_auth_service_1.InternalAuthService])
], InternalSeedService);
//# sourceMappingURL=internal-seed.service.js.map