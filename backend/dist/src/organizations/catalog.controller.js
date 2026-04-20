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
        const pendingCatalogIds = new Set();
        const drafts = [];
        for (const o of list) {
            const settings = (await this.org.getSettings(o.id));
            const carBrands = Array.isArray(settings?.car_brands) ? settings.car_brands : [];
            const photoUrls = this.org.getPhotoUrls(o);
            const services = Array.isArray(settings?.services) ? settings.services : [];
            const packages = Array.isArray(settings?.service_packages) ? settings.service_packages : [];
            const catalogItemIdsForSearch = new Set();
            const byId = new Map();
            for (const s of services) {
                if (!s?.id)
                    continue;
                const id = String(s.id);
                const rawCat = s.catalog_item_id
                    ?? s.catalogItemId;
                const catId = rawCat != null && String(rawCat).trim() !== '' ? String(rawCat).trim() : '';
                if (catId)
                    catalogItemIdsForSearch.add(catId);
                byId.set(id, {
                    id,
                    name: String(s.name ?? '').trim(),
                    price_kopecks: Number(s.price_kopecks ?? 0) || 0,
                    duration_minutes: Number(s.duration_minutes ?? 60) || 60,
                    ...(catId ? { catalog_item_id: catId } : {}),
                    use_body_type_pricing: s.use_body_type_pricing === true,
                    body_type_pricing: Array.isArray(s.body_type_pricing) ? s.body_type_pricing : [],
                });
            }
            for (const p of packages) {
                const inc = Array.isArray(p?.included_service_ids)
                    ? p.included_service_ids.filter(Boolean).map(String)
                    : [];
                const n = inc.length;
                const pkgPrice = Number(p?.package_price_kopecks ?? 0) || 0;
                const pkgDur = Number(p?.package_duration_minutes ?? 0) || 0;
                const perPrice = n > 0 ? Math.floor(pkgPrice / n) : 0;
                const perDur = n > 0 ? Math.max(15, Math.floor(pkgDur / n) || 60) : 60;
                for (const id of inc) {
                    if (!byId.has(id)) {
                        byId.set(id, { id, name: '', price_kopecks: perPrice, duration_minutes: perDur });
                    }
                }
                const addons = Array.isArray(p?.addons) ? p.addons : [];
                for (const a of addons) {
                    const sid = a?.service_id != null && String(a.service_id).trim() !== '' ? String(a.service_id) : '';
                    if (!sid)
                        continue;
                    if (!byId.has(sid)) {
                        byId.set(sid, {
                            id: sid,
                            name: '',
                            price_kopecks: Number(a?.extra_price_kopecks ?? 0) || 0,
                            duration_minutes: Number(a?.extra_duration_minutes ?? 30) || 30,
                        });
                    }
                }
            }
            for (const v of byId.values()) {
                if (!v.name)
                    pendingCatalogIds.add(v.id);
            }
            const bk = (o.businessKind ?? 'sto');
            const sm = (o.schedulingMode ?? 'staff_based');
            drafts.push({ o, carBrands, photoUrls, byId, catalogItemIdsForSearch, bk, sm });
        }
        const catalogBasics = await this.serviceCatalog.resolveItemBasicsByIds([...pendingCatalogIds]);
        const items = [];
        for (const d of drafts) {
            const servicesPayload = [...d.byId.values()].map((v) => {
                let name = v.name.trim();
                if (!name) {
                    name = (catalogBasics.get(v.id)?.name ?? '').trim() || 'Услуга';
                }
                let duration = v.duration_minutes;
                const catDur = catalogBasics.get(v.id)?.defaultDurationMinutes;
                if ((!duration || duration < 15) && catDur)
                    duration = catDur;
                if (!duration || duration < 15)
                    duration = 60;
                return {
                    id: v.id,
                    name,
                    price_kopecks: v.price_kopecks,
                    duration_minutes: duration,
                    ...(v.catalog_item_id ? { catalog_item_id: v.catalog_item_id } : {}),
                    ...(v.use_body_type_pricing === true ? { use_body_type_pricing: true } : {}),
                    ...(Array.isArray(v.body_type_pricing) && v.body_type_pricing.length > 0
                        ? { body_type_pricing: v.body_type_pricing }
                        : {}),
                };
            });
            const service_ids = [
                ...new Set([...servicesPayload.map((s) => s.id), ...d.catalogItemIdsForSearch]),
            ];
            items.push({
                id: d.o.id,
                name: d.o.name,
                address: d.o.address,
                phone: d.o.phone,
                working_hours: d.o.workingHours,
                car_brands: d.carBrands,
                latitude: d.o.latitude ?? undefined,
                longitude: d.o.longitude ?? undefined,
                photo_urls: d.photoUrls,
                service_ids,
                services: servicesPayload,
                business_kind: d.bk,
                business_kind_label: this.org.businessKindLabelRu(d.bk),
                scheduling_mode: d.sm,
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
        const items = services.map((s) => {
            const catRaw = s.catalog_item_id ?? s.catalogItemId;
            const catalogItemId = catRaw != null && String(catRaw).trim() !== '' ? String(catRaw).trim() : undefined;
            return {
                id: s.id,
                category_id: s.category_id ?? '',
                name: s.name,
                price_kopecks: s.price_kopecks ?? 0,
                duration_minutes: s.duration_minutes ?? 60,
                required_skill: s.required_skill ?? 'MAINTENANCE',
                use_body_type_pricing: s.use_body_type_pricing === true,
                body_type_pricing: Array.isArray(s.body_type_pricing) ? s.body_type_pricing : [],
                ...(catalogItemId ? { catalog_item_id: catalogItemId } : {}),
            };
        });
        const packageItems = packages.map((p) => ({
            id: p.id,
            name: p.name,
            category_id: p.category_id ?? '',
            package_price_kopecks: p.package_price_kopecks ?? 0,
            package_duration_minutes: p.package_duration_minutes ?? 0,
            included_service_ids: Array.isArray(p.included_service_ids) ? p.included_service_ids : [],
            addons: Array.isArray(p.addons)
                ? p.addons.map((a) => ({
                    service_id: a.service_id,
                    extra_price_kopecks: a.extra_price_kopecks ?? 0,
                    extra_duration_minutes: a.extra_duration_minutes ?? 0,
                }))
                : [],
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