import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  forwardRef,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import * as fs from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { In } from 'typeorm';
import { User } from './user.entity';
import { ClientCar } from './client-car.entity';
import { ClientCarTransfer } from './client-car-transfer.entity';
import { ClientCarFormerOwnership } from './client-car-former-ownership.entity';
import { UsersService } from './users.service';
import { NotificationsService } from '../notifications/notifications.service';
import { Order } from '../orders/order.entity';
import { Chat } from '../chats/chat.entity';

const PROFILE_NOTES_SERVER_KEY = 'profile_notes_json';

/** Ключи как в клиенте `ClientAppStateSchema` — снимок ТО в `users.client_app_state`. */
const MAINTENANCE_CONFIGS_JSON_KEY = 'maintenance_reminder_configs_json';
const MAINTENANCE_RECORDS_JSON_KEY = 'maintenance_reminder_records_json';
const MAINTENANCE_SYNCED_ORDER_IDS_JSON_KEY = 'maintenance_synced_order_ids_json';

const CLIENT_CAR_UPLOAD_DIR = path.join(process.cwd(), 'uploads', 'client-cars');

export interface CreateCarTransferBody {
  car_id: string;
  /** Телефон получателя (как вводит пользователь). */
  to_phone: string;
  /** share_order_history и др. — для клиента и аналитики. */
  options?: Record<string, unknown>;
}

@Injectable()
export class CarTransferService {
  constructor(
    @InjectRepository(ClientCarTransfer) private readonly transferRepo: Repository<ClientCarTransfer>,
    @InjectRepository(ClientCarFormerOwnership) private readonly formerRepo: Repository<ClientCarFormerOwnership>,
    @InjectRepository(ClientCar) private readonly carRepo: Repository<ClientCar>,
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Chat) private readonly chatRepo: Repository<Chat>,
    private readonly usersService: UsersService,
    @Inject(forwardRef(() => NotificationsService)) private readonly notifications: NotificationsService,
  ) {}

  private assertClientUser(user: User): void {
    if ((user.accountRealm ?? 'business') !== 'client') {
      throw new ForbiddenException('Доступно только в клиентском аккаунте');
    }
  }

  /** Нормализация телефона как в заказах. */
  normalizePhoneForCompare(phone: string): string {
    const digits = String(phone || '').replace(/\D/g, '');
    if (digits.length === 11 && digits.startsWith('8')) return '7' + digits.slice(1);
    if (digits.length === 10 && !digits.startsWith('7')) return '7' + digits;
    return digits;
  }

  private moveCarUploadFolder(fromUserId: string, toUserId: string, carId: string): void {
    const from = path.join(CLIENT_CAR_UPLOAD_DIR, fromUserId, carId);
    const to = path.join(CLIENT_CAR_UPLOAD_DIR, toUserId, carId);
    if (!fs.existsSync(from)) return;
    fs.mkdirSync(path.dirname(to), { recursive: true });
    if (fs.existsSync(to)) {
      fs.rmSync(to, { recursive: true, force: true });
    }
    fs.renameSync(from, to);
  }

  private transferToJson(t: ClientCarTransfer, car?: ClientCar | null) {
    return {
      id: t.id,
      car_id: t.carId,
      from_user_id: t.fromUserId,
      to_user_id: t.toUserId,
      to_phone_norm: t.toPhoneNorm,
      status: t.status,
      options: t.options ?? null,
      created_at: t.createdAt?.toISOString?.() ?? null,
      updated_at: t.updatedAt?.toISOString?.() ?? null,
      car_label: car
        ? [car.brand, car.model, car.year ? String(car.year) : ''].filter(Boolean).join(' ')
        : null,
    };
  }

  /**
   * При первой регистрации/привязке номера — связать входящие запросы, ожидавшие этот телефон.
   */
  async linkPendingTransfersForNewUser(userId: string, phoneRaw: string): Promise<void> {
    const norm = this.normalizePhoneForCompare(phoneRaw);
    if (!norm) return;
    const pending = await this.transferRepo.find({
      where: { status: 'pending', toUserId: IsNull(), toPhoneNorm: norm },
    });
    for (const t of pending) {
      t.toUserId = userId;
      await this.transferRepo.save(t);
      await this.notifyIncomingTransferRequest(t);
    }
  }

  private async notifyIncomingTransferRequest(t: ClientCarTransfer): Promise<void> {
    if (!t.toUserId) return;
    const from = await this.usersService.findById(t.fromUserId);
    const name = (from?.name || '').trim() || 'Владелец';
    const car = await this.carRepo.findOne({ where: { id: t.carId } });
    const label = car
      ? `${(car.brand || '').trim()} ${(car.model || '').trim()}`.trim() || 'Автомобиль'
      : 'Автомобиль';
    await this.notifications.create({
      userId: t.toUserId,
      carId: t.carId,
      type: 'car_transfer_request',
      title: 'Запрос на передачу автомобиля',
      body: `${name} передаёт вам «${label}». Откройте гараж, чтобы принять или отклонить.`,
      payload: {
        transfer_id: t.id,
        car_id: t.carId,
        from_user_id: t.fromUserId,
      },
    });
  }

  private async notifyTransferOutcome(
    userId: string,
    title: string,
    body: string,
    payload: Record<string, unknown>,
    carId: string,
  ): Promise<void> {
    await this.notifications.create({
      userId,
      carId,
      type: 'car_transfer_result',
      title,
      body,
      payload,
    });
  }

  async create(user: User, body: CreateCarTransferBody): Promise<Record<string, unknown>> {
    this.assertClientUser(user);
    const carId = String(body.car_id || '').trim();
    if (!carId) throw new BadRequestException('Укажите car_id');
    const toNorm = this.normalizePhoneForCompare(body.to_phone || '');
    if (toNorm.length < 11) throw new BadRequestException('Укажите корректный номер телефона получателя');
    const selfNorm = this.normalizePhoneForCompare(user.phone || '');
    if (selfNorm && toNorm === selfNorm) {
      throw new BadRequestException('Нельзя передать автомобиль самому себе');
    }

    const existingPending = await this.transferRepo.findOne({ where: { carId, status: 'pending' } });
    if (existingPending) {
      throw new ConflictException('По этому автомобилю уже есть активный запрос передачи');
    }

    const car = await this.carRepo.findOne({ where: { id: carId } });
    if (!car || car.userId !== user.id) {
      throw new NotFoundException('Автомобиль не найден');
    }

    const toUserId = await this.usersService.findIdByNormalizedPhone(toNorm, 'client');
    const opts = body.options && typeof body.options === 'object' ? body.options : null;

    const row = this.transferRepo.create({
      carId,
      fromUserId: user.id,
      toUserId: toUserId ?? null,
      toPhoneNorm: toNorm,
      status: 'pending',
      options: opts,
    });
    const saved = await this.transferRepo.save(row);

    if (saved.toUserId) {
      await this.notifyIncomingTransferRequest(saved);
    }

    const c = await this.carRepo.findOne({ where: { id: carId } });
    return this.transferToJson(saved, c);
  }

  async listIncoming(user: User): Promise<{ items: Record<string, unknown>[] }> {
    this.assertClientUser(user);
    const norm = this.normalizePhoneForCompare(user.phone || '');
    const qb = this.transferRepo
      .createQueryBuilder('t')
      .where('t.status = :st', { st: 'pending' })
      .orderBy('t.created_at', 'DESC');
    if (norm.length >= 10) {
      qb.andWhere('(t.to_user_id = :uid OR (t.to_user_id IS NULL AND t.to_phone_norm = :pn))', {
        uid: user.id,
        pn: norm,
      });
    } else {
      qb.andWhere('t.to_user_id = :uid', { uid: user.id });
    }
    const rows = await qb.getMany();
    const items: Record<string, unknown>[] = [];
    for (const t of rows) {
      const c = await this.carRepo.findOne({ where: { id: t.carId } });
      items.push(this.transferToJson(t, c));
    }
    return { items };
  }

  async listOutgoing(user: User): Promise<{ items: Record<string, unknown>[] }> {
    this.assertClientUser(user);
    const rows = await this.transferRepo.find({
      where: { fromUserId: user.id },
      order: { createdAt: 'DESC' },
      take: 50,
    });
    const items: Record<string, unknown>[] = [];
    for (const t of rows) {
      const c = await this.carRepo.findOne({ where: { id: t.carId } });
      items.push(this.transferToJson(t, c));
    }
    return { items };
  }

  private async assertRecipient(transfer: ClientCarTransfer, user: User): Promise<void> {
    const norm = this.normalizePhoneForCompare(user.phone || '');
    if (transfer.toUserId === user.id) return;
    if (!transfer.toUserId && transfer.toPhoneNorm && transfer.toPhoneNorm === norm) return;
    throw new ForbiddenException('Этот запрос предназначен другому пользователю');
  }

  async accept(user: User, transferId: string): Promise<Record<string, unknown>> {
    this.assertClientUser(user);
    const t = await this.transferRepo.findOne({ where: { id: transferId } });
    if (!t || t.status !== 'pending') throw new NotFoundException('Запрос не найден');
    await this.assertRecipient(t, user);

    const car = await this.carRepo.findOne({ where: { id: t.carId } });
    if (!car || car.userId !== t.fromUserId) {
      throw new ConflictException('Состояние автомобиля изменилось, запрос недействителен');
    }

    const fromUserId = t.fromUserId;
    const toUserId = user.id;
    const carId = t.carId;

    await this.transferRepo.manager.transaction(async (em) => {
      const transferRepo = em.getRepository(ClientCarTransfer);
      const carRepo = em.getRepository(ClientCar);
      const formerRepo = em.getRepository(ClientCarFormerOwnership);

      const fresh = await transferRepo.findOne({ where: { id: transferId, status: 'pending' } });
      if (!fresh) throw new ConflictException('Запрос уже обработан');
      const c = await carRepo.findOne({ where: { id: carId } });
      if (!c || c.userId !== fromUserId) throw new ConflictException('Автомобиль уже передан');

      this.moveCarUploadFolder(fromUserId, toUserId, carId);

      c.userId = toUserId;
      await carRepo.save(c);

      await formerRepo.save(
        formerRepo.create({
          userId: fromUserId,
          carId,
          transferId: t.id,
        }),
      );

      fresh.status = 'accepted';
      fresh.toUserId = toUserId;
      await transferRepo.save(fresh);
    });

    await this.applyTransferSideEffects(fromUserId, toUserId, carId, t.options ?? null);
    await this.reassignPendingOrdersToNewOwner(carId, toUserId);

    const uname = (user.name || '').trim() || 'Получатель';
    await this.notifyTransferOutcome(
      fromUserId,
      'Передача автомобиля принята',
      `${uname} принял(а) ваш автомобиль.`,
      { transfer_id: transferId, car_id: carId, outcome: 'accepted' },
      carId,
    );

    const updated = await this.transferRepo.findOne({ where: { id: transferId } });
    const c2 = await this.carRepo.findOne({ where: { id: carId } });
    return this.transferToJson(updated!, c2);
  }

  async reject(user: User, transferId: string): Promise<Record<string, unknown>> {
    this.assertClientUser(user);
    const t = await this.transferRepo.findOne({ where: { id: transferId } });
    if (!t || t.status !== 'pending') throw new NotFoundException('Запрос не найден');
    await this.assertRecipient(t, user);
    t.status = 'rejected';
    t.toUserId = t.toUserId ?? user.id;
    await this.transferRepo.save(t);

    await this.notifyTransferOutcome(
      t.fromUserId,
      'Передача автомобиля отклонена',
      `${(user.name || '').trim() || 'Получатель'} отклонил(а) запрос.`,
      { transfer_id: transferId, car_id: t.carId, outcome: 'rejected' },
      t.carId,
    );

    const c = await this.carRepo.findOne({ where: { id: t.carId } });
    return this.transferToJson(t, c);
  }

  async cancel(user: User, transferId: string): Promise<Record<string, unknown>> {
    this.assertClientUser(user);
    const t = await this.transferRepo.findOne({ where: { id: transferId } });
    if (!t || t.status !== 'pending') throw new NotFoundException('Запрос не найден');
    if (t.fromUserId !== user.id) throw new ForbiddenException('Отменить может только отправитель');
    t.status = 'cancelled';
    await this.transferRepo.save(t);
    const c = await this.carRepo.findOne({ where: { id: t.carId } });
    return this.transferToJson(t, c);
  }

  /** Убрать авто из гаража бывшего владельца (read-only запись). */
  async forgetFormerCar(user: User, carId: string): Promise<{ ok: boolean }> {
    this.assertClientUser(user);
    const cid = String(carId || '').trim();
    if (!cid) throw new BadRequestException('Укажите автомобиль');
    const row = await this.formerRepo.findOne({ where: { userId: user.id, carId: cid } });
    if (!row) throw new NotFoundException('Запись не найдена');
    await this.formerRepo.remove(row);
    return { ok: true };
  }

  async isFormerOwner(userId: string, carId: string): Promise<boolean> {
    const cid = String(carId || '').trim();
    if (!cid) return false;
    const row = await this.formerRepo.findOne({ where: { userId, carId: cid } });
    return !!row;
  }

  /** Активные заказы по этому авто переводим на телефон/имя нового владельца (уведомления и клиентское приложение). */
  private async reassignPendingOrdersToNewOwner(carId: string, newUserId: string): Promise<void> {
    const u = await this.usersService.findById(newUserId);
    if (!u?.phone) return;
    const phoneDigits = this.normalizePhoneForCompare(u.phone);
    if (phoneDigits.length < 10) return;
    const clientName = String(u.name || '').trim() || 'Клиент';
    await this.orderRepo
      .createQueryBuilder()
      .update(Order)
      .set({ clientPhone: phoneDigits, clientName })
      .where('car_id = :carId', { carId })
      .andWhere('status IN (:...st)', {
        st: ['pending_confirmation', 'confirmed', 'in_progress', 'pending_approval'],
      })
      .execute();
  }

  /**
   * Для каждого авто — время приёма передачи, после которого заказы по машине видны новому владельцу,
   * если в опциях было `share_order_history: false` (заказы старше этой метки скрываются).
   */
  async getCarOrderHistoryCutoffMap(clientUserId: string): Promise<Map<string, Date>> {
    const rows = await this.transferRepo.find({
      where: { toUserId: clientUserId, status: 'accepted' },
    });
    const m = new Map<string, Date>();
    for (const t of rows) {
      if (!this.isShareOrderHistoryFalse(t.options)) continue;
      const cid = String(t.carId || '').trim();
      if (!cid) continue;
      const prev = m.get(cid);
      const ts = t.updatedAt;
      if (!prev || ts > prev) m.set(cid, ts);
    }
    return m;
  }

  async getOrderHistoryCutoffForCar(clientUserId: string, carId: string): Promise<Date | null> {
    const cid = String(carId || '').trim();
    if (!cid) return null;
    const m = await this.getCarOrderHistoryCutoffMap(clientUserId);
    return m.get(cid) ?? null;
  }

  private optBool(v: unknown, defaultTrue: boolean): boolean {
    if (v === undefined || v === null) return defaultTrue;
    if (v === false || v === 'false' || v === 0 || v === '0') return false;
    if (v === true || v === 'true' || v === 1 || v === '1') return true;
    return defaultTrue;
  }

  private isShareOrderHistoryFalse(opts: Record<string, unknown> | null | undefined): boolean {
    if (!opts || typeof opts !== 'object') return false;
    return this.optBool(opts['share_order_history'], true) === false;
  }

  private async applyTransferSideEffects(
    fromUserId: string,
    toUserId: string,
    carId: string,
    options: Record<string, unknown> | null,
  ): Promise<void> {
    const shareChats = this.optBool(options?.['share_chat_history'], true);
    const shareNotes = this.optBool(options?.['share_notes'], true);
    const shareMaintenance = this.optBool(options?.['share_maintenance'], true);
    if (shareChats) {
      await this.reassignChatsForCarTransfer(fromUserId, toUserId, carId);
    }
    if (shareNotes) {
      await this.mergeProfileNotesForCarTransfer(fromUserId, toUserId, carId);
    }
    if (shareMaintenance) {
      await this.mergeMaintenanceStateForCarTransfer(fromUserId, toUserId, carId);
    }
    await this.stripMaintenanceStateForFormerOwner(fromUserId, carId);
  }

  private async reassignChatsForCarTransfer(fromUserId: string, toUserId: string, carId: string): Promise<void> {
    const fromUser = await this.usersService.findById(fromUserId);
    const toUser = await this.usersService.findById(toUserId);
    if (!fromUser?.phone || !toUser?.phone) return;
    const fromNorm = this.normalizePhoneForCompare(fromUser.phone);
    const toNorm = this.normalizePhoneForCompare(toUser.phone);
    if (fromNorm.length < 10 || toNorm.length < 10 || fromNorm === toNorm) return;

    const ordersForCar = await this.orderRepo.find({
      where: { carId },
      select: ['id', 'clientPhone'],
    });
    const orderIds = ordersForCar
      .filter((o) => this.normalizePhoneForCompare((o as any).clientPhone || '') === fromNorm)
      .map((o) => o.id);
    if (orderIds.length === 0) return;

    const chats = await this.chatRepo.find({
      where: { lastOrderId: In(orderIds) },
    });
    const toDigits = toNorm.replace(/\D/g, '');
    const fromDigits = fromNorm.replace(/\D/g, '');

    for (const chat of chats) {
      const cp = String((chat as any).clientPhone || '').replace(/\D/g, '');
      if (cp && cp !== fromDigits) continue;
      const orgId = (chat as any).organizationId as string | null | undefined;
      if (orgId) {
        const conflict = await this.chatRepo.findOne({
          where: { organizationId: orgId, clientPhone: toDigits },
        });
        if (conflict && conflict.id !== chat.id) continue;
      }
      (chat as any).clientPhone = toDigits;
      await this.chatRepo.save(chat);
    }
  }

  private parseProfileNotesPayload(raw: unknown): Array<Record<string, unknown>> {
    if (raw == null) return [];
    let arr: unknown = raw;
    if (typeof raw === 'string') {
      try {
        arr = JSON.parse(raw);
      } catch {
        return [];
      }
    }
    if (!Array.isArray(arr)) return [];
    return arr.filter((x) => x && typeof x === 'object') as Array<Record<string, unknown>>;
  }

  private async mergeProfileNotesForCarTransfer(fromUserId: string, toUserId: string, carId: string): Promise<void> {
    const fromState = await this.usersService.getClientAppState(fromUserId);
    const toState = await this.usersService.getClientAppState(toUserId);
    const fromPayload = (fromState.payload ?? {}) as Record<string, unknown>;
    const toPayload = toState.payload ? { ...toState.payload } : {};
    const fromNotes = this.parseProfileNotesPayload(fromPayload[PROFILE_NOTES_SERVER_KEY]).filter((n) => {
      const cid = String(n['carId'] ?? n['car_id'] ?? '').trim();
      return cid === carId;
    });
    if (fromNotes.length === 0) return;

    const toNotes = this.parseProfileNotesPayload(toPayload[PROFILE_NOTES_SERVER_KEY]);
    const usedIds = new Set(toNotes.map((n) => String(n['id'] ?? '')));
    for (const n of fromNotes) {
      let id = String(n['id'] ?? '');
      if (!id || usedIds.has(id)) {
        id = randomUUID();
      }
      usedIds.add(id);
      toNotes.push({
        ...n,
        id,
        carId,
        car_id: carId,
      });
    }
    toPayload[PROFILE_NOTES_SERVER_KEY] = JSON.stringify(toNotes);
    await this.usersService.putClientAppState(toUserId, toPayload);
  }

  private parseClientAppJsonArray(raw: unknown): unknown[] {
    if (raw == null) return [];
    if (Array.isArray(raw)) return raw;
    if (typeof raw === 'string') {
      try {
        const v = JSON.parse(raw) as unknown;
        return Array.isArray(v) ? v : [];
      } catch {
        return [];
      }
    }
    return [];
  }

  /**
   * Копирует настройки и историю ТО по этому авто из снимка бывшего владельца в снимок нового (тот же car_id в БД).
   */
  private async mergeMaintenanceStateForCarTransfer(
    fromUserId: string,
    toUserId: string,
    carId: string,
  ): Promise<void> {
    const fromState = await this.usersService.getClientAppState(fromUserId);
    const toState = await this.usersService.getClientAppState(toUserId);
    const fromPayload = (fromState.payload ?? {}) as Record<string, unknown>;
    const toPayload: Record<string, unknown> = toState.payload ? { ...toState.payload } : {};

    const fromConfigs = this.parseClientAppJsonArray(fromPayload[MAINTENANCE_CONFIGS_JSON_KEY]) as Array<
      Record<string, unknown>
    >;
    const cfgForCar = fromConfigs.filter((c) => String(c['carId'] ?? '').trim() === carId);
    if (cfgForCar.length > 0) {
      const toConfigs = this.parseClientAppJsonArray(toPayload[MAINTENANCE_CONFIGS_JSON_KEY]) as Array<
        Record<string, unknown>
      >;
      const rest = toConfigs.filter((c) => String(c['carId'] ?? '').trim() !== carId);
      toPayload[MAINTENANCE_CONFIGS_JSON_KEY] = JSON.stringify([...rest, ...cfgForCar]);
    }

    const fromRecords = this.parseClientAppJsonArray(fromPayload[MAINTENANCE_RECORDS_JSON_KEY]) as Array<
      Record<string, unknown>
    >;
    const recForCar = fromRecords.filter((r) => String(r['carId'] ?? '').trim() === carId);
    if (recForCar.length > 0) {
      const toRecords = this.parseClientAppJsonArray(toPayload[MAINTENANCE_RECORDS_JSON_KEY]) as Array<
        Record<string, unknown>
      >;
      const seen = new Set(toRecords.map((r) => String(r['id'] ?? '')));
      const merged = [...toRecords];
      for (const r of recForCar) {
        const id = String(r['id'] ?? '');
        if (!id || seen.has(id)) continue;
        seen.add(id);
        merged.push(r);
      }
      toPayload[MAINTENANCE_RECORDS_JSON_KEY] = JSON.stringify(merged);
    }

    const ordersForCar = await this.orderRepo.find({
      where: { carId },
      select: ['id'],
    });
    const orderIdsForCar = new Set(ordersForCar.map((o) => o.id));
    const fromSyncRaw = this.parseClientAppJsonArray(fromPayload[MAINTENANCE_SYNCED_ORDER_IDS_JSON_KEY]);
    const fromSyncForCar = fromSyncRaw.map(String).filter((id) => orderIdsForCar.has(id));
    if (fromSyncForCar.length > 0) {
      const toSyncRaw = this.parseClientAppJsonArray(toPayload[MAINTENANCE_SYNCED_ORDER_IDS_JSON_KEY]);
      const toSet = new Set(toSyncRaw.map(String));
      for (const id of fromSyncForCar) {
        toSet.add(id);
      }
      toPayload[MAINTENANCE_SYNCED_ORDER_IDS_JSON_KEY] = JSON.stringify([...toSet]);
    }

    if (cfgForCar.length > 0 || recForCar.length > 0 || fromSyncForCar.length > 0) {
      await this.usersService.putClientAppState(toUserId, toPayload);
    }
  }

  /** У бывшего владельца убираем ТО по переданному авто из client_app_state (интервалы, записи, учёт заказов). */
  private async stripMaintenanceStateForFormerOwner(fromUserId: string, carId: string): Promise<void> {
    const fromState = await this.usersService.getClientAppState(fromUserId);
    const fromPayload: Record<string, unknown> = fromState.payload ? { ...fromState.payload } : {};

    const ordersForCar = await this.orderRepo.find({
      where: { carId },
      select: ['id'],
    });
    const orderIdsForCar = new Set(ordersForCar.map((o) => o.id));

    const configs = this.parseClientAppJsonArray(fromPayload[MAINTENANCE_CONFIGS_JSON_KEY]) as Array<
      Record<string, unknown>
    >;
    const nextConfigs = configs.filter((c) => String(c['carId'] ?? '').trim() !== carId);
    if (nextConfigs.length !== configs.length) {
      fromPayload[MAINTENANCE_CONFIGS_JSON_KEY] = JSON.stringify(nextConfigs);
    }

    const records = this.parseClientAppJsonArray(fromPayload[MAINTENANCE_RECORDS_JSON_KEY]) as Array<
      Record<string, unknown>
    >;
    const nextRecords = records.filter((r) => String(r['carId'] ?? '').trim() !== carId);
    if (nextRecords.length !== records.length) {
      fromPayload[MAINTENANCE_RECORDS_JSON_KEY] = JSON.stringify(nextRecords);
    }

    const syncedRaw = this.parseClientAppJsonArray(fromPayload[MAINTENANCE_SYNCED_ORDER_IDS_JSON_KEY]);
    const nextSynced = syncedRaw.map(String).filter((oid) => !orderIdsForCar.has(oid));
    if (nextSynced.length !== syncedRaw.length) {
      fromPayload[MAINTENANCE_SYNCED_ORDER_IDS_JSON_KEY] = JSON.stringify(nextSynced);
    }

    if (
      nextConfigs.length !== configs.length ||
      nextRecords.length !== records.length ||
      nextSynced.length !== syncedRaw.length
    ) {
      await this.usersService.putClientAppState(fromUserId, fromPayload);
    }
  }

  /**
   * Подсказка для Business/СТО: по car_id из заказа — была ли передача владельца в приложении клиента.
   */
  async getStaffCarTransferInsight(carId: string): Promise<{
    show_notice: boolean;
    message: string;
    last_event_at: string | null;
  }> {
    const cid = String(carId || '').trim();
    if (!cid || cid === 'unknown') {
      return { show_notice: false, message: '', last_event_at: null };
    }
    const [transferCount, formerCount] = await Promise.all([
      this.transferRepo.count({ where: { carId: cid } }),
      this.formerRepo.count({ where: { carId: cid } }),
    ]);
    if (transferCount === 0 && formerCount === 0) {
      return { show_notice: false, message: '', last_event_at: null };
    }
    const latest = await this.transferRepo.findOne({
      where: { carId: cid },
      order: { updatedAt: 'DESC' },
    });
    const lastAt = latest?.updatedAt?.toISOString?.() ?? null;
    return {
      show_notice: true,
      message:
        'Этот автомобиль мог быть передан другому владельцу через приложение MP-Servis (клиент). ' +
        'В старых заказах сохраняются телефон и данные на момент записи — они могут не совпадать с текущим владельцем в гараже клиента.',
      last_event_at: lastAt,
    };
  }
}
