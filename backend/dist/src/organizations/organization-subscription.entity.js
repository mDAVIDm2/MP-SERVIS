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
exports.OrganizationSubscription = void 0;
const typeorm_1 = require("typeorm");
const organization_entity_1 = require("./organization.entity");
let OrganizationSubscription = class OrganizationSubscription {
};
exports.OrganizationSubscription = OrganizationSubscription;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], OrganizationSubscription.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_id', type: 'uuid' }),
    __metadata("design:type", String)
], OrganizationSubscription.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => organization_entity_1.Organization, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'organization_id' }),
    __metadata("design:type", organization_entity_1.Organization)
], OrganizationSubscription.prototype, "organization", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'start_date', type: 'date' }),
    __metadata("design:type", Date)
], OrganizationSubscription.prototype, "startDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'end_date', type: 'date' }),
    __metadata("design:type", Date)
], OrganizationSubscription.prototype, "endDate", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', default: true }),
    __metadata("design:type", Boolean)
], OrganizationSubscription.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 32, default: 'active' }),
    __metadata("design:type", String)
], OrganizationSubscription.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'plan_key', type: 'varchar', length: 32, default: 'team' }),
    __metadata("design:type", String)
], OrganizationSubscription.prototype, "planKey", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'limits_override', type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], OrganizationSubscription.prototype, "limitsOverride", void 0);
exports.OrganizationSubscription = OrganizationSubscription = __decorate([
    (0, typeorm_1.Entity)('organization_subscriptions')
], OrganizationSubscription);
//# sourceMappingURL=organization-subscription.entity.js.map