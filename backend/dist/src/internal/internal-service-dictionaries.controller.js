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
exports.InternalServiceDictionariesController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const service_catalog_service_1 = require("../reference/service-catalog.service");
let InternalServiceDictionariesController = class InternalServiceDictionariesController {
    constructor(serviceCatalog) {
        this.serviceCatalog = serviceCatalog;
    }
    async list() {
        const grouped = await this.serviceCatalog.getCatalogGrouped();
        const categories = grouped.categories;
        const items = [];
        for (const c of categories) {
            for (const it of c.items)
                items.push(it);
        }
        return {
            categories: grouped.categories,
            items,
            total_items: items.length,
            total_categories: categories.length,
        };
    }
};
exports.InternalServiceDictionariesController = InternalServiceDictionariesController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalServiceDictionariesController.prototype, "list", null);
exports.InternalServiceDictionariesController = InternalServiceDictionariesController = __decorate([
    (0, common_1.Controller)('internal/service-dictionaries'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [service_catalog_service_1.ServiceCatalogService])
], InternalServiceDictionariesController);
//# sourceMappingURL=internal-service-dictionaries.controller.js.map