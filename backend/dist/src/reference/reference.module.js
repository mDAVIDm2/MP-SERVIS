"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ReferenceModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const car_brand_entity_1 = require("./car-brand.entity");
const car_model_entity_1 = require("./car-model.entity");
const car_generation_entity_1 = require("./car-generation.entity");
const pending_car_reference_entity_1 = require("./pending-car-reference.entity");
const service_catalog_item_entity_1 = require("./service-catalog-item.entity");
const service_catalog_suggestion_entity_1 = require("./service-catalog-suggestion.entity");
const reference_controller_1 = require("./reference.controller");
const reference_service_1 = require("./reference.service");
const service_catalog_service_1 = require("./service-catalog.service");
const notifications_module_1 = require("../notifications/notifications.module");
const organization_entity_1 = require("../organizations/organization.entity");
let ReferenceModule = class ReferenceModule {
};
exports.ReferenceModule = ReferenceModule;
exports.ReferenceModule = ReferenceModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                car_brand_entity_1.CarBrand,
                car_model_entity_1.CarModel,
                car_generation_entity_1.CarGeneration,
                pending_car_reference_entity_1.PendingCarReference,
                service_catalog_item_entity_1.ServiceCatalogItem,
                service_catalog_suggestion_entity_1.ServiceCatalogSuggestion,
                organization_entity_1.Organization,
            ]),
            (0, common_1.forwardRef)(() => notifications_module_1.NotificationsModule),
        ],
        controllers: [reference_controller_1.ReferenceController],
        providers: [reference_service_1.ReferenceService, service_catalog_service_1.ServiceCatalogService],
        exports: [reference_service_1.ReferenceService, service_catalog_service_1.ServiceCatalogService],
    })
], ReferenceModule);
//# sourceMappingURL=reference.module.js.map