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
exports.ServiceCatalogSuggestion = void 0;
const typeorm_1 = require("typeorm");
const organization_entity_1 = require("../organizations/organization.entity");
let ServiceCatalogSuggestion = class ServiceCatalogSuggestion {
};
exports.ServiceCatalogSuggestion = ServiceCatalogSuggestion;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], ServiceCatalogSuggestion.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'organization_id' }),
    __metadata("design:type", String)
], ServiceCatalogSuggestion.prototype, "organizationId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => organization_entity_1.Organization, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'organization_id' }),
    __metadata("design:type", organization_entity_1.Organization)
], ServiceCatalogSuggestion.prototype, "organization", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'requested_name', type: 'varchar', length: 512 }),
    __metadata("design:type", String)
], ServiceCatalogSuggestion.prototype, "requestedName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'category_hint', type: 'varchar', length: 256, nullable: true }),
    __metadata("design:type", Object)
], ServiceCatalogSuggestion.prototype, "categoryHint", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", Object)
], ServiceCatalogSuggestion.prototype, "note", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 32, default: 'pending' }),
    __metadata("design:type", String)
], ServiceCatalogSuggestion.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reviewed_at', type: 'timestamp', nullable: true }),
    __metadata("design:type", Object)
], ServiceCatalogSuggestion.prototype, "reviewedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'review_note', type: 'text', nullable: true }),
    __metadata("design:type", Object)
], ServiceCatalogSuggestion.prototype, "reviewNote", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], ServiceCatalogSuggestion.prototype, "createdAt", void 0);
exports.ServiceCatalogSuggestion = ServiceCatalogSuggestion = __decorate([
    (0, typeorm_1.Entity)('service_catalog_suggestions')
], ServiceCatalogSuggestion);
//# sourceMappingURL=service-catalog-suggestion.entity.js.map