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
exports.Organization = void 0;
const typeorm_1 = require("typeorm");
const staff_member_entity_1 = require("./staff-member.entity");
const organization_settings_entity_1 = require("./organization-settings.entity");
let Organization = class Organization {
};
exports.Organization = Organization;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Organization.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: 'Мой автосервис' }),
    __metadata("design:type", String)
], Organization.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: '' }),
    __metadata("design:type", String)
], Organization.prototype, "address", void 0);
__decorate([
    (0, typeorm_1.Column)({ default: '' }),
    __metadata("design:type", String)
], Organization.prototype, "phone", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'working_hours', default: 'Пн–Пт 9:00–19:00, Сб 10:00–16:00' }),
    __metadata("design:type", String)
], Organization.prototype, "workingHours", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'timezone', type: 'varchar', length: 64, default: 'Europe/Moscow' }),
    __metadata("design:type", String)
], Organization.prototype, "timezone", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'latitude', type: 'float', nullable: true }),
    __metadata("design:type", Object)
], Organization.prototype, "latitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'longitude', type: 'float', nullable: true }),
    __metadata("design:type", Object)
], Organization.prototype, "longitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'photo_urls', type: 'simple-json', nullable: true }),
    __metadata("design:type", Object)
], Organization.prototype, "photoUrls", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'business_kind', type: 'varchar', length: 32, default: 'sto' }),
    __metadata("design:type", String)
], Organization.prototype, "businessKind", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'scheduling_mode', type: 'varchar', length: 16, default: 'staff_based' }),
    __metadata("design:type", String)
], Organization.prototype, "schedulingMode", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => staff_member_entity_1.StaffMember, (s) => s.organization),
    __metadata("design:type", Array)
], Organization.prototype, "staff", void 0);
__decorate([
    (0, typeorm_1.OneToOne)(() => organization_settings_entity_1.OrganizationSettings, (s) => s.organization, { cascade: true }),
    __metadata("design:type", organization_settings_entity_1.OrganizationSettings)
], Organization.prototype, "settings", void 0);
exports.Organization = Organization = __decorate([
    (0, typeorm_1.Entity)('organizations')
], Organization);
//# sourceMappingURL=organization.entity.js.map