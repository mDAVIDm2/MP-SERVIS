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
exports.OrganizationInvitation = void 0;
const typeorm_1 = require("typeorm");
const organization_entity_1 = require("./organization.entity");
const user_entity_1 = require("../users/user.entity");
const staff_member_entity_1 = require("./staff-member.entity");
let OrganizationInvitation = class OrganizationInvitation {
};
exports.OrganizationInvitation = OrganizationInvitation;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], OrganizationInvitation.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_id', type: 'uuid' }),
    __metadata("design:type", String)
], OrganizationInvitation.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => organization_entity_1.Organization, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'organization_id' }),
    __metadata("design:type", organization_entity_1.Organization)
], OrganizationInvitation.prototype, "organization", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invited_by_user_id', type: 'uuid' }),
    __metadata("design:type", String)
], OrganizationInvitation.prototype, "invitedByUserId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'invited_by_user_id' }),
    __metadata("design:type", user_entity_1.User)
], OrganizationInvitation.prototype, "invitedByUser", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'accepted_by_user_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "acceptedByUserId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'accepted_by_user_id' }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "acceptedByUser", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'staff_member_id', type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "staffMemberId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => staff_member_entity_1.StaffMember, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'staff_member_id' }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "staffMember", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'master' }),
    __metadata("design:type", String)
], OrganizationInvitation.prototype, "role", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invited_name', type: 'varchar', length: 255, nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "invitedName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invited_email', type: 'varchar', length: 320, nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "invitedEmail", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invited_email_norm', type: 'varchar', length: 320, nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "invitedEmailNorm", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invited_phone', type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "invitedPhone", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'invited_phone_norm', type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "invitedPhoneNorm", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'pending' }),
    __metadata("design:type", String)
], OrganizationInvitation.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 500, nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "message", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'expires_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "expiresAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'responded_at', type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], OrganizationInvitation.prototype, "respondedAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], OrganizationInvitation.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at', type: 'timestamptz' }),
    __metadata("design:type", Date)
], OrganizationInvitation.prototype, "updatedAt", void 0);
exports.OrganizationInvitation = OrganizationInvitation = __decorate([
    (0, typeorm_1.Entity)('organization_invitations'),
    (0, typeorm_1.Index)('IDX_org_invites_org', ['organizationId']),
    (0, typeorm_1.Index)('IDX_org_invites_pending_email', ['organizationId', 'invitedEmailNorm', 'status']),
    (0, typeorm_1.Index)('IDX_org_invites_pending_phone', ['organizationId', 'invitedPhoneNorm', 'status'])
], OrganizationInvitation);
//# sourceMappingURL=organization-invitation.entity.js.map