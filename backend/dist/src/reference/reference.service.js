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
exports.ReferenceService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const car_brand_entity_1 = require("./car-brand.entity");
const car_model_entity_1 = require("./car-model.entity");
const car_generation_entity_1 = require("./car-generation.entity");
const pending_car_reference_entity_1 = require("./pending-car-reference.entity");
const notifications_service_1 = require("../notifications/notifications.service");
const client_car_entity_1 = require("../users/client-car.entity");
let ReferenceService = class ReferenceService {
    constructor(brandRepo, modelRepo, generationRepo, pendingRepo, clientCarRepo, notifications) {
        this.brandRepo = brandRepo;
        this.modelRepo = modelRepo;
        this.generationRepo = generationRepo;
        this.pendingRepo = pendingRepo;
        this.clientCarRepo = clientCarRepo;
        this.notifications = notifications;
    }
    async getCarBrands() {
        const list = await this.brandRepo.find({
            order: { sortOrder: 'ASC', name: 'ASC' },
        });
        return list.map((b) => ({ id: b.id, name: b.name }));
    }
    async getCarModels(brandId) {
        const brand = await this.brandRepo.findOne({ where: { id: brandId } });
        if (!brand)
            throw new common_1.NotFoundException('Марка не найдена');
        const list = await this.modelRepo.find({
            where: { brandId },
            order: { sortOrder: 'ASC', name: 'ASC' },
        });
        return list.map((m) => ({ id: m.id, name: m.name }));
    }
    async getCarGenerations(modelId) {
        const model = await this.modelRepo.findOne({ where: { id: modelId } });
        if (!model)
            throw new common_1.NotFoundException('Модель не найдена');
        const list = await this.generationRepo.find({
            where: { modelId },
            order: { sortOrder: 'ASC', yearFrom: 'DESC' },
        });
        return list.map((g) => ({
            id: g.id,
            name: g.name,
            yearFrom: g.yearFrom ?? undefined,
            yearTo: g.yearTo ?? undefined,
        }));
    }
    async createPending(userId, carId, data) {
        const cid = carId?.trim();
        if (!cid)
            throw new common_1.BadRequestException('Не указан car_id автомобиля из гаража');
        let pendingBrand = data.pendingBrand?.trim() || undefined;
        let pendingModel = data.pendingModel?.trim() || undefined;
        const pendingGeneration = data.pendingGeneration?.trim() || undefined;
        if (pendingModel === '—')
            pendingModel = undefined;
        const car = await this.clientCarRepo.findOne({ where: { id: cid, userId } });
        const brandIdHint = data.referenceBrandId ?? car?.brandId ?? undefined;
        const modelIdHint = data.referenceModelId ?? car?.modelId ?? undefined;
        if (!pendingBrand && car?.brand?.trim())
            pendingBrand = car.brand.trim();
        if (!pendingModel && car?.model?.trim() && car.model.trim() !== '—')
            pendingModel = car.model.trim();
        if (!pendingBrand && brandIdHint != null) {
            const b = await this.brandRepo.findOne({ where: { id: brandIdHint } });
            if (b?.name?.trim())
                pendingBrand = b.name.trim();
        }
        if (!pendingModel && modelIdHint != null) {
            const m = await this.modelRepo.findOne({ where: { id: modelIdHint } });
            if (m?.name?.trim())
                pendingModel = m.name.trim();
        }
        const hasAny = pendingBrand || pendingModel || pendingGeneration;
        if (!hasAny)
            throw new common_1.BadRequestException('Нет данных для подтверждения');
        const pending = this.pendingRepo.create({
            userId,
            carId: cid,
            pendingBrand: pendingBrand ?? null,
            pendingModel: pendingModel ?? null,
            pendingGeneration: pendingGeneration ?? null,
            status: 'pending',
        });
        await this.pendingRepo.save(pending);
        return { id: pending.id };
    }
    async listPending() {
        const list = await this.pendingRepo.find({
            where: { status: 'pending' },
            order: { createdAt: 'DESC' },
        });
        const ids = [...new Set(list.map((p) => p.carId?.trim()).filter((id) => !!id))];
        const cars = ids.length ? await this.clientCarRepo.find({ where: { id: (0, typeorm_2.In)(ids) } }) : [];
        const carById = new Map(cars.map((c) => [c.id, c]));
        const brandIds = new Set();
        const modelIds = new Set();
        for (const c of cars) {
            if (c.brandId != null)
                brandIds.add(c.brandId);
            if (c.modelId != null)
                modelIds.add(c.modelId);
        }
        const brandRows = brandIds.size ? await this.brandRepo.find({ where: { id: (0, typeorm_2.In)([...brandIds]) } }) : [];
        const modelRows = modelIds.size ? await this.modelRepo.find({ where: { id: (0, typeorm_2.In)([...modelIds]) } }) : [];
        const brandById = new Map(brandRows.map((b) => [b.id, b]));
        const modelById = new Map(modelRows.map((m) => [m.id, m]));
        return list.map((p) => {
            const car = carById.get(p.carId);
            let snapB = car?.brand?.trim() || null;
            let snapM = car?.model?.trim() || null;
            if ((!snapB || snapB === '—') && car?.brandId != null) {
                const b = brandById.get(car.brandId);
                if (b?.name?.trim())
                    snapB = b.name.trim();
            }
            if ((!snapM || snapM === '—') && car?.modelId != null) {
                const m = modelById.get(car.modelId);
                if (m?.name?.trim())
                    snapM = m.name.trim();
            }
            return {
                id: p.id,
                userId: p.userId,
                carId: p.carId,
                pendingBrand: p.pendingBrand,
                pendingModel: p.pendingModel,
                pendingGeneration: p.pendingGeneration,
                status: p.status,
                createdAt: p.createdAt,
                carSnapshotBrand: snapB && snapB !== '—' ? snapB : null,
                carSnapshotModel: snapM && snapM !== '—' ? snapM : null,
                carBrandId: car?.brandId ?? null,
                carModelId: car?.modelId ?? null,
            };
        });
    }
    async createBrand(name) {
        const trimmed = name?.trim();
        if (!trimmed)
            throw new common_1.BadRequestException('Название марки обязательно');
        const last = await this.brandRepo.find({ order: { sortOrder: 'DESC' }, take: 1 });
        const nextOrder = (last[0]?.sortOrder ?? 0) + 1;
        const brand = this.brandRepo.create({ name: trimmed, sortOrder: nextOrder });
        await this.brandRepo.save(brand);
        return { id: brand.id, name: brand.name };
    }
    async createModel(brandId, name) {
        const brand = await this.brandRepo.findOne({ where: { id: brandId } });
        if (!brand)
            throw new common_1.NotFoundException('Марка не найдена');
        const trimmed = name?.trim();
        if (!trimmed)
            throw new common_1.BadRequestException('Название модели обязательно');
        const last = await this.modelRepo.find({ where: { brandId }, order: { sortOrder: 'DESC' }, take: 1 });
        const nextOrder = (last[0]?.sortOrder ?? 0) + 1;
        const model = this.modelRepo.create({ brandId, name: trimmed, sortOrder: nextOrder });
        await this.modelRepo.save(model);
        return { id: model.id, name: model.name };
    }
    async createGeneration(modelId, name, yearFrom, yearTo) {
        const model = await this.modelRepo.findOne({ where: { id: modelId } });
        if (!model)
            throw new common_1.NotFoundException('Модель не найдена');
        const trimmed = name?.trim();
        if (!trimmed)
            throw new common_1.BadRequestException('Название поколения обязательно');
        const last = await this.generationRepo.find({ where: { modelId }, order: { sortOrder: 'DESC' }, take: 1 });
        const nextOrder = (last[0]?.sortOrder ?? 0) + 1;
        const gen = this.generationRepo.create({
            modelId,
            name: trimmed,
            sortOrder: nextOrder,
            yearFrom: yearFrom ?? null,
            yearTo: yearTo ?? null,
        });
        await this.generationRepo.save(gen);
        return { id: gen.id, name: gen.name, yearFrom: gen.yearFrom ?? undefined, yearTo: gen.yearTo ?? undefined };
    }
    async approvePending(id) {
        const pending = await this.pendingRepo.findOne({ where: { id, status: 'pending' } });
        if (!pending)
            throw new common_1.NotFoundException('Заявка не найдена или уже обработана');
        const result = {};
        if (pending.pendingBrand) {
            const brand = await this.createBrand(pending.pendingBrand);
            result.brandId = brand.id;
        }
        if (pending.pendingModel && result.brandId) {
            const model = await this.createModel(result.brandId, pending.pendingModel);
            result.modelId = model.id;
        }
        else if (pending.pendingModel) {
            const brands = await this.brandRepo.find({ order: { sortOrder: 'ASC' }, take: 1 });
            if (brands.length) {
                const model = await this.createModel(brands[0].id, pending.pendingModel);
                result.modelId = model.id;
            }
        }
        if (pending.pendingGeneration && result.modelId) {
            const gen = await this.createGeneration(result.modelId, pending.pendingGeneration);
            result.generationId = gen.id;
        }
        else if (pending.pendingGeneration && result.brandId) {
            const models = await this.modelRepo.find({ where: { brandId: result.brandId }, order: { sortOrder: 'ASC' }, take: 1 });
            if (models.length) {
                const gen = await this.createGeneration(models[0].id, pending.pendingGeneration);
                result.generationId = gen.id;
            }
        }
        pending.status = 'approved';
        await this.pendingRepo.save(pending);
        const brandName = result.brandId ? (await this.brandRepo.findOne({ where: { id: result.brandId } }))?.name : null;
        const modelName = result.modelId ? (await this.modelRepo.findOne({ where: { id: result.modelId } }))?.name : null;
        const genName = result.generationId ? (await this.generationRepo.findOne({ where: { id: result.generationId } }))?.name : null;
        const namesText = [brandName, modelName, genName].filter(Boolean).join(' · ') || 'Данные добавлены в справочник.';
        await this.notifications.create({
            userId: pending.userId,
            carId: pending.carId,
            type: 'pending_car_approved',
            title: 'Предложение: указать выбранную разработчиками марку и модель',
            body: `Разработчики добавили в справочник: ${namesText}. Нажмите на уведомление, чтобы обновить карточку авто.`,
            payload: {
                brandId: result.brandId,
                modelId: result.modelId,
                generationId: result.generationId,
                brandName: brandName ?? undefined,
                modelName: modelName ?? undefined,
                generationName: genName ?? undefined,
            },
        });
        return result;
    }
    async rejectPending(id) {
        const pending = await this.pendingRepo.findOne({ where: { id, status: 'pending' } });
        if (!pending)
            throw new common_1.NotFoundException('Заявка не найдена или уже обработана');
        pending.status = 'rejected';
        await this.pendingRepo.save(pending);
        await this.notifications.create({
            userId: pending.userId,
            carId: pending.carId,
            type: 'pending_car_rejected',
            title: 'Требуется переуказать марку, модель и поколение',
            body: 'Разработчики отклонили заявку. Укажите марку, модель и поколение заново в карточке машины.',
        });
    }
    async suggestPending(id, data) {
        const pending = await this.pendingRepo.findOne({ where: { id, status: 'pending' } });
        if (!pending)
            throw new common_1.NotFoundException('Заявка не найдена или уже обработана');
        const brand = await this.brandRepo.findOne({ where: { id: data.brandId } });
        const model = await this.modelRepo.findOne({ where: { id: data.modelId } });
        const gen = await this.generationRepo.findOne({ where: { id: data.generationId } });
        if (!brand || !model || !gen)
            throw new common_1.BadRequestException('Неверные идентификаторы марки/модели/поколения');
        const brandName = brand.name;
        const modelName = model.name;
        const genName = gen.name;
        await this.notifications.create({
            userId: pending.userId,
            carId: pending.carId,
            type: 'pending_car_suggested',
            title: 'Тех-обеспечение предлагает',
            body: `Марка: ${brandName}, Модель: ${modelName}, Поколение: ${genName}. Подтвердите в уведомлении или укажите свой вариант в карточке машины.`,
            payload: {
                suggestedBrandId: data.brandId,
                suggestedModelId: data.modelId,
                suggestedGenerationId: data.generationId,
                suggestedBrandName: brandName,
                suggestedModelName: modelName,
                suggestedGenerationName: genName,
            },
        });
        pending.status = 'suggested';
        await this.pendingRepo.save(pending);
    }
    async deleteBrand(id) {
        const brand = await this.brandRepo.findOne({ where: { id } });
        if (!brand)
            throw new common_1.NotFoundException('Марка не найдена');
        await this.brandRepo.remove(brand);
    }
    async deleteModel(id) {
        const model = await this.modelRepo.findOne({ where: { id } });
        if (!model)
            throw new common_1.NotFoundException('Модель не найдена');
        await this.modelRepo.remove(model);
    }
    async deleteGeneration(id) {
        const gen = await this.generationRepo.findOne({ where: { id } });
        if (!gen)
            throw new common_1.NotFoundException('Поколение не найдено');
        await this.generationRepo.remove(gen);
    }
};
exports.ReferenceService = ReferenceService;
exports.ReferenceService = ReferenceService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(car_brand_entity_1.CarBrand)),
    __param(1, (0, typeorm_1.InjectRepository)(car_model_entity_1.CarModel)),
    __param(2, (0, typeorm_1.InjectRepository)(car_generation_entity_1.CarGeneration)),
    __param(3, (0, typeorm_1.InjectRepository)(pending_car_reference_entity_1.PendingCarReference)),
    __param(4, (0, typeorm_1.InjectRepository)(client_car_entity_1.ClientCar)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_service_1.NotificationsService])
], ReferenceService);
//# sourceMappingURL=reference.service.js.map