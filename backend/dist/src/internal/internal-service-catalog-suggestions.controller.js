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
exports.InternalServiceCatalogSuggestionsController = void 0;
const common_1 = require("@nestjs/common");
const internal_jwt_guard_1 = require("./internal-jwt.guard");
const internal_current_operator_decorator_1 = require("./internal-current-operator.decorator");
const internal_operator_entity_1 = require("./internal-operator.entity");
const service_catalog_service_1 = require("../reference/service-catalog.service");
const patch_service_catalog_suggestion_dto_1 = require("./dto/patch-service-catalog-suggestion.dto");
const internal_audit_service_1 = require("./internal-audit.service");
let InternalServiceCatalogSuggestionsController = class InternalServiceCatalogSuggestionsController {
    constructor(catalog, audit) {
        this.catalog = catalog;
        this.audit = audit;
    }
    async stats() {
        return this.catalog.getSuggestionStats();
    }
    async list(status, q, pageStr, limitStr) {
        const page = Math.min(10_000, Math.max(1, parseInt(pageStr ?? '1', 10) || 1));
        const limit = Math.min(100, Math.max(1, parseInt(limitStr ?? '24', 10) || 24));
        return this.catalog.listSuggestionsAdmin({ status, page, limit, q });
    }
    async patch(id, body, operator) {
        const result = await this.catalog.updateSuggestionAdmin(id, {
            status: body.status,
            review_note: body.review_note,
        });
        await this.audit.logInternal(operator, 'service_catalog_suggestion_update', 'service_catalog_suggestion', id, {
            requested_name: result.requested_name,
            status: result.status,
        });
        return result;
    }
};
exports.InternalServiceCatalogSuggestionsController = InternalServiceCatalogSuggestionsController;
__decorate([
    (0, common_1.Get)('stats'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], InternalServiceCatalogSuggestionsController.prototype, "stats", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('status')),
    __param(1, (0, common_1.Query)('q')),
    __param(2, (0, common_1.Query)('page')),
    __param(3, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String]),
    __metadata("design:returntype", Promise)
], InternalServiceCatalogSuggestionsController.prototype, "list", null);
__decorate([
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, internal_current_operator_decorator_1.InternalCurrentOperator)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, patch_service_catalog_suggestion_dto_1.PatchServiceCatalogSuggestionDto,
        internal_operator_entity_1.InternalOperator]),
    __metadata("design:returntype", Promise)
], InternalServiceCatalogSuggestionsController.prototype, "patch", null);
exports.InternalServiceCatalogSuggestionsController = InternalServiceCatalogSuggestionsController = __decorate([
    (0, common_1.Controller)('internal/service-catalog/suggestions'),
    (0, common_1.UseGuards)(internal_jwt_guard_1.InternalJwtAuthGuard),
    __metadata("design:paramtypes", [service_catalog_service_1.ServiceCatalogService,
        internal_audit_service_1.InternalAuditService])
], InternalServiceCatalogSuggestionsController);
//# sourceMappingURL=internal-service-catalog-suggestions.controller.js.map