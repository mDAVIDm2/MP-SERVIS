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
exports.StaffMember = void 0;
const typeorm_1 = require("typeorm");
const organization_entity_1 = require("./organization.entity");
const master_schedule_entity_1 = require("./master-schedule.entity");
let StaffMember = class StaffMember {
};
exports.StaffMember = StaffMember;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], StaffMember.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], StaffMember.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], StaffMember.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], StaffMember.prototype, "phone", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 255, nullable: true }),
    __metadata("design:type", Object)
], StaffMember.prototype, "email", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'master' }),
    __metadata("design:type", String)
], StaffMember.prototype, "role", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], StaffMember.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invited_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], StaffMember.prototype, "invitedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_id' }),
    __metadata("design:type", String)
], StaffMember.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', default: [] }),
    __metadata("design:type", Array)
], StaffMember.prototype, "skills", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => organization_entity_1.Organization, (o) => o.staff, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'organization_id' }),
    __metadata("design:type", organization_entity_1.Organization)
], StaffMember.prototype, "organization", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => master_schedule_entity_1.MasterSchedule, (s) => s.master, { cascade: true }),
    __metadata("design:type", Array)
], StaffMember.prototype, "schedule", void 0);
exports.StaffMember = StaffMember = __decorate([
    (0, typeorm_1.Entity)('staff_members')
], StaffMember);
//# sourceMappingURL=staff-member.entity.js.map