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
exports.ServiceCatalogItem = void 0;
const typeorm_1 = require("typeorm");
let ServiceCatalogItem = class ServiceCatalogItem {
};
exports.ServiceCatalogItem = ServiceCatalogItem;
__decorate([
    (0, typeorm_1.PrimaryColumn)({ type: 'varchar', length: 96 }),
    __metadata("design:type", String)
], ServiceCatalogItem.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'category_key', type: 'varchar', length: 64 }),
    __metadata("design:type", String)
], ServiceCatalogItem.prototype, "categoryKey", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'category_name', type: 'varchar', length: 160 }),
    __metadata("design:type", String)
], ServiceCatalogItem.prototype, "categoryName", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'category_sort_order', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], ServiceCatalogItem.prototype, "categorySortOrder", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 512 }),
    __metadata("design:type", String)
], ServiceCatalogItem.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'default_duration_minutes', type: 'int', default: 60 }),
    __metadata("design:type", Number)
], ServiceCatalogItem.prototype, "defaultDurationMinutes", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'sort_order', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], ServiceCatalogItem.prototype, "sortOrder", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'required_skill', type: 'varchar', length: 32, nullable: true }),
    __metadata("design:type", Object)
], ServiceCatalogItem.prototype, "requiredSkill", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'allowed_business_kinds', type: 'jsonb', default: () => `'["sto"]'` }),
    __metadata("design:type", Array)
], ServiceCatalogItem.prototype, "allowedBusinessKinds", void 0);
exports.ServiceCatalogItem = ServiceCatalogItem = __decorate([
    (0, typeorm_1.Entity)('service_catalog_items')
], ServiceCatalogItem);
//# sourceMappingURL=service-catalog-item.entity.js.map