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
var ReferenceController_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ReferenceController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const reference_service_1 = require("./reference.service");
const service_catalog_service_1 = require("./service-catalog.service");
let ReferenceController = ReferenceController_1 = class ReferenceController {
    constructor(reference, serviceCatalog) {
        this.reference = reference;
        this.serviceCatalog = serviceCatalog;
    }
    async getCarBrands() {
        return this.reference.getCarBrands();
    }
    async getCarModels(brandId) {
        return this.reference.getCarModels(brandId);
    }
    async getCarGenerations(modelId) {
        return this.reference.getCarGenerations(modelId);
    }
    async createPending(req, body) {
        const carId = String(body?.carId ?? '').trim();
        const pendingBrand = typeof body?.pendingBrand === 'string' ? body.pendingBrand : (typeof body?.pending_brand === 'string' ? body.pending_brand : undefined);
        const pendingModel = typeof body?.pendingModel === 'string' ? body.pendingModel : (typeof body?.pending_model === 'string' ? body.pending_model : undefined);
        const pendingGeneration = typeof body?.pendingGeneration === 'string' ? body.pendingGeneration : (typeof body?.pending_generation === 'string' ? body.pending_generation : undefined);
        const referenceBrandId = ReferenceController_1.optPositiveInt(body?.referenceBrandId ?? body?.reference_brand_id ?? body?.brandId);
        const referenceModelId = ReferenceController_1.optPositiveInt(body?.referenceModelId ?? body?.reference_model_id ?? body?.modelId);
        return this.reference.createPending(req.user.id, carId, {
            pendingBrand: pendingBrand?.trim() || undefined,
            pendingModel: pendingModel?.trim() || undefined,
            pendingGeneration: pendingGeneration?.trim() || undefined,
            referenceBrandId,
            referenceModelId,
        });
    }
    static optPositiveInt(v) {
        if (v === null || v === undefined)
            return undefined;
        if (typeof v === 'number' && Number.isFinite(v))
            return Math.trunc(v);
        if (typeof v === 'string' && v.trim() !== '') {
            const n = parseInt(v.trim(), 10);
            if (!Number.isNaN(n) && n > 0)
                return n;
        }
        return undefined;
    }
    async listPending() {
        return this.reference.listPending();
    }
    async getServiceCatalog(organizationId, businessKind, req) {
        const orgId = (organizationId && organizationId.trim()) || req?.user?.organizationId || null;
        if (orgId) {
            return this.serviceCatalog.getCatalogGrouped(orgId);
        }
        const bk = businessKind != null && String(businessKind).trim() !== '' ? String(businessKind).trim() : null;
        return this.serviceCatalog.getCatalogGrouped(null, bk);
    }
    async suggestServiceCatalog(req, body) {
        const orgId = req.user.organizationId;
        if (!orgId)
            throw new common_1.BadRequestException('Пользователь не привязан к организации');
        return this.serviceCatalog.createSuggestion(orgId, {
            requested_name: String(body?.requested_name ?? ''),
            category_hint: body?.category_hint,
            note: body?.note,
        });
    }
};
exports.ReferenceController = ReferenceController;
__decorate([
    (0, common_1.Get)('car-brands'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], ReferenceController.prototype, "getCarBrands", null);
__decorate([
    (0, common_1.Get)('car-brands/:id/models'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ReferenceController.prototype, "getCarModels", null);
__decorate([
    (0, common_1.Get)('car-models/:modelId/generations'),
    __param(0, (0, common_1.Param)('modelId', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", Promise)
], ReferenceController.prototype, "getCarGenerations", null);
__decorate([
    (0, common_1.Post)('pending-car'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], ReferenceController.prototype, "createPending", null);
__decorate([
    (0, common_1.Get)('pending-car'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], ReferenceController.prototype, "listPending", null);
__decorate([
    (0, common_1.Get)('service-catalog'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __param(0, (0, common_1.Query)('organization_id')),
    __param(1, (0, common_1.Query)('business_kind')),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], ReferenceController.prototype, "getServiceCatalog", null);
__decorate([
    (0, common_1.Post)('service-catalog/suggestions'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], ReferenceController.prototype, "suggestServiceCatalog", null);
exports.ReferenceController = ReferenceController = ReferenceController_1 = __decorate([
    (0, common_1.Controller)('reference'),
    __metadata("design:paramtypes", [reference_service_1.ReferenceService,
        service_catalog_service_1.ServiceCatalogService])
], ReferenceController);
//# sourceMappingURL=reference.controller.js.map