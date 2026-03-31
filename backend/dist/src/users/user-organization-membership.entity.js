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
exports.UserOrganizationMembership = void 0;
const typeorm_1 = require("typeorm");
const user_entity_1 = require("./user.entity");
const organization_entity_1 = require("../organizations/organization.entity");
let UserOrganizationMembership = class UserOrganizationMembership {
};
exports.UserOrganizationMembership = UserOrganizationMembership;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], UserOrganizationMembership.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Index)('IDX_user_org_membership_user'),
    (0, typeorm_1.Column)({ name: 'user_id', type: 'uuid' }),
    __metadata("design:type", String)
], UserOrganizationMembership.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", user_entity_1.User)
], UserOrganizationMembership.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Index)('IDX_user_org_membership_org'),
    (0, typeorm_1.Column)({ name: 'organization_id', type: 'uuid' }),
    __metadata("design:type", String)
], UserOrganizationMembership.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => organization_entity_1.Organization, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'organization_id' }),
    __metadata("design:type", organization_entity_1.Organization)
], UserOrganizationMembership.prototype, "organization", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'owner' }),
    __metadata("design:type", String)
], UserOrganizationMembership.prototype, "role", void 0);
exports.UserOrganizationMembership = UserOrganizationMembership = __decorate([
    (0, typeorm_1.Entity)('user_organization_memberships'),
    (0, typeorm_1.Unique)('UQ_user_org_membership', ['userId', 'organizationId'])
], UserOrganizationMembership);
//# sourceMappingURL=user-organization-membership.entity.js.map