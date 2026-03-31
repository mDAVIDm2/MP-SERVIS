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
var OrganizationInvitationsScheduler_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationInvitationsScheduler = void 0;
const common_1 = require("@nestjs/common");
const schedule_1 = require("@nestjs/schedule");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const organization_invitation_entity_1 = require("./organization-invitation.entity");
let OrganizationInvitationsScheduler = OrganizationInvitationsScheduler_1 = class OrganizationInvitationsScheduler {
    constructor(invitationRepo) {
        this.invitationRepo = invitationRepo;
        this.log = new common_1.Logger(OrganizationInvitationsScheduler_1.name);
    }
    async expirePendingInvitations() {
        const now = new Date();
        const res = await this.invitationRepo
            .createQueryBuilder()
            .update(organization_invitation_entity_1.OrganizationInvitation)
            .set({ status: 'expired', respondedAt: now })
            .where('status = :pending', { pending: 'pending' })
            .andWhere('expires_at IS NOT NULL')
            .andWhere('expires_at < :now', { now })
            .execute();
        const n = res.affected ?? 0;
        if (n > 0) {
            this.log.log(`Истекло приглашений (pending→expired): ${n}`);
        }
    }
};
exports.OrganizationInvitationsScheduler = OrganizationInvitationsScheduler;
__decorate([
    (0, schedule_1.Cron)(schedule_1.CronExpression.EVERY_HOUR),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], OrganizationInvitationsScheduler.prototype, "expirePendingInvitations", null);
exports.OrganizationInvitationsScheduler = OrganizationInvitationsScheduler = OrganizationInvitationsScheduler_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(organization_invitation_entity_1.OrganizationInvitation)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], OrganizationInvitationsScheduler);
//# sourceMappingURL=organization-invitations.scheduler.js.map