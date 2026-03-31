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
exports.InternalReferenceController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const internal_current_operator_decorator_1 = require("./internal-current-operator.decorator");
const internal_operator_entity_1 = require("./internal-operator.entity");
const internal_audit_service_1 = require("./internal-audit.service");
const reference_service_1 = require("../reference/reference.service");
const service_catalog_service_1 = require("../reference/service-catalog.service");
let InternalReferenceController = class InternalReferenceController {
    constructor(reference, serviceCatalog, audit) {
        this.reference = reference;
        this.serviceCatalog = serviceCatalog;
        this.audit = audit;
    }
    async getServiceCatalog() {
        return this.serviceCatalog.getCatalogGrouped();
    }
    async createServiceCatalogCategory(body, operator) {
        const result = await this.serviceCatalog.createCatalogCategoryAdmin(body);
        await this.audit.logInternal(operator, 'service_catalog_category_create', 'service_catalog', body.category_key, {
            category_name: body.category_name,
        });
        return result;
    }
    async patchServiceCatalogCategory(body, operator) {
        const result = await this.serviceCatalog.patchCatalogCategoryAdmin(body.category_key, {
            category_name: body.category_name,
            new_category_key: body.new_category_key,
        });
        await this.audit.logInternal(operator, 'service_catalog_category_patch', 'service_catalog', body.category_key, {
            category_name: body.category_name,
            new_category_key: body.new_category_key,
        });
        return result;
    }
    async deleteServiceCatalogCategory(categoryKey, operator) {
        const result = await this.serviceCatalog.deleteCatalogCategoryAdmin(categoryKey);
        await this.audit.logInternal(operator, 'service_catalog_category_delete', 'service_catalog', categoryKey, {});
        return result;
    }
    async reorderServiceCatalogCategory(body, operator) {
        const result = await this.serviceCatalog.reorderCatalogCategoryAdmin(body.category_key, body.delta);
        await this.audit.logInternal(operator, 'service_catalog_category_reorder', 'service_catalog', body.category_key, {
            delta: body.delta,
        });
        return result;
    }
    async createServiceCatalogItem(body, operator) {
        const result = await this.serviceCatalog.createCatalogItemAdmin(body);
        await this.audit.logInternal(operator, 'service_catalog_item_create', 'service_catalog_item', body.name, {
            category_key: body.category_key,
        });
        return result;
    }
    async patchServiceCatalogItem(id, body, operator) {
        const result = await this.serviceCatalog.updateCatalogItemAdmin(id, body);
        await this.audit.logInternal(operator, 'service_catalog_item_patch', 'service_catalog_item', id, body);
        return result;
    }
    async deleteServiceCatalogItem(id, operator) {
        const result = await this.serviceCatalog.deleteCatalogItemAdmin(id);
        await this.audit.logInternal(operator, 'service_catalog_item_delete', 'service_catalog_item', id, {});
        return result;
    }
    async reorderServiceCatalogItem(id, body, operator) {
        const result = await this.serviceCatalog.reorderCatalogItemAdmin(id, body.delta);
        await this.audit.logInternal(operator, 'service_catalog_item_reorder', 'service_catalog_item', id, {
            delta: body.delta,
        });
        return result;
    }
    async getCarBrands() {
        return this.reference.getCarBrands();
    }
    async createBrand(body) {
        return this.reference.createBrand(body.name);
    }
    async deleteBrand(id) {
        await this.reference.deleteBrand(id);
        return { ok: true };
    }
    async getCarModels(brandId) {
        return this.reference.getCarModels(brandId);
    }
    async createModel(brandId, body) {
        return this.reference.createModel(brandId, body.name);
    }
    async deleteModel(id) {
        await this.reference.deleteModel(id);
        return { ok: true };
    }
    async getCarGenerations(modelId) {
        return this.reference.getCarGenerations(modelId);
    }
    async createGeneration(modelId, body) {
        return this.reference.createGeneration(modelId, body.name, body.year_from, body.year_to);
    }
    async deleteGeneration(id) {
        await this.reference.deleteGeneration(id);
        return { ok: true };
    }
    async listPending() {
        return this.reference.listPending();
    }
    async approvePending(id) {
        return this.reference.approvePending(id);
    }
    async rejectPending(id) {
        await this.reference.rejectPending(id);
        return { ok: true };
    }
    async suggestPending(id, body) {
        await this.reference.suggestPending(id, body);
        return { ok: true };
    }
};
exports.InternalReferenceController = InternalReferenceController;
__decorate([
    (0, common_1.Get)('service-catalog'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "getServiceCatalog", null);
__decorate([
    (0, common_1.Post)('service-catalog/categories'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "createServiceCatalogCategory", null);
__decorate([
    (0, common_1.Patch)('service-catalog/categories'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "patchServiceCatalogCategory", null);
__decorate([
    (0, common_1.Delete)('service-catalog/categories'),
    __param(0, (0, common_1.Query)('category_key')),
    __param(1, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "deleteServiceCatalogCategory", null);
__decorate([
    (0, common_1.Post)('service-catalog/categories/reorder'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "reorderServiceCatalogCategory", null);
__decorate([
    (0, common_1.Post)('service-catalog/items'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "createServiceCatalogItem", null);
__decorate([
    (0, common_1.Patch)('service-catalog/items/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "patchServiceCatalogItem", null);
__decorate([
    (0, common_1.Delete)('service-catalog/items/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "deleteServiceCatalogItem", null);
__decorate([
    (0, common_1.Post)('service-catalog/items/:id/reorder'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "reorderServiceCatalogItem", null);
__decorate([
    (0, common_1.Get)('car-brands'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "getCarBrands", null);
__decorate([
    (0, common_1.Post)('car-brands'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "createBrand", null);
__decorate([
    (0, common_1.Delete)('car-brands/:id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "deleteBrand", null);
__decorate([
    (0, common_1.Get)('car-brands/:id/models'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "getCarModels", null);
__decorate([
    (0, common_1.Post)('car-brands/:id/models'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "createModel", null);
__decorate([
    (0, common_1.Delete)('car-models/:id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "deleteModel", null);
__decorate([
    (0, common_1.Get)('car-models/:modelId/generations'),
    __param(0, (0, common_1.Param)('modelId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "getCarGenerations", null);
__decorate([
    (0, common_1.Post)('car-models/:modelId/generations'),
    __param(0, (0, common_1.Param)('modelId', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "createGeneration", null);
__decorate([
    (0, common_1.Delete)('car-generations/:id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "deleteGeneration", null);
__decorate([
    (0, common_1.Get)('pending-car'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "listPending", null);
__decorate([
    (0, common_1.Post)('pending-car/:id/approve'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "approvePending", null);
__decorate([
    (0, common_1.Post)('pending-car/:id/reject'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "rejectPending", null);
__decorate([
    (0, common_1.Post)('pending-car/:id/suggest'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], InternalReferenceController.prototype, "suggestPending", null);
exports.InternalReferenceController = InternalReferenceController = __decorate([
    (0, common_1.Controller)('internal/reference'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [reference_service_1.ReferenceService,
        service_catalog_service_1.ServiceCatalogService,
        internal_audit_service_1.InternalAuditService])
], InternalReferenceController);
//# sourceMappingURL=internal-reference.controller.js.map