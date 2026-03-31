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
exports.InternalAuditService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const audit_log_entity_1 = require("../audit/audit-log.entity");
let InternalAuditService = class InternalAuditService {
    constructor(repo) {
        this.repo = repo;
    }
    async logInternal(operator, action, resourceType, resourceId, details) {
        const actorName = operator.name || operator.email;
        await this.repo
            .save(this.repo.create({
            actorId: operator.id,
            actorType: 'internal',
            actorName,
            action,
            resourceType,
            resourceId,
            details,
        }))
            .catch(() => { });
    }
    async find(limit = 100, offset = 0, from, to) {
        const qb = this.repo
            .createQueryBuilder('a')
            .orderBy('a.createdAt', 'DESC')
            .take(limit)
            .skip(offset);
        if (from) {
            qb.andWhere('a.createdAt >= :from', { from: new Date(from) });
        }
        if (to) {
            qb.andWhere('a.createdAt <= :to', { to: new Date(to) });
        }
        const [items, total] = await qb.getManyAndCount();
        return {
            items: items.map((a) => ({
                id: a.id,
                actor_id: a.actorId,
                actor_type: a.actorType,
                actor_name: a.actorName,
                action: a.action,
                resource_type: a.resourceType,
                resource_id: a.resourceId,
                details: a.details,
                created_at: a.createdAt?.toISOString?.(),
            })),
            total,
        };
    }
};
exports.InternalAuditService = InternalAuditService;
exports.InternalAuditService = InternalAuditService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(audit_log_entity_1.AuditLog)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], InternalAuditService);
//# sourceMappingURL=internal-audit.service.js.map