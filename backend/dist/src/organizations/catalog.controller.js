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
exports.CatalogController = void 0;
const common_1 = require("@nestjs/common");
const passport_1 = require("@nestjs/passport");
const service_catalog_service_1 = require("../reference/service-catalog.service");
const organizations_service_1 = require("./organizations.service");
let CatalogController = class CatalogController {
    constructor(org, serviceCatalog) {
        this.org = org;
        this.serviceCatalog = serviceCatalog;
    }
    async getCatalogServices(businessKind) {
        return this.serviceCatalog.getCatalogGrouped(undefined, businessKind ?? null);
    }
    async search(q, businessKind) {
        const list = await this.org.findAll();
        const items = [];
        for (const o of list) {
            const settings = (await this.org.getSettings(o.id));
            const carBrands = Array.isArray(settings?.car_brands) ? settings.car_brands : [];
            const photoUrls = this.org.getPhotoUrls(o);
            const services = Array.isArray(settings?.services) ? settings.services : [];
            const serviceIds = services.map((s) => s.id);
            const servicesPayload = services.map((s) => ({
                id: s.id,
                name: s.name,
                price_kopecks: s.price_kopecks ?? 0,
                duration_minutes: s.duration_minutes ?? 60,
            }));
            const bk = (o.businessKind ?? 'sto');
            const sm = (o.schedulingMode ?? 'staff_based');
            items.push({
                id: o.id,
                name: o.name,
                address: o.address,
                phone: o.phone,
                working_hours: o.workingHours,
                car_brands: carBrands,
                latitude: o.latitude ?? undefined,
                longitude: o.longitude ?? undefined,
                photo_urls: photoUrls,
                service_ids: serviceIds,
                services: servicesPayload,
                business_kind: bk,
                business_kind_label: this.org.businessKindLabelRu(bk),
                scheduling_mode: sm,
            });
        }
        let filtered = items;
        const query = (q ?? '').trim().toLowerCase();
        if (query) {
            filtered = items.filter((o) => o.name.toLowerCase().includes(query) ||
                (o.address && o.address.toLowerCase().includes(query)));
        }
        const kind = (businessKind ?? '').trim().toLowerCase();
        if (kind && kind !== 'all') {
            filtered = filtered.filter((o) => o.business_kind === kind);
        }
        return { items: filtered };
    }
    async getOrganization(id) {
        const o = await this.org.findOne(id);
        if (!o)
            throw new common_1.NotFoundException('Organization not found');
        const settings = (await this.org.getSettings(id));
        const carBrands = Array.isArray(settings?.car_brands) ? settings.car_brands : [];
        const photoUrls = this.org.getPhotoUrls(o);
        const bk = (o.businessKind ?? 'sto');
        const sm = (o.schedulingMode ?? 'staff_based');
        return {
            id: o.id,
            name: o.name,
            address: o.address,
            phone: o.phone,
            working_hours: o.workingHours,
            timezone: o.timezone ?? 'Europe/Moscow',
            car_brands: carBrands,
            latitude: o.latitude ?? undefined,
            longitude: o.longitude ?? undefined,
            photo_urls: photoUrls,
            business_kind: bk,
            business_kind_label: this.org.businessKindLabelRu(bk),
            scheduling_mode: sm,
        };
    }
    async getOrganizationServices(id) {
        const o = await this.org.findOne(id);
        if (!o)
            throw new common_1.NotFoundException('Organization not found');
        const settings = (await this.org.getSettings(id));
        const categories = Array.isArray(settings?.categories) ? settings.categories : [];
        const services = Array.isArray(settings?.services) ? settings.services : [];
        const packages = Array.isArray(settings?.service_packages) ? settings.service_packages : [];
        const items = services.map((s) => ({
            id: s.id,
            category_id: s.category_id ?? '',
            name: s.name,
            price_kopecks: s.price_kopecks ?? 0,
            duration_minutes: s.duration_minutes ?? 60,
            required_skill: s.required_skill ?? 'MAINTENANCE',
            use_body_type_pricing: s.use_body_type_pricing === true,
            body_type_pricing: Array.isArray(s.body_type_pricing) ? s.body_type_pricing : [],
        }));
        const packageItems = packages.map((p) => ({
            id: p.id,
            name: p.name,
            category_id: p.category_id ?? '',
            package_price_kopecks: p.package_price_kopecks ?? 0,
            included_service_ids: Array.isArray(p.included_service_ids) ? p.included_service_ids : [],
            addons: Array.isArray(p.addons) ? p.addons : [],
        }));
        return { categories, items, packages: packageItems };
    }
};
exports.CatalogController = CatalogController;
__decorate([
    (0, common_1.Get)('services'),
    __param(0, (0, common_1.Query)('business_kind')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], CatalogController.prototype, "getCatalogServices", null);
__decorate([
    (0, common_1.Get)('search'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('business_kind')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], CatalogController.prototype, "search", null);
__decorate([
    (0, common_1.Get)('organizations/:id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], CatalogController.prototype, "getOrganization", null);
__decorate([
    (0, common_1.Get)('organizations/:id/services'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], CatalogController.prototype, "getOrganizationServices", null);
exports.CatalogController = CatalogController = __decorate([
    (0, common_1.Controller)('catalog'),
    (0, common_1.UseGuards)((0, passport_1.AuthGuard)('jwt')),
    __metadata("design:paramtypes", [organizations_service_1.OrganizationsService,
        service_catalog_service_1.ServiceCatalogService])
], CatalogController);
//# sourceMappingURL=catalog.controller.js.map