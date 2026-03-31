import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CarBrand } from './car-brand.entity';
import { CarModel } from './car-model.entity';
import { CarGeneration } from './car-generation.entity';
import { PendingCarReference } from './pending-car-reference.entity';
import { NotificationsService } from '../notifications/notifications.service';

export interface CarBrandDto {
  id: number;
  name: string;
}

export interface CarModelDto {
  id: number;
  name: string;
}

export interface CarGenerationDto {
  id: number;
  name: string;
  yearFrom?: number | null;
  yearTo?: number | null;
}

@Injectable()
export class ReferenceService {
  constructor(
    @InjectRepository(CarBrand) private brandRepo: Repository<CarBrand>,
    @InjectRepository(CarModel) private modelRepo: Repository<CarModel>,
    @InjectRepository(CarGeneration) private generationRepo: Repository<CarGeneration>,
    @InjectRepository(PendingCarReference) private pendingRepo: Repository<PendingCarReference>,
    private notifications: NotificationsService,
  ) {}

  async getCarBrands(): Promise<CarBrandDto[]> {
    const list = await this.brandRepo.find({
      order: { sortOrder: 'ASC', name: 'ASC' },
    });
    return list.map((b) => ({ id: b.id, name: b.name }));
  }

  async getCarModels(brandId: number): Promise<CarModelDto[]> {
    const brand = await this.brandRepo.findOne({ where: { id: brandId } });
    if (!brand) throw new NotFoundException('Марка не найдена');
    const list = await this.modelRepo.find({
      where: { brandId },
      order: { sortOrder: 'ASC', name: 'ASC' },
    });
    return list.map((m) => ({ id: m.id, name: m.name }));
  }

  async getCarGenerations(modelId: number): Promise<CarGenerationDto[]> {
    const model = await this.modelRepo.findOne({ where: { id: modelId } });
    if (!model) throw new NotFoundException('Модель не найдена');
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

  /** Сохранить запись «ожидает подтверждения» (марка/модель/поколение введены вручную). */
  async createPending(
    userId: string,
    carId: string,
    data: { pendingBrand?: string; pendingModel?: string; pendingGeneration?: string },
  ): Promise<{ id: string }> {
    const hasAny = data.pendingBrand?.trim() || data.pendingModel?.trim() || data.pendingGeneration?.trim();
    if (!hasAny) throw new BadRequestException('Нет данных для подтверждения');
    const pending = this.pendingRepo.create({
      userId,
      carId,
      pendingBrand: data.pendingBrand?.trim() || null,
      pendingModel: data.pendingModel?.trim() || null,
      pendingGeneration: data.pendingGeneration?.trim() || null,
      status: 'pending',
    });
    await this.pendingRepo.save(pending);
    return { id: pending.id };
  }

  /** Список заявок «ожидает подтверждения» (для разработчиков / админки). */
  async listPending(): Promise<
    { id: string; userId: string; carId: string; pendingBrand: string | null; pendingModel: string | null; pendingGeneration: string | null; status: string; createdAt: Date }[]
  > {
    const list = await this.pendingRepo.find({
      where: { status: 'pending' },
      order: { createdAt: 'DESC' },
    });
    return list.map((p) => ({
      id: p.id,
      userId: p.userId,
      carId: p.carId,
      pendingBrand: p.pendingBrand,
      pendingModel: p.pendingModel,
      pendingGeneration: p.pendingGeneration,
      status: p.status,
      createdAt: p.createdAt,
    }));
  }

  /** Добавить марку (для админки). */
  async createBrand(name: string): Promise<CarBrandDto> {
    const trimmed = name?.trim();
    if (!trimmed) throw new BadRequestException('Название марки обязательно');
    const last = await this.brandRepo.find({ order: { sortOrder: 'DESC' }, take: 1 });
    const nextOrder = (last[0]?.sortOrder ?? 0) + 1;
    const brand = this.brandRepo.create({ name: trimmed, sortOrder: nextOrder });
    await this.brandRepo.save(brand);
    return { id: brand.id, name: brand.name };
  }

  /** Добавить модель (для админки). */
  async createModel(brandId: number, name: string): Promise<CarModelDto> {
    const brand = await this.brandRepo.findOne({ where: { id: brandId } });
    if (!brand) throw new NotFoundException('Марка не найдена');
    const trimmed = name?.trim();
    if (!trimmed) throw new BadRequestException('Название модели обязательно');
    const last = await this.modelRepo.find({ where: { brandId }, order: { sortOrder: 'DESC' }, take: 1 });
    const nextOrder = (last[0]?.sortOrder ?? 0) + 1;
    const model = this.modelRepo.create({ brandId, name: trimmed, sortOrder: nextOrder });
    await this.modelRepo.save(model);
    return { id: model.id, name: model.name };
  }

  /** Добавить поколение (для админки). */
  async createGeneration(modelId: number, name: string, yearFrom?: number | null, yearTo?: number | null): Promise<CarGenerationDto> {
    const model = await this.modelRepo.findOne({ where: { id: modelId } });
    if (!model) throw new NotFoundException('Модель не найдена');
    const trimmed = name?.trim();
    if (!trimmed) throw new BadRequestException('Название поколения обязательно');
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

  /** Подтвердить заявку: добавить марку/модель/поколение в справочник и пометить заявку как approved. */
  async approvePending(id: string): Promise<{ brandId?: number; modelId?: number; generationId?: number }> {
    const pending = await this.pendingRepo.findOne({ where: { id, status: 'pending' } });
    if (!pending) throw new NotFoundException('Заявка не найдена или уже обработана');
    const result: { brandId?: number; modelId?: number; generationId?: number } = {};
    if (pending.pendingBrand) {
      const brand = await this.createBrand(pending.pendingBrand);
      result.brandId = brand.id;
    }
    if (pending.pendingModel && result.brandId) {
      const model = await this.createModel(result.brandId, pending.pendingModel);
      result.modelId = model.id;
    } else if (pending.pendingModel) {
      const brands = await this.brandRepo.find({ order: { sortOrder: 'ASC' }, take: 1 });
      if (brands.length) {
        const model = await this.createModel(brands[0].id, pending.pendingModel);
        result.modelId = model.id;
      }
    }
    if (pending.pendingGeneration && result.modelId) {
      const gen = await this.createGeneration(result.modelId, pending.pendingGeneration);
      result.generationId = gen.id;
    } else if (pending.pendingGeneration && result.brandId) {
      const models = await this.modelRepo.find({ where: { brandId: result.brandId }, order: { sortOrder: 'ASC' }, take: 1 });
      if (models.length) {
        const gen = await this.createGeneration(models[0].id, pending.pendingGeneration);
        result.generationId = gen.id;
      }
    }
    (pending as any).status = 'approved';
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

  /** Отклонить заявку. */
  async rejectPending(id: string): Promise<void> {
    const pending = await this.pendingRepo.findOne({ where: { id, status: 'pending' } });
    if (!pending) throw new NotFoundException('Заявка не найдена или уже обработана');
    (pending as any).status = 'rejected';
    await this.pendingRepo.save(pending);
    await this.notifications.create({
      userId: pending.userId,
      carId: pending.carId,
      type: 'pending_car_rejected',
      title: 'Требуется переуказать марку, модель и поколение',
      body: 'Разработчики отклонили заявку. Укажите марку, модель и поколение заново в карточке машины.',
    });
  }

  /** Предложить пользователю вариант из справочника (марка/модель/поколение). После отправки заявка считается обработанной (не показывается в списке). */
  async suggestPending(
    id: string,
    data: { brandId: number; modelId: number; generationId: number },
  ): Promise<void> {
    const pending = await this.pendingRepo.findOne({ where: { id, status: 'pending' } });
    if (!pending) throw new NotFoundException('Заявка не найдена или уже обработана');
    const brand = await this.brandRepo.findOne({ where: { id: data.brandId } });
    const model = await this.modelRepo.findOne({ where: { id: data.modelId } });
    const gen = await this.generationRepo.findOne({ where: { id: data.generationId } });
    if (!brand || !model || !gen) throw new BadRequestException('Неверные идентификаторы марки/модели/поколения');
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
    (pending as any).status = 'suggested';
    await this.pendingRepo.save(pending);
  }

  async deleteBrand(id: number): Promise<void> {
    const brand = await this.brandRepo.findOne({ where: { id } });
    if (!brand) throw new NotFoundException('Марка не найдена');
    await this.brandRepo.remove(brand);
  }

  async deleteModel(id: number): Promise<void> {
    const model = await this.modelRepo.findOne({ where: { id } });
    if (!model) throw new NotFoundException('Модель не найдена');
    await this.modelRepo.remove(model);
  }

  async deleteGeneration(id: number): Promise<void> {
    const gen = await this.generationRepo.findOne({ where: { id } });
    if (!gen) throw new NotFoundException('Поколение не найдено');
    await this.generationRepo.remove(gen);
  }
}
