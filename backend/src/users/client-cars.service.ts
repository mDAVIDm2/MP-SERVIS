import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { User } from './user.entity';
import { ClientCar } from './client-car.entity';
import { ClientCarFormerOwnership } from './client-car-former-ownership.entity';
import { UserClientHiddenCar } from './user-client-hidden-car.entity';
import { CarTransferService } from './car-transfer.service';
import { Order } from '../orders/order.entity';
import { PendingCarReference } from '../reference/pending-car-reference.entity';
import { Notification } from '../notifications/notification.entity';

const CLIENT_CAR_UPLOAD_DIR = path.join(process.cwd(), 'uploads', 'client-cars');

export interface CreateClientCarBody {
  id?: string;
  brand: string;
  model: string;
  generation?: string | null;
  brand_id?: number | null;
  model_id?: number | null;
  generation_id?: number | null;
  year?: number;
  nickname?: string | null;
  plate_number?: string | null;
  vin?: string | null;
  mileage?: number;
  engine_type?: string | null;
  transmission?: string | null;
  drivetrain?: string | null;
  body_type?: string | null;
  color?: string | null;
  photo_url?: string | null;
  merged_from_orders?: boolean;
}

export interface PatchClientCarBody {
  brand?: string;
  model?: string;
  generation?: string | null;
  brand_id?: number | null;
  model_id?: number | null;
  generation_id?: number | null;
  year?: number;
  nickname?: string | null;
  plate_number?: string | null;
  vin?: string | null;
  mileage?: number;
  engine_type?: string | null;
  transmission?: string | null;
  drivetrain?: string | null;
  body_type?: string | null;
  color?: string | null;
  photo_url?: string | null;
  merged_from_orders?: boolean;
}

@Injectable()
export class ClientCarsService {
  constructor(
    @InjectRepository(ClientCar) private readonly carRepo: Repository<ClientCar>,
    @InjectRepository(UserClientHiddenCar) private readonly hiddenCarRepo: Repository<UserClientHiddenCar>,
    @InjectRepository(ClientCarFormerOwnership) private readonly formerRepo: Repository<ClientCarFormerOwnership>,
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    private readonly carTransfers: CarTransferService,
  ) {}

  /** Нормализация телефона как в заказах (для проверки привязки авто к клиенту). */
  private normalizePhoneForCompare(phone: string): string {
    const digits = String(phone || '').replace(/\D/g, '');
    if (digits.length === 11 && digits.startsWith('8')) return '7' + digits.slice(1);
    return digits;
  }

  private async isCarHiddenForUser(userId: string, carId: string): Promise<boolean> {
    const cid = String(carId || '').trim();
    if (!cid) return false;
    const row = await this.hiddenCarRepo.findOne({ where: { userId, carId: cid } });
    return !!row;
  }

  /** Публичная проверка для раздачи фото гаража (владелец не видит скрытое авто). */
  async isCarHiddenFromClientApp(userId: string, carId: string): Promise<boolean> {
    return this.isCarHiddenForUser(userId, String(carId || '').trim());
  }

  /** Проверка перед hard-delete из Control Center (телефон + car_id). */
  async assertCarLinkedToClientUserForInternal(userId: string, carId: string, clientPhoneRaw: string): Promise<void> {
    const norm = this.normalizePhoneForCompare(clientPhoneRaw);
    if (!norm) throw new BadRequestException('Укажите телефон клиента');
    await this.assertCarLinkedToClientUser(userId, carId, norm);
  }

  private async assertCarLinkedToClientUser(userId: string, carId: string, phoneNorm: string): Promise<void> {
    const cid = String(carId || '').trim();
    if (!cid) throw new NotFoundException('Автомобиль не найден у этого клиента');
    const owned = await this.carRepo.findOne({ where: { id: cid, userId } });
    if (owned) return;
    const orders = await this.orderRepo.find({ where: { carId: cid }, take: 80 });
    const ok = orders.some(
      (o) => this.normalizePhoneForCompare((o as any).clientPhone || '') === phoneNorm,
    );
    if (!ok) {
      throw new NotFoundException('Автомобиль не найден у этого клиента');
    }
  }

  /** Скрыть авто у клиента (запись в user_client_hidden_cars). */
  async hideCarFromClientForInternal(userId: string, carId: string, clientPhoneRaw: string): Promise<void> {
    const norm = this.normalizePhoneForCompare(clientPhoneRaw);
    if (!norm) throw new BadRequestException('Укажите телефон клиента');
    await this.assertCarLinkedToClientUser(userId, carId, norm);
    const cid = String(carId || '').trim();
    const existing = await this.hiddenCarRepo.findOne({ where: { userId, carId: cid } });
    if (existing) return;
    await this.hiddenCarRepo.save(
      this.hiddenCarRepo.create({ userId, carId: cid, hiddenAt: new Date() }),
    );
  }

  /** Вернуть отображение авто клиенту. */
  async restoreCarForClientForInternal(userId: string, carId: string, clientPhoneRaw: string): Promise<void> {
    const norm = this.normalizePhoneForCompare(clientPhoneRaw);
    if (!norm) throw new BadRequestException('Укажите телефон клиента');
    await this.assertCarLinkedToClientUser(userId, carId, norm);
    const cid = String(carId || '').trim();
    await this.hiddenCarRepo.delete({ userId, carId: cid });
  }

  /**
   * После purgeOrdersByCarIdForInternal: скрытия, pending_car_references, car_id в уведомлениях, строка client_cars и файлы.
   */
  async eraseCarAfterHardDeleteForInternal(carId: string): Promise<void> {
    const cid = String(carId || '').trim();
    if (!cid) return;
    await this.hiddenCarRepo.createQueryBuilder().delete().where('car_id = :cid', { cid }).execute();
    await this.carRepo.manager.getRepository(PendingCarReference).delete({ carId: cid });
    await this.carRepo.manager.getRepository(Notification).update({ carId: cid }, { carId: null });
    const car = await this.carRepo.findOne({ where: { id: cid } });
    if (car) {
      const dir = path.join(CLIENT_CAR_UPLOAD_DIR, car.userId, cid);
      if (fs.existsSync(dir)) {
        fs.rmSync(dir, { recursive: true, force: true });
      }
      await this.carRepo.remove(car);
    }
  }

  assertClientUser(user: User): void {
    if ((user.accountRealm ?? 'business') !== 'client') {
      throw new ForbiddenException('Гараж доступен только в клиентском аккаунте');
    }
  }

  /** Удаляет загруженные файлы фото (photo*, включая старый формат photo.jpg). */
  private clearUploadedCarPhotos(ownerUserId: string, carId: string): void {
    const dir = path.join(CLIENT_CAR_UPLOAD_DIR, ownerUserId, carId);
    if (!fs.existsSync(dir)) return;
    for (const name of fs.readdirSync(dir)) {
      const lower = name.toLowerCase();
      if (!lower.startsWith('photo')) continue;
      try {
        fs.unlinkSync(path.join(dir, name));
      } catch {
        /* ignore */
      }
    }
  }

  private toJson(c: ClientCar, extra?: Record<string, unknown>) {
    return {
      id: c.id,
      brand: c.brand,
      model: c.model,
      generation: c.generation,
      brand_id: c.brandId,
      model_id: c.modelId,
      generation_id: c.generationId,
      year: c.year,
      nickname: c.nickname,
      plate_number: c.plateNumber,
      vin: c.vin,
      mileage: c.mileage,
      engine_type: c.engineType,
      transmission: c.transmission,
      drivetrain: c.drivetrain,
      body_type: c.bodyType,
      color: c.color,
      photo_url: c.photoUrl,
      merged_from_orders: c.mergedFromOrders,
      created_at: c.createdAt?.toISOString?.() ?? null,
      updated_at: c.updatedAt?.toISOString?.() ?? null,
      ...(extra || {}),
    };
  }

  async list(userId: string): Promise<{ items: Record<string, unknown>[] }> {
    const rows = await this.carRepo
      .createQueryBuilder('c')
      .leftJoin(
        UserClientHiddenCar,
        'h',
        'h.user_id = c.user_id AND h.car_id = c.id',
      )
      .where('c.user_id = :uid', { uid: userId })
      .andWhere('h.id IS NULL')
      .orderBy('c.created_at', 'ASC')
      .getMany();
    const owned = rows.map((r) => this.toJson(r, { ownership_mode: 'owner' }));

    const formerRows = await this.formerRepo.find({ where: { userId } });
    if (!formerRows.length) return { items: owned };

    const fids = [...new Set(formerRows.map((f) => String(f.carId || '').trim()).filter(Boolean))];
    const formerCars = fids.length ? await this.carRepo.find({ where: { id: In(fids) } }) : [];
    const byId = new Map(formerCars.map((c) => [c.id, c]));
    const formerItems: Record<string, unknown>[] = [];
    for (const f of formerRows) {
      const c = byId.get(f.carId);
      if (!c) continue;
      formerItems.push(
        this.toJson(c, {
          ownership_mode: 'former',
          transfer_id: f.transferId,
        }),
      );
    }
    return { items: [...owned, ...formerItems] };
  }

  async create(user: User, body: CreateClientCarBody): Promise<Record<string, unknown>> {
    this.assertClientUser(user);
    const rawId = body.id?.trim();
    const id = rawId && rawId.length > 0 ? rawId.slice(0, 64) : randomUUID();

    const existingById = await this.carRepo.findOne({ where: { id } });
    if (existingById) {
      if (existingById.userId !== user.id) {
        throw new ConflictException('Такой id автомобиля уже занят');
      }
      return this.patch(user, id, {
        brand: body.brand,
        model: body.model,
        generation: body.generation ?? null,
        brand_id: body.brand_id ?? null,
        model_id: body.model_id ?? null,
        generation_id: body.generation_id ?? null,
        year: body.year ?? 0,
        nickname: body.nickname ?? null,
        plate_number: body.plate_number ?? null,
        vin: body.vin ?? null,
        mileage: body.mileage ?? 0,
        engine_type: body.engine_type ?? null,
        transmission: body.transmission ?? null,
        drivetrain: body.drivetrain ?? null,
        body_type: body.body_type ?? null,
        color: body.color ?? null,
        photo_url: body.photo_url !== undefined ? body.photo_url : existingById.photoUrl,
        merged_from_orders: body.merged_from_orders ?? existingById.mergedFromOrders,
      });
    }

    const row = this.carRepo.create({
      id,
      userId: user.id,
      brand: String(body.brand ?? '').trim() || 'Авто',
      model: String(body.model ?? '').trim() || '—',
      generation: body.generation != null ? String(body.generation).trim() || null : null,
      brandId: body.brand_id ?? null,
      modelId: body.model_id ?? null,
      generationId: body.generation_id ?? null,
      year: Number(body.year) || 0,
      nickname: body.nickname != null ? String(body.nickname).trim() || null : null,
      plateNumber: body.plate_number != null ? String(body.plate_number).trim() || null : null,
      vin: body.vin != null ? String(body.vin).trim() || null : null,
      mileage: Number(body.mileage) || 0,
      engineType: body.engine_type != null ? String(body.engine_type).trim() || null : null,
      transmission: body.transmission != null ? String(body.transmission).trim() || null : null,
      drivetrain: body.drivetrain != null ? String(body.drivetrain).trim() || null : null,
      bodyType: body.body_type != null ? String(body.body_type).trim() || null : null,
      color: body.color != null ? String(body.color).trim() || null : null,
      photoUrl: body.photo_url != null ? String(body.photo_url).trim() || null : null,
      mergedFromOrders: body.merged_from_orders === true,
    });
    await this.carRepo.save(row);
    return this.toJson(row);
  }

  async patch(user: User, carId: string, body: PatchClientCarBody): Promise<Record<string, unknown>> {
    this.assertClientUser(user);
    if (await this.carTransfers.isFormerOwner(user.id, carId)) {
      throw new ForbiddenException('Редактирование недоступно: вы передали этот автомобиль');
    }
    const c = await this.carRepo.findOne({ where: { id: carId } });
    if (!c || c.userId !== user.id) throw new NotFoundException('Автомобиль не найден');
    if (await this.isCarHiddenForUser(user.id, carId)) throw new NotFoundException('Автомобиль не найден');

    if (body.brand !== undefined) c.brand = String(body.brand).trim() || c.brand;
    if (body.model !== undefined) c.model = String(body.model).trim() || c.model;
    if (body.generation !== undefined) c.generation = body.generation != null ? String(body.generation).trim() || null : null;
    if (body.brand_id !== undefined) c.brandId = body.brand_id;
    if (body.model_id !== undefined) c.modelId = body.model_id;
    if (body.generation_id !== undefined) c.generationId = body.generation_id;
    if (body.year !== undefined) c.year = Number(body.year) || 0;
    if (body.nickname !== undefined) c.nickname = body.nickname != null ? String(body.nickname).trim() || null : null;
    if (body.plate_number !== undefined) c.plateNumber = body.plate_number != null ? String(body.plate_number).trim() || null : null;
    if (body.vin !== undefined) c.vin = body.vin != null ? String(body.vin).trim() || null : null;
    if (body.mileage !== undefined) c.mileage = Number(body.mileage) || 0;
    if (body.engine_type !== undefined) c.engineType = body.engine_type != null ? String(body.engine_type).trim() || null : null;
    if (body.transmission !== undefined) c.transmission = body.transmission != null ? String(body.transmission).trim() || null : null;
    if (body.drivetrain !== undefined) c.drivetrain = body.drivetrain != null ? String(body.drivetrain).trim() || null : null;
    if (body.body_type !== undefined) c.bodyType = body.body_type != null ? String(body.body_type).trim() || null : null;
    if (body.color !== undefined) c.color = body.color != null ? String(body.color).trim() || null : null;
    if (body.photo_url !== undefined) {
      c.photoUrl = body.photo_url != null ? String(body.photo_url).trim() || null : null;
      if (c.photoUrl === null) {
        this.clearUploadedCarPhotos(user.id, carId);
      }
    }
    if (body.merged_from_orders !== undefined) c.mergedFromOrders = body.merged_from_orders === true;

    await this.carRepo.save(c);
    return this.toJson(c);
  }

  async remove(user: User, carId: string): Promise<void> {
    this.assertClientUser(user);
    if (await this.carTransfers.isFormerOwner(user.id, carId)) {
      throw new ForbiddenException('Удаление недоступно. Используйте «Забыть автомобиль» в карточке.');
    }
    const c = await this.carRepo.findOne({ where: { id: carId } });
    if (!c || c.userId !== user.id) throw new NotFoundException('Автомобиль не найден');
    if (await this.isCarHiddenForUser(user.id, carId)) throw new NotFoundException('Автомобиль не найден');
    const dir = path.join(CLIENT_CAR_UPLOAD_DIR, user.id, carId);
    if (fs.existsSync(dir)) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
    await this.carRepo.remove(c);
  }

  async saveCarPhoto(user: User, carId: string, file: Express.Multer.File): Promise<Record<string, unknown>> {
    this.assertClientUser(user);
    if (await this.carTransfers.isFormerOwner(user.id, carId)) {
      throw new ForbiddenException('Загрузка фото недоступна: вы передали этот автомобиль');
    }
    const c = await this.carRepo.findOne({ where: { id: carId } });
    if (!c || c.userId !== user.id) throw new NotFoundException('Автомобиль не найден');
    if (await this.isCarHiddenForUser(user.id, carId)) throw new NotFoundException('Автомобиль не найден');
    if (!file || (!file.buffer && !file.path)) {
      throw new BadRequestException('Передайте изображение в поле file');
    }
    const extRaw = path.extname(file.originalname || '').toLowerCase();
    const ext = extRaw && extRaw.length <= 6 && /^\.[a-z0-9]+$/.test(extRaw) ? extRaw : '.jpg';
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    if (!allowed.includes(ext)) {
      throw new BadRequestException('Допустимы изображения: jpg, png, webp');
    }
    // Уникальное имя — иначе URL не меняется и клиент (CachedNetworkImage) показывает старый кадр.
    const filename = `photo-${randomUUID()}${ext}`;
    const dir = path.join(CLIENT_CAR_UPLOAD_DIR, user.id, carId);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    this.clearUploadedCarPhotos(user.id, carId);
    const filePath = path.join(dir, filename);
    if (file.buffer?.length) {
      fs.writeFileSync(filePath, file.buffer);
    } else if (file.path && fs.existsSync(file.path)) {
      fs.copyFileSync(file.path, filePath);
    } else {
      throw new BadRequestException('Пустой файл');
    }
    const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
    const url = `${baseUrl}/profile/cars/${encodeURIComponent(carId)}/photo-file/${encodeURIComponent(filename)}`;
    c.photoUrl = url;
    await this.carRepo.save(c);
    return this.toJson(c);
  }

  /** Строка «как в заказе» для списка Control Center: марка, модель, год, при необходимости госномер. */
  private formatGarageCarInfoLine(c: ClientCar): string {
    const brand = String(c.brand || '').trim();
    const model = String(c.model || '').trim();
    const gen = (c.generation || '').trim();
    const year = c.year && c.year > 0 ? String(c.year) : '';
    const parts: string[] = [];
    if (brand) parts.push(brand);
    if (model) parts.push(model);
    if (gen) parts.push(`(${gen})`);
    let line =
      parts.length > 0
        ? year
          ? `${parts.join(' ')}, ${year}`
          : parts.join(' ')
        : year
          ? `Автомобиль, ${year}`
          : 'Автомобиль';
    const plate = (c.plateNumber || '').trim();
    if (plate) line = `${line} · ${plate}`;
    return line;
  }

  /**
   * Дополняет агрегат из заказов авто из гаража (client_cars), по которым ещё не было ни одного заказа.
   * Иначе в Control Center машина появляется только после первой записи.
   */
  async mergeGarageOnlyCarsIntoAggregatedInternalList(
    items: Array<{
      client_phone: string;
      car_id: string;
      car_info: string;
      client_name: string | null;
      orders_count: number;
      last_order_at: string;
      car_photo_url: string | null;
    }>,
  ): Promise<void> {
    const keys = new Set(items.map((i) => `${i.client_phone}|${i.car_id}`));
    const garageCars = await this.carRepo
      .createQueryBuilder('c')
      .innerJoinAndSelect('c.user', 'u')
      .where('u.account_realm = :realm', { realm: 'client' })
      .getMany();

    for (const gc of garageCars) {
      const u = gc.user as User;
      const phone = this.normalizePhoneForCompare(u?.phone || '');
      const carId = String(gc.id || '').trim();
      if (!phone || !carId) continue;
      const key = `${phone}|${carId}`;
      if (keys.has(key)) continue;
      keys.add(key);
      const photo = (gc.photoUrl || '').trim() || null;
      const clientName = (u?.name || '').trim() || null;
      items.push({
        client_phone: phone,
        car_id: carId,
        car_info: this.formatGarageCarInfoLine(gc),
        client_name: clientName,
        orders_count: 0,
        last_order_at: (gc.createdAt ?? new Date()).toISOString(),
        car_photo_url: photo,
      });
    }
    items.sort((a, b) => b.last_order_at.localeCompare(a.last_order_at));
  }

  /**
   * Если в заказах нет car_photo_url, подставляет URL из гаража (client_cars) при совпадении телефона владельца.
   */
  async enrichAggregatedClientCarsWithGaragePhotos(
    items: Array<{ client_phone: string; car_id: string; car_photo_url?: string | null }>,
  ): Promise<void> {
    if (!items?.length) return;
    const missing = items.filter((i) => !String(i.car_photo_url || '').trim());
    if (!missing.length) return;
    const carIds = [...new Set(missing.map((m) => String(m.car_id || '').trim()).filter(Boolean))];
    if (!carIds.length) return;
    const cars = await this.carRepo.find({
      where: { id: In(carIds) },
      relations: ['user'],
    });
    for (const item of items) {
      if (String(item.car_photo_url || '').trim()) continue;
      const cid = String(item.car_id || '').trim();
      const car = cars.find((c) => c.id === cid);
      const pu = (car?.photoUrl || '').trim();
      if (!car || !pu) continue;
      const orderPhone = this.normalizePhoneForCompare(item.client_phone || '');
      const userPhone = this.normalizePhoneForCompare((car.user as User)?.phone || '');
      if (orderPhone && userPhone && orderPhone === userPhone) {
        item.car_photo_url = pu;
      }
    }
  }

  async findCarEntityById(carId: string): Promise<ClientCar | null> {
    const id = carId?.trim();
    if (!id) return null;
    return this.carRepo.findOne({ where: { id } });
  }

  getCarPhotoFilePath(ownerUserId: string, carId: string, filename: string): string | null {
    const safeName = path.basename(filename);
    if (!safeName || safeName.includes('..')) return null;
    const fullPath = path.join(CLIENT_CAR_UPLOAD_DIR, ownerUserId, carId, safeName);
    if (!fs.existsSync(fullPath)) return null;
    return fullPath;
  }

  async assertOwnsCar(viewer: User, carId: string): Promise<ClientCar> {
    if (await this.carTransfers.isFormerOwner(viewer.id, carId)) {
      throw new ForbiddenException('Действие недоступно для бывшего владельца');
    }
    const c = await this.carRepo.findOne({ where: { id: carId } });
    if (!c || c.userId !== viewer.id) throw new NotFoundException('Автомобиль не найден');
    if (await this.isCarHiddenForUser(viewer.id, carId)) throw new NotFoundException('Автомобиль не найден');
    return c;
  }
}
