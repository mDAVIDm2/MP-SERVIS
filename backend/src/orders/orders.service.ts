import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { QueryFailedError } from 'typeorm';
import * as fs from 'fs';
import * as path from 'path';
import { Order } from './order.entity';
import { OrderItem } from './order-item.entity';
import { OrderPhoto } from './order-photo.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { ChatsService } from '../chats/chats.service';
import { Chat } from '../chats/chat.entity';
import { ChatMessage } from '../chats/chat-message.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { SubscriptionQuotaService } from '../subscriptions/subscription-quota.service';
import { MediaService } from '../media/media.service';
import { normalizeOrganizationBusinessKind } from '../organizations/organization-business-kind';
import { normalizeSchedulingMode } from '../organizations/organization-scheduling';
import { bayNameMapFromSlots, effectiveBayCountFromSlots, normalizeOrgBays } from '../organizations/bay-settings.util';
import { UsersService } from '../users/users.service';
import { UserClientHiddenCar } from '../users/user-client-hidden-car.entity';
import { normalizeOptionalVin } from '../common/vin.util';

const UPLOADS_DIR = path.join(process.cwd(), 'uploads', 'order-photos');

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order) private orderRepo: Repository<Order>,
    @InjectRepository(OrderItem) private itemRepo: Repository<OrderItem>,
    @InjectRepository(OrderPhoto) private photoRepo: Repository<OrderPhoto>,
    @InjectRepository(StaffMember) private staffRepo: Repository<StaffMember>,
    @InjectRepository(Chat) private chatRepo: Repository<Chat>,
    @InjectRepository(ChatMessage) private chatMsgRepo: Repository<ChatMessage>,
    private chats: ChatsService,
    private notifications: NotificationsService,
    private orgService: OrganizationsService,
    private subscriptionQuota: SubscriptionQuotaService,
    private readonly mediaService: MediaService,
    private readonly usersService: UsersService,
    @InjectRepository(UserClientHiddenCar) private readonly hiddenCarRepo: Repository<UserClientHiddenCar>,
  ) {}

  /**
   * Id строки прайса организации и/или общего каталога. Не задают цену: фактические суммы и сроки — в полях позиции.
   */
  private parseItemServiceRefs(
    i: Record<string, unknown> | undefined | null,
  ): { organizationServiceId: string | null; catalogItemId: string | null } {
    if (!i || typeof i !== 'object') {
      return { organizationServiceId: null, catalogItemId: null };
    }
    const trim = (v: unknown): string | null => {
      if (v === undefined || v === null) return null;
      const s = String(v).trim();
      return s.length > 0 ? s : null;
    };
    const organizationServiceId =
      trim(i['organization_service_id']) ??
      trim(i['organizationServiceId']) ??
      trim(i['service_id']) ??
      trim(i['serviceId']);
    const catalogItemId = trim(i['catalog_item_id']) ?? trim(i['catalogItemId']);
    return { organizationServiceId, catalogItemId };
  }

  private async loadHiddenCarIdsForClientUser(userId: string): Promise<Set<string>> {
    const rows = await this.hiddenCarRepo.find({ where: { userId }, select: ['carId'] });
    return new Set(rows.map((r) => r.carId));
  }

  /** Скрытое у клиента авто: не показывать в гараже и в списке/карточке заказов. */
  async isCarHiddenForClient(userId: string, carId: string | null | undefined): Promise<boolean> {
    if (!carId || String(carId).trim() === '') return false;
    const row = await this.hiddenCarRepo.findOne({
      where: { userId, carId: String(carId).trim() },
    });
    return !!row;
  }

  /** Аватары клиентских аккаунтов по ключу телефона (для списка/карточки заказа без запроса чатов). */
  private async buildClientAvatarMapForOrders(orders: Order[]): Promise<Map<string, string | null>> {
    const keys = new Set<string>();
    for (const o of orders) {
      const pk = this.usersService.clientPhoneMatchKey(String((o as any).clientPhone || ''));
      if (pk) keys.add(pk);
    }
    return this.usersService.mapClientAvatarUrlsByPhoneKeys(keys);
  }

  private async assertOrderMediaAttachmentLimit(orderId: string, organizationId: string): Promise<void> {
    const limits = await this.subscriptionQuota.getLimitsForOrganization(organizationId);
    const max = limits.maxOrderMediaAttachments;
    if (max == null) return;
    const [modern, legacy] = await Promise.all([
      this.mediaService.countOrderMediaLinks(orderId),
      this.photoRepo.count({ where: { orderId } }),
    ]);
    if (modern + legacy >= max) {
      throw new BadRequestException(
        `Достигнут лимит вложений к заказу по тарифу (${max}). Удалите файлы или смените тариф.`,
      );
    }
  }

  /**
   * Первый выход заказа из pending_confirmation в confirmed или in_progress расходует месячный лимит тарифа
   * и фиксирует first_confirmed_at (один раз на заказ).
   */
  private async mergeFirstBillingConfirmation(
    order: Order,
    previousStatus: string,
    updates: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const nextStatus =
      updates.status !== undefined ? String(updates.status) : previousStatus;
    if ((order as any).firstConfirmedAt) {
      return updates;
    }
    const leavesPendingConfirmation =
      previousStatus === 'pending_confirmation' &&
      (nextStatus === 'confirmed' || nextStatus === 'in_progress');
    if (!leavesPendingConfirmation) {
      return updates;
    }
    await this.subscriptionQuota.assertCanConsumeConfirmedOrderSlot((order as any).organizationId);
    return { ...updates, firstConfirmedAt: new Date() };
  }

  async findAll(organizationId: string) {
    const orders = await this.orderRepo.find({
      where: { organizationId },
      relations: ['items', 'master', 'organization'],
      order: { dateTime: 'DESC' },
    });
    const bayCache = new Map<string, Map<string, string>>();
    const avatarMap = await this.buildClientAvatarMapForOrders(orders);
    const items = await Promise.all(orders.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache, avatarMap)));
    return { items };
  }

  /** Все заказы для Control Center (с пагинацией). */
  async findAllForInternal(limit = 200, offset = 0) {
    const [orders, total] = await this.orderRepo.findAndCount({
      relations: ['items', 'master', 'organization'],
      order: { dateTime: 'DESC' },
      take: limit,
      skip: offset,
    });
    const bayCache = new Map<string, Map<string, string>>();
    const avatarMap = await this.buildClientAvatarMapForOrders(orders);
    const items = await Promise.all(orders.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache, avatarMap)));
    return { items, total };
  }

  /** Заказы клиента по номеру телефона (для Client-приложения). Учитывает 8/7 для РФ. */
  async findForClient(clientPhoneNorm: string) {
    const norm = this.normalizePhoneForCompare(clientPhoneNorm);
    const userId = await this.usersService.findIdByNormalizedPhone(norm, 'client');
    const hidden = userId ? await this.loadHiddenCarIdsForClientUser(userId) : new Set<string>();
    const digitsExpr = "REGEXP_REPLACE(COALESCE(order.client_phone, ''), '\\D', '', 'g')";
    const normalizedExpr = `CASE WHEN LENGTH(${digitsExpr}) = 11 AND LEFT(${digitsExpr}, 1) = '8' THEN '7' || SUBSTRING(${digitsExpr} FROM 2) ELSE ${digitsExpr} END`;
    const orders = await this.orderRepo
      .createQueryBuilder('order')
      .leftJoinAndSelect('order.items', 'items')
      .leftJoinAndSelect('order.master', 'master')
      .leftJoinAndSelect('order.organization', 'organization')
      .where(`${normalizedExpr} = :phone`, { phone: norm })
      .orderBy('order.date_time', 'DESC')
      .getMany();
    const visible =
      hidden.size === 0
        ? orders
        : orders.filter((o) => {
            const cid = (o as any).carId;
            if (cid == null || String(cid).trim() === '') return true;
            return !hidden.has(String(cid).trim());
          });
    const bayCache = new Map<string, Map<string, string>>();
    const avatarMap = await this.buildClientAvatarMapForOrders(visible);
    const items = await Promise.all(visible.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache, avatarMap)));
    return { items };
  }

  /**
   * Детали заказа. Поле items — фактические позиции в БД (для правок СТО).
   * При pending_approval дополнительно approval_preview — предлагаемый состав из последнего запроса согласования (только отображение).
   */
  async findOne(id: string, filterHiddenForClientUserId?: string | null) {
    const o = await this.orderRepo.findOne({ where: { id }, relations: ['items', 'master', 'organization'] });
    if (!o) return null;
    if (
      filterHiddenForClientUserId &&
      (await this.isCarHiddenForClient(filterHiddenForClientUserId, (o as any).carId))
    ) {
      return null;
    }
    const avatarMap = await this.buildClientAvatarMapForOrders([o]);
    return this.toOrderJsonWithApprovalPreview(o, new Map<string, Map<string, string>>(), avatarMap);
  }

  /**
   * Единая точка создания заказа «из чата» (запрос согласования без существующего заказа).
   * Создаёт заказ без позиций; approval_items хранятся только в ChatMessage.
   * ChatsService вызывает этот метод и привязывает полученный orderId к чату и сообщению.
   */
  async createFromChat(
    organizationId: string,
    clientPhone: string,
    approvalItems: any[],
    proposedDateTime?: Date,
  ): Promise<string> {
    const norm = this.normalizePhoneForCompare(clientPhone);
    const recentOrders = await this.orderRepo.find({
      where: { organizationId },
      order: { updatedAt: 'DESC' },
      take: 50,
    });
    const lastOrder = recentOrders.find((o) => this.normalizePhoneForCompare((o as any).clientPhone || '') === norm) ?? null;
    const orderNumber = await this.nextOrderNumber(organizationId);
    const dateTime = proposedDateTime ?? new Date();
    const totalMin = approvalItems.reduce((s: number, i: any) => s + (Number(i.estimated_minutes) ?? Number(i.estimatedMinutes) ?? 60), 0);
    const plannedEndTime = new Date(dateTime.getTime() + totalMin * 60 * 1000);

    const order = this.orderRepo.create({
      organizationId,
      orderNumber,
      carId: (lastOrder as any)?.carId ?? 'unknown',
      carInfo: (lastOrder as any)?.carInfo ?? '',
      vin: (lastOrder as any)?.vin ?? null,
      licensePlate: (lastOrder as any)?.licensePlate ?? null,
      bodyType: (lastOrder as any)?.bodyType ?? null,
      color: (lastOrder as any)?.color ?? null,
      mileage: (lastOrder as any)?.mileage ?? null,
      engineType: (lastOrder as any)?.engineType ?? null,
      clientName: (lastOrder as any)?.clientName ?? null,
      clientPhone,
      carPhotoUrl: (lastOrder as any)?.carPhotoUrl ?? null,
      status: 'pending_confirmation',
      previousStatus: null,
      dateTime,
      plannedStartTime: dateTime,
      plannedEndTime,
      comment: null,
      masterId: null,
    });

    const maxSaveRetries = 5;
    for (let attempt = 0; attempt < maxSaveRetries; attempt++) {
      try {
        await this.orderRepo.save(order);
        return order.id;
      } catch (e: unknown) {
        const isUniqueError = e instanceof QueryFailedError && (e as any).code === '23505';
        if (isUniqueError && attempt < maxSaveRetries - 1) {
          order.orderNumber = await this.nextOrderNumber(organizationId);
          continue;
        }
        throw e;
      }
    }
    return order.id;
  }

  /** Генерирует уникальный номер заказа; при гонке (unique violation) повторяет с новым count. */
  private async nextOrderNumber(organizationId: string, maxRetries = 5): Promise<string> {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      const num = await this.orderRepo.count({ where: { organizationId } });
      const orderNumber = '#2024-' + String(num + 1).padStart(3, '0');
      const exists = await this.orderRepo.findOne({ where: { orderNumber }, select: ['id'] });
      if (!exists) return orderNumber;
    }
    return '#2024-' + String(Date.now()).slice(-6);
  }

  /** URL фото авто из клиентского приложения (https или относительный путь к API). */
  private sanitizeCarPhotoUrl(raw: unknown): string | null {
    const s = raw == null ? '' : String(raw).trim();
    if (!s || s.length > 1024) return null;
    const lower = s.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return s;
    if (s.startsWith('/')) return s;
    return null;
  }

  async create(organizationId: string, dto: any) {
    const dateTime = new Date(dto.date_time);
    const itemDtos = Array.isArray(dto.items) ? dto.items : [];
    const totalMinutes = itemDtos.reduce((sum: number, i: any) => sum + (Number(i.estimated_minutes) ?? Number(i.estimatedMinutes) ?? 60), 0);
    const plannedEndTime = new Date(dateTime.getTime() + totalMinutes * 60 * 1000);

    const baseOverlap = this.orderRepo
      .createQueryBuilder('order')
      .where('order.organization_id = :orgId', { orgId: organizationId })
      .andWhere('order.status NOT IN (:...excluded)', { excluded: ['cancelled', 'done'] })
      .andWhere(
        'COALESCE(order.planned_start_time, order.date_time) < :newEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :newStart',
        { newStart: dateTime.toISOString(), newEnd: plannedEndTime.toISOString() },
      );

    const orgRow = await this.orgService.findOne(organizationId);
    const schedMode = normalizeSchedulingMode((orgRow as any)?.schedulingMode);
    const settings = (await this.orgService.getSettings(organizationId)) as { slots?: Record<string, unknown> };
    const slotsBlock = settings?.slots;
    const bays = normalizeOrgBays(slotsBlock);
    const bayCount = effectiveBayCountFromSlots(slotsBlock);

    let resolvedBayId: string | null =
      dto.bay_id != null && String(dto.bay_id).trim() !== '' ? String(dto.bay_id).trim() : null;

    if (schedMode === 'bay_based') {
      if (bays.length > 0) {
        if (resolvedBayId) {
          if (!bays.some((b) => b.id === resolvedBayId)) {
            throw new BadRequestException('Указан неизвестный пост.');
          }
          const overlappingBay = await baseOverlap.clone().andWhere('order.bay_id = :bid', { bid: resolvedBayId }).getCount();
          if (overlappingBay > 0) {
            throw new BadRequestException('Этот пост занят в выбранное время.');
          }
        } else {
          resolvedBayId = null;
          for (const b of bays) {
            const c = await baseOverlap.clone().andWhere('order.bay_id = :bid', { bid: b.id }).getCount();
            if (c === 0) {
              resolvedBayId = b.id;
              break;
            }
          }
          if (!resolvedBayId) {
            throw new BadRequestException('Все посты заняты в это время. Выберите другое время.');
          }
        }
      } else {
        resolvedBayId = null;
        const overlappingCount = await baseOverlap.getCount();
        if (overlappingCount >= bayCount) {
          throw new BadRequestException('Все посты заняты в это время. Выберите другое время.');
        }
      }
    } else {
      resolvedBayId = null;
    }

    if (dto.master_id) {
      const overlapping = await baseOverlap.clone().andWhere('order.master_id = :masterId', { masterId: dto.master_id }).getCount();
      if (overlapping > 0) {
        throw new BadRequestException('Мастер уже занят в это время. Выберите другое время.');
      }
    } else if (schedMode !== 'bay_based') {
      const overlappingCount = await baseOverlap.getCount();
      const solo = await this.subscriptionQuota.isSoloPlan(organizationId);
      if (solo) {
        if (overlappingCount >= 1) {
          throw new BadRequestException('Нет свободных слотов в это время. Выберите другое время.');
        }
      } else {
        const mastersCount = await this.staffRepo.count({
          where: { organizationId, role: 'master', isActive: true },
        });
        if (mastersCount === 0 || overlappingCount >= mastersCount) {
          throw new BadRequestException('Нет свободных мастеров в это время. Выберите другое время.');
        }
      }
    }

    const orderNumber = await this.nextOrderNumber(organizationId);
    const vinNorm = normalizeOptionalVin(dto.vin);
    const order = this.orderRepo.create({
      organizationId,
      orderNumber,
      carId: dto.car_id || 'unknown',
      carInfo: dto.car_info || '',
      vin: vinNorm,
      licensePlate: dto.license_plate ?? null,
      bodyType: dto.body_type ?? null,
      color: dto.color ?? null,
      mileage: dto.mileage != null ? Number(dto.mileage) : null,
      engineType: dto.engine_type ?? null,
      clientName: dto.client_name,
      clientPhone: dto.client_phone,
      carPhotoUrl: this.sanitizeCarPhotoUrl(dto.car_photo_url ?? dto.carPhotoUrl),
      status: 'pending_confirmation',
      dateTime,
      plannedStartTime: dateTime,
      plannedEndTime,
      comment: dto.comment,
      masterId: dto.master_id ?? null,
      bayId: resolvedBayId,
    });

    const maxSaveRetries = 5;
    for (let attempt = 0; attempt < maxSaveRetries; attempt++) {
      try {
        await this.orderRepo.save(order);
        break;
      } catch (e: unknown) {
        const isUniqueError = e instanceof QueryFailedError && (e as any).code === '23505';
        if (isUniqueError && attempt < maxSaveRetries - 1) {
          order.orderNumber = await this.nextOrderNumber(organizationId);
          continue;
        }
        throw e;
      }
    }
    for (const i of itemDtos) {
      const row = i as Record<string, unknown>;
      const refs = this.parseItemServiceRefs(row);
      const item = this.itemRepo.create({
        orderId: order.id,
        name: (row.name as string) ?? '',
        priceKopecks: (row.price_kopecks as number) ?? (row.priceKopecks as number) ?? null,
        estimatedMinutes: Number(row.estimated_minutes ?? row.estimatedMinutes ?? 60) || 60,
        organizationServiceId: refs.organizationServiceId,
        catalogItemId: refs.catalogItemId,
      });
      await this.itemRepo.save(item);
    }
    const chat = await this.chats.createForOrder(order.id);
    await this.chats.addSystemMessage(chat.id, 'Клиент создал заявку. Требуется подтверждение/проверка.', order.id);
    const itemsForCard = itemDtos.map((i: any) => ({
      name: i.name ?? '',
      price_kopecks: i.price_kopecks ?? null,
      estimated_minutes: i.estimated_minutes ?? 60,
    }));
    await this.chats.addOrderCardMessage(chat.id, order.id, itemsForCard, order.dateTime);
    return this.findOne(order.id)!;
  }

  async updateStatus(id: string, status: string) {
    const order = await this.orderRepo.findOne({ where: { id } });
    if (!order) return null;
    const current = (order as any).status;
    if (status === 'in_progress' && current === 'pending_approval') {
      throw new BadRequestException('Нельзя перевести в работу: ожидается подтверждение клиента');
    }
    const updates: Record<string, unknown> = { status: status as any };
    if (status === 'in_progress' && !(order as any).actualStartTime) {
      updates.actualStartTime = new Date();
    }
    if ((status === 'completed' || status === 'done') && !(order as any).actualEndTime) {
      updates.actualEndTime = new Date();
    }
    const merged = await this.mergeFirstBillingConfirmation(order, current, updates);
    await this.orderRepo.update(id, merged);
    await this.notifyClientOrderIfNeeded(order, current, status);
    return this.findOne(id);
  }

  private async notifyClientOrderIfNeeded(order: Order, previousStatus: string, newStatus: string) {
    if (newStatus === previousStatus) return;
    const phone = this.normalizePhoneForCompare((order as any).clientPhone || '');
    if (!phone) return;
    // pending_approval — отдельное уведомление из чата при запросе согласования
    const interesting = new Set([
      'confirmed',
      'pending_confirmation',
      'in_progress',
      'completed',
      'done',
      'cancelled',
    ]);
    if (!interesting.has(newStatus)) return;
    const titles: Record<string, string> = {
      confirmed: 'Заказ подтверждён',
      pending_confirmation: 'Требуется подтверждение записи',
      in_progress: 'Работы по заказу начались',
      completed: 'Заказ выполнен',
      done: 'Заказ выполнен',
      cancelled: 'Заказ отменён',
    };
    const title = titles[newStatus] || 'Обновление заказа';
    const num = (order as any).orderNumber || '';
    await this.notifications.createForClientPhone(phone, {
      carId: (order as any).carId,
      type: 'order',
      title,
      body: num ? `Заказ №${num}` : undefined,
      payload: {
        order_id: order.id,
        target_type: 'order',
        target_id: order.id,
      },
    });
  }

  /** Ручная корректировка планового времени (Администратор). */
  async updateTime(id: string, dto: { planned_start_time?: string; planned_end_time?: string }) {
    const order = await this.orderRepo.findOne({ where: { id } });
    if (!order) return null;
    const updates: Record<string, unknown> = {};
    if (dto.planned_start_time != null) updates.plannedStartTime = new Date(dto.planned_start_time);
    if (dto.planned_end_time != null) updates.plannedEndTime = new Date(dto.planned_end_time);
    if (Object.keys(updates).length === 0) return this.findOne(id);
    await this.orderRepo.update(id, updates);
    return this.findOne(id);
  }

  /** Нормализация номера для сравнения: только цифры; для РФ 11 цифр ведущая 8 заменяется на 7. */
  normalizePhoneForCompare(phone: string): string {
    const digits = String(phone || '').replace(/\D/g, '');
    if (digits.length === 11 && digits.startsWith('8')) return '7' + digits.slice(1);
    return digits;
  }

  /** Push в Business-приложение: сотрудники с user_id, если включены пуши по заказам. */
  private async notifyOrgStaffClientBookingSystemLine(orderId: string, line: string): Promise<void> {
    const order = await this.orderRepo.findOne({ where: { id: orderId } });
    const orgId = (order as any)?.organizationId as string | undefined;
    if (!orgId) return;
    const chat = await this.chats.getChatByOrderId(orderId);
    await this.notifications.notifyOrganizationStaffOrderEvent(orgId, {
      title: 'Клиент и запись',
      body: line,
      payload: {
        order_id: orderId,
        ...(chat?.id ? { chat_id: chat.id } : {}),
        target_type: 'order',
        target_id: orderId,
      },
    });
  }

  /**
   * Имена для системного сообщения после согласования: из payload последнего запроса, а не из устаревшего order.items.
   * Редактирования в object-формате применяются все; new_items фильтруются по approved_item_ids (или «принять всё» = ['0']).
   */
  private buildClientApprovalAppliedDisplayNames(
    edited: any[],
    newItems: any[],
    approvedItemIds: string[],
  ): string[] {
    const acceptAllNew =
      approvedItemIds.length === 1 && String(approvedItemIds[0]) === '0';
    const approvedSet = new Set(approvedItemIds.map((x) => String(x)));
    const approvedSetWithMsg = new Set<string>();
    approvedItemIds.forEach((aid) => {
      const a = String(aid);
      approvedSetWithMsg.add(a);
      if (a.startsWith('msg_')) {
        const idx = a.slice(4);
        if (/^\d+$/.test(idx)) approvedSetWithMsg.add('proposed_' + idx);
      }
    });
    const names: string[] = [];
    for (const e of edited) {
      const nm = String(e?.name ?? '').trim();
      if (nm) names.push(nm);
    }
    for (let index = 0; index < newItems.length; index++) {
      const n = newItems[index];
      const id = n?.id != null ? String(n.id) : `proposed_${index}`;
      const allowed =
        acceptAllNew ||
        approvedSet.has(id) ||
        approvedSetWithMsg.has(id);
      if (!allowed) continue;
      const nm = String(n?.name ?? '').trim();
      if (nm) names.push(nm);
    }
    return names;
  }

  /**
   * Клиент сначала вызывает POST /approval, затем POST /confirm с временем.
   * После первого шага заказ уже confirmed/in_progress — второй запрос только фиксирует время и пересчитывает planned_end.
   */
  private async applyClientTimeConfirmAfterApproval(
    orderId: string,
    newDateTime?: string,
    acceptProposed?: boolean,
    filterHiddenForClientUserId?: string | null,
  ) {
    const updates: Record<string, unknown> = {};
    if (newDateTime) {
      const dt = new Date(newDateTime);
      updates.dateTime = dt;
      const items = await this.itemRepo.find({ where: { orderId } });
      const totalMin = items.reduce((s: number, i) => s + (i.estimatedMinutes || 0), 0);
      updates.plannedStartTime = dt;
      updates.plannedEndTime = new Date(dt.getTime() + totalMin * 60 * 1000);
    }
    if (acceptProposed === false && newDateTime) {
      updates.status = 'pending_confirmation';
    }
    if (Object.keys(updates).length > 0) {
      await this.orderRepo.update(orderId, updates);
    }
    if (newDateTime) {
      const chat = await this.chats.getChatByOrderId(orderId);
      if (chat) {
        const dt = new Date(newDateTime);
        const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
        const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
        const text =
          acceptProposed !== false
            ? `Клиент подтвердил запись на ${dateStr} в ${timeStr}.`
            : `Клиент перенёс время на ${dateStr} в ${timeStr}.`;
        await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
        await this.notifyOrgStaffClientBookingSystemLine(orderId, text);
      }
    }
    return this.findOne(orderId, filterHiddenForClientUserId);
  }

  /**
   * Подтверждение заказа клиентом (перечень работ и/или время).
   * Если заказ в pending_approval, сначала применяем позиции из последнего сообщения («принять всё»), затем обновляем время/статус.
   * - accept_proposed === true или не передан: клиент согласен → статус confirmed.
   * - accept_proposed === false и передан date_time: своё время → обновляем время, статус pending_confirmation.
   */
  async confirmByClient(
    orderId: string,
    clientPhoneNorm: string,
    newDateTime?: string,
    acceptProposed?: boolean,
    approvalMessageId?: string | null,
  ) {
    const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['items'] });
    if (!order) return null;
    const orderPhone = this.normalizePhoneForCompare((order as any).clientPhone);
    const userPhone = this.normalizePhoneForCompare(clientPhoneNorm);
    if (orderPhone !== userPhone) return null;
    const clientUserId = await this.usersService.findIdByNormalizedPhone(userPhone, 'client');
    if (clientUserId && (await this.isCarHiddenForClient(clientUserId, (order as any).carId))) {
      return null;
    }
    const status = (order as any).status;
    if (status === 'confirmed' || status === 'in_progress') {
      return this.applyClientTimeConfirmAfterApproval(orderId, newDateTime, acceptProposed, clientUserId);
    }
    if (status !== 'pending_confirmation' && status !== 'pending_approval') return null;

    // Новый заказ от СТО (без позиций): применяем услуги из последнего approval-сообщения и переводим в confirmed.
    if (status === 'pending_confirmation' && ((order as any).items?.length ?? 0) === 0) {
      const approvalMsg = await this.chats.getLastApprovalMessageForOrder(orderId);
      if (approvalMsg?.approvalItems) {
        let payload: any = approvalMsg.approvalItems;
        if (typeof payload === 'string') {
          try {
            payload = JSON.parse(payload);
          } catch {
            payload = null;
          }
        }
        const newItems = (Array.isArray(payload) ? payload : (payload?.new_items ?? payload?.newItems ?? [])) as any[];
        for (const n of newItems) {
          const nr = n as Record<string, unknown>;
          const refs = this.parseItemServiceRefs(nr);
          const item = this.itemRepo.create({
            orderId,
            order: { id: orderId } as any,
            name: (nr.name as string) ?? '',
            priceKopecks: (nr.price_kopecks as number) ?? (nr.priceKopecks as number) ?? null,
            estimatedMinutes: Number(nr.estimated_minutes ?? nr.estimatedMinutes ?? 60) || 60,
            isCompleted: false,
            isAdditional: false,
            organizationServiceId: refs.organizationServiceId,
            catalogItemId: refs.catalogItemId,
          });
          await this.itemRepo.save(item);
        }
        const updates: Record<string, unknown> = { status: 'confirmed' };
        if (newDateTime) {
          const dt = new Date(newDateTime);
          updates.dateTime = dt;
          updates.plannedStartTime = dt;
          const totalMin = newItems.reduce((s: number, i: any) => s + (Number(i.estimated_minutes) ?? Number(i.estimatedMinutes) ?? 60), 0);
          updates.plannedEndTime = new Date(dt.getTime() + totalMin * 60 * 1000);
        }
        const mergedEmptyItems = await this.mergeFirstBillingConfirmation(order, status, updates);
        await this.orderRepo.update(orderId, mergedEmptyItems);
        const chat = await this.chats.getChatByOrderId(orderId);
        if (chat && newDateTime) {
          const dt = new Date(newDateTime);
          const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
          const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
          const line = `Клиент подтвердил запись на ${dateStr} в ${timeStr}.`;
          await this.chats.sendMessage(chat.id, { text: line, is_system: true }, false);
          await this.notifyOrgStaffClientBookingSystemLine(orderId, line);
        } else if (chat) {
          const line = 'Клиент подтвердил запись.';
          await this.chats.sendMessage(chat.id, { text: line, is_system: true }, false);
          await this.notifyOrgStaffClientBookingSystemLine(orderId, line);
        }
        return this.findOne(orderId, clientUserId);
      }
    }

    if (status === 'pending_approval') {
      try {
        const afterApproval = await this.approveByClient(orderId, clientPhoneNorm, ['0'], [], {
          approvalMessageId,
        });
        if (!afterApproval) return null;
      } catch (e) {
        // Нет сообщения согласования (409) — всё равно применяем время, если клиент выбрал «другое время».
        if (newDateTime && acceptProposed === false) {
          const updates: Record<string, unknown> = {
            dateTime: new Date(newDateTime),
            status: 'pending_confirmation',
          };
          const items = await this.itemRepo.find({ where: { orderId } });
          const totalMin = items.reduce((s: number, i: any) => s + (i.estimatedMinutes || 0), 0);
          updates.plannedStartTime = new Date(newDateTime);
          updates.plannedEndTime = new Date(new Date(newDateTime).getTime() + totalMin * 60 * 1000);
          await this.orderRepo.update(orderId, updates);
          const chat = await this.chats.getChatByOrderId(orderId);
          if (chat) {
            const dt = new Date(newDateTime);
            const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
            const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
            const line = `Клиент перенёс время на ${dateStr} в ${timeStr}.`;
            await this.chats.sendMessage(chat.id, { text: line, is_system: true }, false);
            await this.notifyOrgStaffClientBookingSystemLine(orderId, line);
          }
          await this.chats.markApprovalRequestsResolvedForOrder(orderId, 'superseded');
          return this.findOne(orderId, clientUserId);
        }
        throw e;
      }
    }

    const updates: Record<string, unknown> = {};
    if (newDateTime) {
      const dt = new Date(newDateTime);
      updates.dateTime = dt;
      const items = await this.itemRepo.find({ where: { orderId } });
      const totalMin = items.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
      updates.plannedStartTime = dt;
      updates.plannedEndTime = new Date(dt.getTime() + totalMin * 60 * 1000);
    }
    if (acceptProposed === false && newDateTime) {
      updates.status = 'pending_confirmation';
    } else {
      updates.status = 'confirmed';
    }
    if (Object.keys(updates).length > 0) {
      const mergedPc = await this.mergeFirstBillingConfirmation(order, status, updates);
      await this.orderRepo.update(orderId, mergedPc);
    }
    // Уведомить СТО в чате о подтверждении/переносе времени.
    if (newDateTime) {
      const chat = await this.chats.getChatByOrderId(orderId);
      if (chat) {
        const dt = new Date(newDateTime);
        const dateStr = dt.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
        const timeStr = dt.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
        const text = acceptProposed !== false
          ? `Клиент подтвердил запись на ${dateStr} в ${timeStr}.`
          : `Клиент перенёс время на ${dateStr} в ${timeStr}.`;
        await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
        await this.notifyOrgStaffClientBookingSystemLine(orderId, text);
      }
    }
    return this.findOne(orderId, clientUserId);
  }

  async assignMaster(
    id: string,
    body: { master_id?: string | null; bay_id?: string | null },
  ) {
    const order = await this.orderRepo.findOne({ where: { id }, relations: ['items'] });
    if (!order) throw new NotFoundException('Заказ не найден');

    const patch: Record<string, unknown> = {};
    if ('master_id' in body) patch['masterId'] = body.master_id ?? null;

    if ('bay_id' in body) {
      const v = body.bay_id;
      const newBayId: string | null = v === '' || v === undefined ? null : String(v).trim();
      const orgId = (order as any).organizationId as string;
      const orgRow = await this.orgService.findOne(orgId);
      const schedMode = normalizeSchedulingMode((orgRow as any)?.schedulingMode);
      const settings = (await this.orgService.getSettings(orgId)) as { slots?: Record<string, unknown> };
      const slotsBlock = settings?.slots;
      const bays = normalizeOrgBays(slotsBlock);

      if (schedMode !== 'bay_based') {
        if (newBayId != null) {
          throw new BadRequestException('В режиме записи по мастеру пост не задаётся.');
        }
      } else if (bays.length > 0) {
        if (newBayId != null && !bays.some((b) => b.id === newBayId)) {
          throw new BadRequestException('Указан неизвестный пост.');
        }
      } else if (newBayId != null) {
        throw new BadRequestException('Именованные посты не настроены.');
      }

      if (schedMode === 'bay_based' && newBayId != null && bays.length > 0) {
        const items = order.items ?? [];
        const totalMinutes = items.reduce(
          (s, i) => s + (Number((i as any).estimatedMinutes) || 60),
          0,
        );
        const start = (order as any).plannedStartTime ?? (order as any).dateTime;
        const end =
          (order as any).plannedEndTime ??
          new Date(new Date(start).getTime() + Math.max(1, totalMinutes) * 60 * 1000);
        const baseOverlap = this.orderRepo
          .createQueryBuilder('order')
          .where('order.organization_id = :orgId', { orgId })
          .andWhere('order.id != :oid', { oid: id })
          .andWhere('order.status NOT IN (:...excluded)', { excluded: ['cancelled', 'done'] })
          .andWhere(
            'COALESCE(order.planned_start_time, order.date_time) < :newEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :newStart',
            { newStart: new Date(start).toISOString(), newEnd: end.toISOString() },
          );
        const overlappingBay = await baseOverlap.clone().andWhere('order.bay_id = :bid', { bid: newBayId }).getCount();
        if (overlappingBay > 0) {
          throw new BadRequestException('Этот пост занят в это время.');
        }
      }

      patch['bayId'] = newBayId;
    }

    if (Object.keys(patch).length > 0) {
      await this.orderRepo.update(id, patch as any);
    }
    return this.findOne(id);
  }

  /**
   * Отмена заказа. СТО (organizationId) может отменить любой заказ своей организации;
   * клиент (clientPhone) — только свой заказ по совпадению телефона.
   */
  async cancel(id: string, opts?: { organizationId?: string; clientPhone?: string }) {
    const order = await this.orderRepo.findOne({ where: { id } });
    if (!order) return null;
    let filterHiddenForClientUserId: string | undefined;
    if (opts?.organizationId) {
      if ((order as any).organizationId !== opts.organizationId) return null;
    } else if (opts?.clientPhone) {
      const orderPhone = this.normalizePhoneForCompare((order as any).clientPhone);
      const userPhone = this.normalizePhoneForCompare(opts.clientPhone);
      if (orderPhone !== userPhone) return null;
      const clientUserId = await this.usersService.findIdByNormalizedPhone(userPhone, 'client');
      if (clientUserId && (await this.isCarHiddenForClient(clientUserId, (order as any).carId))) {
        return null;
      }
      filterHiddenForClientUserId = clientUserId ?? undefined;
    }
    await this.orderRepo.update(id, { status: 'cancelled' });
    return this.findOne(id, filterHiddenForClientUserId);
  }

  /**
   * Клиент ответил на запрос согласования доп. работ.
   * - Одобрил: берём approval_items из сообщения (id с карточки или последнее по заказу), создаём/обновляем позиции, статус → confirmed.
   * - Отклонил: откат статуса в previous_status (фолбэк in_progress), в чат — системное сообщение с is_system: true.
   */
  async approveByClient(
    orderId: string,
    clientPhoneNorm: string,
    approvedItemIds: string[],
    _rejectedItemIds: string[],
    opts?: { approvalMessageId?: string | null },
  ) {
    const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['items'] });
    if (!order) return null;
    const orderPhone = this.normalizePhoneForCompare((order as any).clientPhone);
    const userPhone = this.normalizePhoneForCompare(clientPhoneNorm);
    if (orderPhone !== userPhone) return null;
    const clientUserId = await this.usersService.findIdByNormalizedPhone(userPhone, 'client');
    if (clientUserId && (await this.isCarHiddenForClient(clientUserId, (order as any).carId))) {
      return null;
    }
    const status = (order as any).status;
    // Уже согласовано — возвращаем текущий заказ (идемпотентность), чтобы клиент обновил UI и убрал карточку.
    if (status !== 'pending_approval') return this.findOne(orderId, clientUserId);

    if (approvedItemIds.length === 0) {
      const previousStatus = ((order as any).previousStatus as string) ?? 'in_progress';
      await this.orderRepo.update(orderId, { status: previousStatus as any, previousStatus: null });
      const chat = await this.chats.getChatByOrderId(orderId);
      if (chat) {
        await this.chats.sendMessage(chat.id, { text: 'Клиент отказался от дополнительных работ.', is_system: true }, false);
      }
      await this.chats.markApprovalRequestsResolvedForOrder(orderId, 'rejected');
      return this.findOne(orderId, clientUserId);
    }

    const approvalMsg = await this.chats.resolveApprovalMessageForOrder(orderId, opts?.approvalMessageId);
    if (!approvalMsg) {
      if (process.env.NODE_ENV === 'development') {
        console.log('[approveByClient] orderId=%s approvalMsg=null (id=%s) → 409', orderId, opts?.approvalMessageId ?? 'last');
      }
      const hint =
        opts?.approvalMessageId != null && String(opts.approvalMessageId).trim() !== ''
          ? 'Сообщение согласования устарело. Обновите чат и подтвердите снова.'
          : 'Для этого заказа нет активного запроса согласования от сервиса.';
      throw new ConflictException(hint);
    }
    const rawPayload = approvalMsg.approvalItems;
    let payload: unknown = rawPayload;
    if (typeof rawPayload === 'string') {
      try {
        payload = JSON.parse(rawPayload);
      } catch {
        payload = null;
      }
    }
    // Нормализуем ключи: поддержка и snake_case, и camelCase из БД/клиента
    if (payload != null && typeof payload === 'object' && !Array.isArray(payload)) {
      const o = payload as Record<string, unknown>;
      if (o.editedItems != null && o.edited_items == null) o.edited_items = o.editedItems;
      if (o.newItems != null && o.new_items == null) o.new_items = o.newItems;
    }
    const payloadType = Array.isArray(payload) ? 'array' : typeof payload;
    const payloadKeys = payload != null && typeof payload === 'object' && !Array.isArray(payload)
      ? Object.keys(payload as object).join(',')
      : '';
    const editedCount = (payload != null && typeof payload === 'object' && !Array.isArray(payload))
      ? ((payload as any).edited_items ?? []).length
      : 0;
    const newCount = (payload != null && typeof payload === 'object' && !Array.isArray(payload))
      ? ((payload as any).new_items ?? []).length
      : 0;
    if (process.env.NODE_ENV === 'development') {
      console.log('[approveByClient] orderId=%s lastApprovalId=%s lastApprovalChatId=%s payloadType=%s keys=%s edited=%d new=%d approved_item_ids=%s', orderId, approvalMsg.id, approvalMsg.chatId, payloadType, payloadKeys, editedCount, newCount, JSON.stringify(approvedItemIds));
    }

    const isObjectFormat = payload != null && typeof payload === 'object' && !Array.isArray(payload);
    if (isObjectFormat) {
      const payloadObj = payload as { edited_items?: any[]; new_items?: any[] };
      const edited = payloadObj?.edited_items ?? [];
      const newItems = payloadObj?.new_items ?? [];
      const acceptAllNew = approvedItemIds.length === 1 && String(approvedItemIds[0]) === '0';
      const approvedSet = new Set(approvedItemIds);
      const approvedSetWithMsg = new Set<string>();
      approvedItemIds.forEach((aid) => {
        approvedSetWithMsg.add(aid);
        if (typeof aid === 'string' && aid.startsWith('msg_')) {
          const idx = aid.slice(4);
          if (/^\d+$/.test(idx)) approvedSetWithMsg.add('proposed_' + idx);
        }
      });

      console.log('[approveByClient] objectFormat edited=', edited.length, 'newItems=', newItems.length, 'acceptAllNew=', acceptAllNew, 'approvedSet=', [...approvedSet], 'approvedSetWithMsg=', [...approvedSetWithMsg]);

      for (const e of edited) {
        const id = e.id;
        if (!id) continue;
        console.log('[approveByClient] UPDATE item', id);
        await this.itemRepo.update(
          { id, orderId },
          {
            priceKopecks: e.price_kopecks ?? e.priceKopecks ?? null,
            estimatedMinutes: e.estimated_minutes ?? e.estimatedMinutes ?? 60,
          },
        );
      }
      let inserted = 0;
      for (let index = 0; index < newItems.length; index++) {
        const n = newItems[index];
        const id = n.id ?? `proposed_${index}`;
        const allowed = acceptAllNew || approvedSet.has(id) || approvedSetWithMsg.has(id);
        if (!allowed) {
          console.log('[approveByClient] SKIP new_items[' + index + '] id=', id, 'not in approved set');
          continue;
        }
        console.log('[approveByClient] INSERT new_items[' + index + ']', n.name);
        const nr = n as Record<string, unknown>;
        const refs = this.parseItemServiceRefs(nr);
        const entity = this.itemRepo.create({
          orderId,
          order: { id: orderId } as any,
          name: (nr.name as string) ?? '',
          priceKopecks: (nr.price_kopecks as number) ?? (nr.priceKopecks as number) ?? null,
          estimatedMinutes: Number(nr.estimated_minutes ?? nr.estimatedMinutes ?? 60) || 60,
          isCompleted: false,
          isAdditional: true,
          organizationServiceId: refs.organizationServiceId,
          catalogItemId: refs.catalogItemId,
        });
        await this.itemRepo.save(entity);
        inserted++;
      }
      console.log('[approveByClient] INSERT count=', inserted);
      const previousStatus = ((order as any).previousStatus as string) ?? 'confirmed';
      const nextStatus = previousStatus === 'in_progress' ? 'in_progress' : 'confirmed';
      await this.orderRepo.update(orderId, { status: nextStatus as any, previousStatus: null });
      const chat = await this.chats.getChatByOrderId(orderId);
      if (chat) {
        const names = this.buildClientApprovalAppliedDisplayNames(edited, newItems, approvedItemIds);
        const namesText =
          names.length > 3 ? names.slice(0, 3).join(', ') + ` и ещё ${names.length - 3}` : names.join(', ');
        const text = namesText
          ? `Изменения применены: ${names.map((n: string) => '+' + n).join(', ')}`
          : 'Изменения применены: клиент подтвердил доп.работы.';
        await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
      }
      await this.chats.markApprovalRequestsResolvedForOrder(orderId, 'accepted');
      return this.findOne(orderId, clientUserId);
    }

    const approvalItems = Array.isArray(payload) ? payload : [];
    const approvedSet = new Set(approvedItemIds);
    const currentItems = ((order as any).items || []).map((i: any) => ({
      name: i.name,
      price_kopecks: i.priceKopecks,
      estimated_minutes: i.estimatedMinutes ?? 60,
      is_completed: i.isCompleted ?? false,
      is_additional: i.isAdditional ?? false,
    }));
    const itemsWithId = approvalItems.map((i: any, index: number) => ({
      id: (i as any).id ?? `proposed_${index}`,
      name: i.name ?? '',
      price_kopecks: i.price_kopecks ?? i.priceKopecks ?? null,
      estimated_minutes: i.estimated_minutes ?? i.estimatedMinutes ?? 60,
      is_completed: false,
      is_additional: true,
    }));
    const addAllLegacy = approvedItemIds.length === 1 && approvedItemIds[0] === '0' && itemsWithId.length > 1;
    const newItemsFromMessage = addAllLegacy
      ? itemsWithId
      : itemsWithId.filter((item: { id: string }) => approvedSet.has(item.id));
    await this.updateItems(orderId, [...currentItems, ...newItemsFromMessage]);
    const previousStatus = ((order as any).previousStatus as string) ?? 'confirmed';
    const nextStatus = previousStatus === 'in_progress' ? 'in_progress' : 'confirmed';
    await this.orderRepo.update(orderId, { status: nextStatus as any, previousStatus: null });
    const chat = await this.chats.getChatByOrderId(orderId);
    if (chat) {
      const approvedSource = addAllLegacy
        ? itemsWithId
        : itemsWithId.filter((item: { id: string }) => approvedSet.has(item.id));
      const approvedNames = approvedSource
        .map((item: any) => item.name ?? '')
        .filter(Boolean);
      const namesText = approvedNames.length > 3
        ? approvedNames.slice(0, 3).join(', ') + ` и ещё ${approvedNames.length - 3}`
        : approvedNames.join(', ');
      const text = namesText ? `Изменения применены: ${approvedNames.map((n: string) => '+' + n).join(', ')}` : 'Изменения применены: клиент подтвердил доп.работы.';
      await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
    }
    await this.chats.markApprovalRequestsResolvedForOrder(orderId, 'accepted');
    return this.findOne(orderId, clientUserId);
  }

  /**
   * СТО подтверждает согласование за клиента («по телефону»). Применяет черновик как «принять всё», восстанавливает previous_status.
   */
  async approveBySto(orderId: string, organizationId: string) {
    const order = await this.orderRepo.findOne({ where: { id: orderId }, relations: ['items'] });
    if (!order) return null;
    if ((order as any).organizationId !== organizationId) return null;
    const status = (order as any).status;
    if (status !== 'pending_approval') return null;

    const approvalMsg = await this.chats.getLastApprovalMessageForOrder(orderId);
    const rawPayload = approvalMsg?.approvalItems;
    let payload: unknown = rawPayload;
    if (typeof rawPayload === 'string') {
      try {
        payload = JSON.parse(rawPayload);
      } catch {
        payload = null;
      }
    }

    const isObjectFormat = payload != null && typeof payload === 'object' && !Array.isArray(payload);
    if (isObjectFormat) {
      const payloadObj = payload as { edited_items?: any[]; new_items?: any[] };
      const edited = payloadObj?.edited_items ?? [];
      const newItems = payloadObj?.new_items ?? [];

      for (const e of edited) {
        const id = e.id;
        if (!id) continue;
        await this.itemRepo.update(
          { id, orderId },
          {
            priceKopecks: e.price_kopecks ?? e.priceKopecks ?? null,
            estimatedMinutes: e.estimated_minutes ?? e.estimatedMinutes ?? 60,
          },
        );
      }
      for (let index = 0; index < newItems.length; index++) {
        const n = newItems[index];
        const nr = n as Record<string, unknown>;
        const refs = this.parseItemServiceRefs(nr);
        const entity = this.itemRepo.create({
          orderId,
          order: { id: orderId } as any,
          name: (nr.name as string) ?? '',
          priceKopecks: (nr.price_kopecks as number) ?? (nr.priceKopecks as number) ?? null,
          estimatedMinutes: Number(nr.estimated_minutes ?? nr.estimatedMinutes ?? 60) || 60,
          isCompleted: false,
          isAdditional: true,
          organizationServiceId: refs.organizationServiceId,
          catalogItemId: refs.catalogItemId,
        });
        await this.itemRepo.save(entity);
      }
    } else {
      const approvalItems = Array.isArray(payload) ? payload : [];
      const currentItems = ((order as any).items || []).map((i: any) => ({
        name: i.name,
        price_kopecks: i.priceKopecks,
        estimated_minutes: i.estimatedMinutes ?? 60,
        is_completed: i.isCompleted ?? false,
        is_additional: i.isAdditional ?? false,
      }));
      const itemsWithId = approvalItems.map((i: any, index: number) => ({
        id: (i as any).id ?? `proposed_${index}`,
        name: i.name ?? '',
        price_kopecks: i.price_kopecks ?? i.priceKopecks ?? null,
        estimated_minutes: i.estimated_minutes ?? i.estimatedMinutes ?? 60,
        is_completed: false,
        is_additional: true,
      }));
      await this.updateItems(orderId, [...currentItems, ...itemsWithId]);
    }

    const previousStatus = ((order as any).previousStatus as string) ?? 'confirmed';
    const nextStatus = previousStatus === 'in_progress' ? 'in_progress' : 'confirmed';

    const itemsAfter = await this.itemRepo.find({ where: { orderId } });
    const totalMinutes = itemsAfter.reduce((s, i) => s + (i.estimatedMinutes || 0), 0);
    const plannedStart = (order as any).plannedStartTime ?? (order as any).dateTime ?? new Date();
    const plannedEndTime = new Date(new Date(plannedStart).getTime() + totalMinutes * 60 * 1000);
    await this.orderRepo.update(orderId, {
      status: nextStatus as any,
      previousStatus: null,
      plannedEndTime,
    });

    const chat = await this.chats.getChatByOrderId(orderId);
    if (chat) {
      const payloadObj = payload != null && typeof payload === 'object' && !Array.isArray(payload)
        ? (payload as { new_items?: any[] })
        : null;
      const addedNames = (payloadObj?.new_items ?? []).map((n: any) => n?.name ?? '').filter(Boolean);
      const namesText = addedNames.length > 3
        ? addedNames.slice(0, 3).join(', ') + ` и ещё ${addedNames.length - 3}`
        : addedNames.join(', ');
      const text = namesText
        ? `Изменения применены: сервис подтвердил по телефону: ${addedNames.map((n: string) => '+' + n).join(', ')}`
        : 'Изменения применены: сервис подтвердил по телефону.';
      await this.chats.sendMessage(chat.id, { text, is_system: true }, false);
    }
    await this.chats.markApprovalRequestsResolvedForOrder(orderId, 'accepted');
    return this.findOne(orderId);
  }

  /**
   * Обновление позиций заказа. Если вызывается СТО (organizationId) и заказ в статусе,
   * требующем согласования клиента (не done/cancelled), прямое сохранение блокируется:
   * формируется черновик { edited_items, new_items }, отправляется в чат, статус → pending_approval.
   */
  async updateItems(id: string, items: any[], organizationId?: string) {
    const order = await this.orderRepo.findOne({ where: { id }, relations: ['items'] });
    if (!order) return null;
    const status = (order as any).status as string;
    const currentItems = ((order as any).items || []) as Array<{ id: string; name: string; priceKopecks?: number | null; estimatedMinutes?: number }>;
    const currentIds = new Set(currentItems.map((i) => i.id));

    const requiresApproval = status !== 'done' && status !== 'cancelled';
    if (organizationId && requiresApproval) {
      const edited: any[] = [];
      const newItems: any[] = [];
      for (const i of items || []) {
        const incId = i.id != null ? String(i.id) : undefined;
        const priceK = i.price_kopecks ?? i.priceKopecks ?? null;
        const minutes = i.estimated_minutes ?? i.estimatedMinutes ?? 60;
        const name = i.name ?? '';
        if (incId && currentIds.has(incId)) {
          const cur = currentItems.find((c) => c.id === incId);
          const same = cur && cur.priceKopecks === priceK && (cur.estimatedMinutes ?? 60) === minutes;
          if (!same) edited.push({ id: incId, name, price_kopecks: priceK, estimated_minutes: minutes });
        } else {
          newItems.push({ name, price_kopecks: priceK, estimated_minutes: minutes });
        }
      }
      if (edited.length > 0 || newItems.length > 0) {
        let chat = await this.chats.getChatByOrderId(id);
        if (!chat) {
          console.log('[updateItems] no chat for orderId=' + id + ', creating via createForOrder');
          chat = await this.chats.createForOrder(id);
          console.log('[updateItems] createForOrder returned chat.id=', chat.id);
        }
        if (chat) {
          const chatId = chat.id;
          console.log('[updateItems] sending approval to chatId=', chatId, 'orderId=', id, 'edited=', edited.length, 'newItems=', newItems.length);
          await this.chats.sendMessage(chatId, {
            order_id: id,
            approval_items: { edited_items: edited, new_items: newItems },
          }, false);
          console.log('[updateItems] sendMessage completed for chatId=', chatId);
          return this.findOne(id);
        } else {
          console.log('[updateItems] chat still null after createForOrder, cannot send message');
        }
      }
    }

    await this.itemRepo.delete({ orderId: id });
    const toInsert = (items || []).map((raw) => {
      const i = raw as Record<string, unknown>;
      const refs = this.parseItemServiceRefs(i);
      return this.itemRepo.create({
        orderId: id,
        name: (i.name as string) ?? '',
        priceKopecks: (i.price_kopecks as number) ?? (i.priceKopecks as number) ?? null,
        estimatedMinutes: Number(i.estimated_minutes ?? i.estimatedMinutes ?? 60) || 60,
        isCompleted: (i.is_completed as boolean) ?? false,
        isAdditional: (i.is_additional as boolean) ?? false,
        organizationServiceId: refs.organizationServiceId,
        catalogItemId: refs.catalogItemId,
      });
    });
    await this.itemRepo.save(toInsert);
    return this.findOne(id);
  }

  /** Получить общий чат клиент–СТО по заказу (GET /orders/:id/chat). Всегда один и тот же chatId для пары org+clientPhone. */
  async getChatForOrder(
    orderId: string,
    opts: { organizationId?: string; clientPhone?: string },
  ): Promise<{ chat_id: string }> {
    const order = await this.orderRepo.findOne({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');
    if (opts.organizationId != null) {
      if ((order as any).organizationId !== opts.organizationId) throw new NotFoundException('Order not found');
    } else if (opts.clientPhone != null) {
      const orderPhone = this.normalizePhoneForCompare((order as any).clientPhone || '');
      const userPhone = this.normalizePhoneForCompare(opts.clientPhone);
      if (orderPhone !== userPhone) throw new NotFoundException('Order not found');
      const uid = await this.usersService.findIdByNormalizedPhone(userPhone, 'client');
      if (uid && (await this.isCarHiddenForClient(uid, (order as any).carId))) {
        throw new NotFoundException('Order not found');
      }
    } else {
      throw new NotFoundException('Order not found');
    }
    const orgId = (order as any).organizationId;
    const clientPhone = (order as any).clientPhone || '';
    // Только общий чат по (org, clientPhone). Никакого «чата по заказу».
    const chat = await this.chats.getOrCreateForClient(orgId, clientPhone);
    if (process.env.NODE_ENV === 'development') {
      const existing = await this.chats.findChatByOrgAndPhone(orgId, clientPhone);
      console.log('[GET /orders/:id/chat] orderId=%s organizationId=%s clientPhone=***%s returnedChatId=%s foundExistingChat=%s', orderId, orgId, (clientPhone || '').slice(-4), chat.id, !!existing);
    }
    return { chat_id: chat.id };
  }

  async getOrderPhotos(orderId: string) {
    const order = await this.orderRepo.findOne({ where: { id: orderId } });
    if (!order) return null;
    const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
    const modern = await this.mediaService.listOrderMediaForApi(orderId, baseUrl);
    const legacyPhotos = await this.photoRepo.find({ where: { orderId }, order: { createdAt: 'ASC' } });
    const legacy = legacyPhotos.map((p) => ({
      id: p.id,
      file_path: p.filePath,
      url: `${baseUrl}/orders/${orderId}/photos/${p.id}/file`,
      created_at: p.createdAt.toISOString(),
      media_type: 'image',
      size_bytes: null as number | null,
      width: null as number | null,
      height: null as number | null,
    }));
    const merged = [...modern, ...legacy].sort((a, b) => a.created_at.localeCompare(b.created_at));
    return { items: merged };
  }

  async addOrderPhoto(
    orderId: string,
    file: Express.Multer.File,
    opts?: { uploadedByUserId?: string | null },
  ) {
    const order = await this.orderRepo.findOne({ where: { id: orderId } });
    if (!order) return null;
    const organizationId = (order as any).organizationId as string;
    await this.assertOrderMediaAttachmentLimit(orderId, organizationId);
    const row = await this.mediaService.attachOrderImage({
      orderId,
      organizationId,
      file,
      uploadedByUserId: opts?.uploadedByUserId ?? null,
    });
    const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
    return {
      id: row.id,
      file_path: row.storage_key,
      url: `${baseUrl}/orders/${orderId}/photos/${row.id}/file`,
      created_at: row.created_at,
      media_type: 'image',
      size_bytes: row.size_bytes,
      width: row.width,
      height: row.height,
    };
  }

  async getOrderPhotoFile(orderId: string, photoId: string) {
    const fromMedia = await this.mediaService.getLocalFilePathForOrderPhoto(orderId, photoId);
    if (fromMedia && fs.existsSync(fromMedia)) return fromMedia;
    const photo = await this.photoRepo.findOne({ where: { id: photoId, orderId } });
    if (!photo) return null;
    const absolutePath = path.isAbsolute(photo.filePath) ? photo.filePath : path.join(process.cwd(), photo.filePath);
    if (!fs.existsSync(absolutePath)) return null;
    return absolutePath;
  }

  /**
   * Очистить всю историю заказов в БД: удалить заказы, позиции, фото; отвязать чаты от заказов.
   * Вызывается из POST /orders/clear-all (только для пользователя с organizationId — своей организации).
   */
  async clearAllOrders(organizationId: string): Promise<{ deletedOrders: number; deletedItems: number; deletedPhotos: number }> {
    const orders = await this.orderRepo.find({ where: { organizationId }, select: ['id'] });
    const orderIds = orders.map((o) => o.id);
    if (orderIds.length === 0) {
      return { deletedOrders: 0, deletedItems: 0, deletedPhotos: 0 };
    }
    const { deleted_assets: deletedMediaAssets } = await this.mediaService.purgeMediaForOrders(orderIds);
    const photoResult = await this.photoRepo.createQueryBuilder().delete().where('order_id IN (:...ids)', { ids: orderIds }).execute();
    const deletedLegacyPhotos = photoResult.affected ?? 0;
    const deletedPhotos = deletedMediaAssets + deletedLegacyPhotos;
    const itemResult = await this.itemRepo.createQueryBuilder().delete().where('order_id IN (:...ids)', { ids: orderIds }).execute();
    const deletedItems = itemResult.affected ?? 0;
    await this.chatMsgRepo.createQueryBuilder().update().set({ orderId: null }).where('order_id IN (:...ids)', { ids: orderIds }).execute();
    await this.chatRepo.createQueryBuilder().update().set({ lastOrderId: null }).where('order_id IN (:...ids)', { ids: orderIds }).execute();
    const result = await this.orderRepo.delete({ organizationId });
    const deletedOrders = result.affected ?? 0;
    return { deletedOrders, deletedItems, deletedPhotos };
  }

  /**
   * Полное удаление заказов по car_id (Control Center): медиа, позиции, отвязка чатов, удаление заказов.
   */
  async purgeOrdersByCarIdForInternal(carId: string): Promise<{
    deletedOrders: number;
    deletedItems: number;
    deletedPhotos: number;
  }> {
    const cid = String(carId || '').trim();
    if (!cid) {
      return { deletedOrders: 0, deletedItems: 0, deletedPhotos: 0 };
    }
    const orders = await this.orderRepo.find({ where: { carId: cid }, select: ['id'] });
    const orderIds = orders.map((o) => o.id);
    if (orderIds.length === 0) {
      return { deletedOrders: 0, deletedItems: 0, deletedPhotos: 0 };
    }
    const { deleted_assets: deletedMediaAssets } = await this.mediaService.purgeMediaForOrders(orderIds);
    const photoResult = await this.photoRepo.createQueryBuilder().delete().where('order_id IN (:...ids)', { ids: orderIds }).execute();
    const deletedLegacyPhotos = photoResult.affected ?? 0;
    const deletedPhotos = deletedMediaAssets + deletedLegacyPhotos;
    const itemResult = await this.itemRepo.createQueryBuilder().delete().where('order_id IN (:...ids)', { ids: orderIds }).execute();
    const deletedItems = itemResult.affected ?? 0;
    await this.chatMsgRepo.createQueryBuilder().update().set({ orderId: null }).where('order_id IN (:...ids)', { ids: orderIds }).execute();
    await this.chatRepo.createQueryBuilder().update().set({ lastOrderId: null }).where('order_id IN (:...ids)', { ids: orderIds }).execute();
    const result = await this.orderRepo.createQueryBuilder().delete().where('car_id = :cid', { cid }).execute();
    const deletedOrders = result.affected ?? 0;
    return { deletedOrders, deletedItems, deletedPhotos };
  }

  /**
   * Модерация: очистить поля авто во всех заказах с данным телефоном клиента и car_id.
   */
  async moderateClearCarFieldsForInternal(
    clientPhone: string,
    carId: string,
    fields: { vin?: boolean; license_plate?: boolean; car_info?: boolean; car_photo_url?: boolean },
  ): Promise<{ updated: number }> {
    const norm = this.normalizePhoneForCompare(clientPhone);
    const cid = String(carId || '').trim();
    if (!norm || !cid) return { updated: 0 };
    const orders = await this.orderRepo.find({ where: { carId: cid } });
    let n = 0;
    for (const o of orders) {
      const op = this.normalizePhoneForCompare((o as any).clientPhone || '');
      if (op !== norm) continue;
      const patch: Partial<Order> = {};
      if (fields.vin) (patch as any).vin = null;
      if (fields.license_plate) (patch as any).licensePlate = null;
      if (fields.car_info) (patch as any).carInfo = '';
      if (fields.car_photo_url) (patch as any).carPhotoUrl = null;
      if (Object.keys(patch).length === 0) continue;
      await this.orderRepo.update(o.id, patch as any);
      n += 1;
    }
    return { updated: n };
  }

  /** Агрегат авто из заказов (машины «в приложении» в терминах заказов с car_id). */
  async listClientCarsAggregatedForInternal() {
    const rows = await this.orderRepo.find({
      order: { dateTime: 'DESC' },
    });
    const map = new Map<
      string,
      {
        client_phone: string;
        car_id: string;
        car_info: string;
        client_name: string | null;
        orders_count: number;
        last_order_at: string;
        car_photo_url: string | null;
      }
    >();
    for (const o of rows) {
      const phone = this.normalizePhoneForCompare((o as any).clientPhone || '');
      const carId = (o as any).carId || '';
      if (!phone || !carId) continue;
      const key = `${phone}|${carId}`;
      const photo = ((o as any).carPhotoUrl || '').trim() || null;
      if (!map.has(key)) {
        map.set(key, {
          client_phone: phone,
          car_id: carId,
          car_info: o.carInfo || '',
          client_name: o.clientName ?? null,
          orders_count: 1,
          last_order_at: o.dateTime.toISOString(),
          car_photo_url: photo,
        });
      } else {
        const e = map.get(key)!;
        e.orders_count += 1;
        if ((!e.car_photo_url || !String(e.car_photo_url).trim()) && photo) {
          e.car_photo_url = photo;
        }
      }
    }
    const items = [...map.values()].sort((a, b) => b.last_order_at.localeCompare(a.last_order_at));
    return { items };
  }

  /** История заказов по авто и телефону клиента (для Control Center). */
  async findOrdersByCarForInternal(clientPhoneDigits: string, carId: string) {
    const norm = this.normalizePhoneForCompare(clientPhoneDigits);
    const orders = await this.orderRepo.find({
      where: { carId },
      relations: ['items', 'master', 'organization'],
      order: { dateTime: 'DESC' },
    });
    const filtered = orders.filter((o) => this.normalizePhoneForCompare((o as any).clientPhone || '') === norm);
    const bayCache = new Map<string, Map<string, string>>();
    const avatarMap = await this.buildClientAvatarMapForOrders(filtered);
    return Promise.all(filtered.map((o) => this.toOrderJsonWithApprovalPreview(o, bayCache, avatarMap)));
  }

  /** JSON заказа + при pending_approval блок approval_preview для карточек (состав/сумма как в запросе согласования). */
  async toOrderJsonWithApprovalPreview(
    o: Order,
    orgBayCaches: Map<string, Map<string, string>> = new Map(),
    clientAvatarByPhoneKey?: Map<string, string | null>,
  ): Promise<Record<string, unknown>> {
    let orgMap = orgBayCaches.get(o.organizationId);
    if (!orgMap) {
      const raw = await this.orgService.getSettings(o.organizationId);
      orgMap = bayNameMapFromSlots((raw as { slots?: unknown }).slots);
      orgBayCaches.set(o.organizationId, orgMap);
    }
    const json = this.toOrderJson(o, orgMap, clientAvatarByPhoneKey) as Record<string, unknown>;
    const status = (o as any).status as string;
    if (status !== 'pending_approval') {
      return json;
    }
    const msg = await this.chats.getLastApprovalMessageForOrder(o.id);
    const raw = msg?.approvalItems;
    const preview = this.buildApprovalPreviewFromPayload(o, raw);
    if (preview != null) {
      json.approval_preview = preview;
    }
    return json;
  }

  private parseApprovalPayloadLocal(raw: unknown): unknown {
    if (raw == null) return null;
    if (typeof raw === 'string') {
      try {
        return JSON.parse(raw);
      } catch {
        return null;
      }
    }
    return raw;
  }

  /**
   * Собирает предлагаемый список работ для UI (pending_approval): правки и новые позиции из сообщения чата.
   */
  private buildApprovalPreviewFromPayload(o: Order, rawPayload: unknown): Record<string, unknown> | null {
    const parsed = this.parseApprovalPayloadLocal(rawPayload);
    if (parsed == null) return null;

    const dbItems = ((o as any).items || []) as Array<{
      id: string;
      name: string;
      priceKopecks?: number | null;
      estimatedMinutes?: number;
      isAdditional?: boolean;
    }>;
    const dbRows = dbItems.map((i) => ({
      id: String(i.id),
      name: i.name,
      price_kopecks: i.priceKopecks ?? null,
      estimated_minutes: i.estimatedMinutes ?? 60,
      is_additional: !!i.isAdditional,
      service_id: (i as any).organizationServiceId ?? null,
      catalog_item_id: (i as any).catalogItemId ?? null,
    }));

    if (Array.isArray(parsed)) {
      const additions = parsed as any[];
      if (additions.length === 0) return null;
      const previewItems = [
        ...dbRows,
        ...additions.map((n, index) => ({
          id: String(n.id ?? `proposed_${index}`),
          name: n.name ?? '',
          price_kopecks: n.price_kopecks ?? n.priceKopecks ?? null,
          estimated_minutes: n.estimated_minutes ?? n.estimatedMinutes ?? 60,
          is_additional: true,
        })),
      ];
      const total_kopecks = previewItems.reduce((s, i) => s + (Number(i.price_kopecks) || 0), 0);
      const estimated_minutes = previewItems.reduce((s, i) => s + (Number(i.estimated_minutes) || 0), 0);
      return { items: previewItems, total_kopecks, estimated_minutes };
    }

    if (typeof parsed !== 'object' || parsed === null) return null;
    const obj = parsed as Record<string, any>;
    const edited = (obj.edited_items ?? obj.editedItems ?? []) as any[];
    const newItems = (obj.new_items ?? obj.newItems ?? []) as any[];
    const originalItems = (obj.original_items ?? obj.originalItems ?? []) as any[];
    const totalsAfter = obj.totals_after ?? obj.totalsAfter;

    const editedById = new Map<string, any>();
    for (const e of edited) {
      if (e?.id != null) editedById.set(String(e.id), e);
    }

    const baseOrdered: Array<{
      id: string;
      name: string;
      price_kopecks: number | null;
      estimated_minutes: number;
      is_additional: boolean;
    }> = [];

    if (Array.isArray(originalItems) && originalItems.length > 0) {
      for (const orig of originalItems) {
        const id = orig?.id != null ? String(orig.id) : '';
        if (!id) continue;
        const ed = editedById.get(id);
        if (ed) {
          editedById.delete(id);
          baseOrdered.push({
            id,
            name: ed.name ?? orig.name ?? '',
            price_kopecks: ed.price_kopecks ?? ed.priceKopecks ?? orig.price_kopecks ?? orig.priceKopecks ?? null,
            estimated_minutes:
              ed.estimated_minutes ?? ed.estimatedMinutes ?? orig.estimated_minutes ?? orig.estimatedMinutes ?? 60,
            is_additional: !!(orig.is_additional ?? orig.isAdditional),
          });
        } else {
          baseOrdered.push({
            id,
            name: orig.name ?? '',
            price_kopecks: orig.price_kopecks ?? orig.priceKopecks ?? null,
            estimated_minutes: orig.estimated_minutes ?? orig.estimatedMinutes ?? 60,
            is_additional: !!(orig.is_additional ?? orig.isAdditional),
          });
        }
      }
      const seen = new Set(baseOrdered.map((r) => r.id));
      for (const row of dbRows) {
        if (seen.has(row.id)) continue;
        const ed = editedById.get(row.id);
        if (ed) {
          editedById.delete(row.id);
          baseOrdered.push({
            id: row.id,
            name: ed.name ?? row.name,
            price_kopecks: ed.price_kopecks ?? ed.priceKopecks ?? row.price_kopecks,
            estimated_minutes: ed.estimated_minutes ?? ed.estimatedMinutes ?? row.estimated_minutes,
            is_additional: row.is_additional,
          });
        } else {
          baseOrdered.push(row);
        }
        seen.add(row.id);
      }
    } else {
      for (const row of dbRows) {
        const ed = editedById.get(row.id);
        if (ed) {
          editedById.delete(row.id);
          baseOrdered.push({
            id: row.id,
            name: ed.name ?? row.name,
            price_kopecks: ed.price_kopecks ?? ed.priceKopecks ?? row.price_kopecks,
            estimated_minutes: ed.estimated_minutes ?? ed.estimatedMinutes ?? row.estimated_minutes,
            is_additional: row.is_additional,
          });
        } else {
          baseOrdered.push(row);
        }
      }
    }

    let ni = 0;
    for (const n of newItems) {
      const pid = n?.id != null ? String(n.id) : `proposed_${ni}`;
      baseOrdered.push({
        id: pid,
        name: n.name ?? '',
        price_kopecks: n.price_kopecks ?? n.priceKopecks ?? null,
        estimated_minutes: n.estimated_minutes ?? n.estimatedMinutes ?? 60,
        is_additional: true,
      });
      ni++;
    }

    let total_kopecks: number | null =
      totalsAfter?.price_kopecks != null
        ? Number(totalsAfter.price_kopecks)
        : totalsAfter?.priceKopecks != null
          ? Number(totalsAfter.priceKopecks)
          : null;
    let estimated_minutes: number | null =
      totalsAfter?.estimated_minutes != null
        ? Number(totalsAfter.estimated_minutes)
        : totalsAfter?.estimatedMinutes != null
          ? Number(totalsAfter.estimatedMinutes)
          : null;
    if (total_kopecks == null || Number.isNaN(total_kopecks)) {
      total_kopecks = baseOrdered.reduce((s, i) => s + (Number(i.price_kopecks) || 0), 0);
    }
    if (estimated_minutes == null || Number.isNaN(estimated_minutes)) {
      estimated_minutes = baseOrdered.reduce((s, i) => s + (Number(i.estimated_minutes) || 0), 0);
    }

    return {
      items: baseOrdered,
      total_kopecks,
      estimated_minutes,
    };
  }

  toOrderJson(
    o: Order,
    bayNames: Map<string, string> = new Map(),
    clientAvatarByPhoneKey?: Map<string, string | null>,
  ) {
    const org = (o as any).organization;
    const order = o as any;
    const bid = (o as any).bayId as string | null | undefined;
    const phoneKey = this.usersService.clientPhoneMatchKey(String(o.clientPhone || ''));
    const clientAvatarUrl =
      clientAvatarByPhoneKey && phoneKey ? clientAvatarByPhoneKey.get(phoneKey) ?? null : null;
    return {
      id: o.id,
      order_number: o.orderNumber,
      car_id: o.carId,
      car_info: o.carInfo,
      vin: (o as any).vin ?? null,
      license_plate: (o as any).licensePlate ?? null,
      body_type: (o as any).bodyType ?? null,
      color: (o as any).color ?? null,
      mileage: (o as any).mileage ?? null,
      engine_type: (o as any).engineType ?? null,
      client_name: o.clientName,
      client_phone: o.clientPhone,
      client_avatar_url: clientAvatarUrl,
      car_photo_url: (o as any).carPhotoUrl ?? null,
      status: o.status,
      previous_status: (o as any).previousStatus ?? null,
      first_confirmed_at: (o as any).firstConfirmedAt?.toISOString?.() ?? null,
      date_time: o.dateTime.toISOString(),
      planned_start_time: (o as any).plannedStartTime?.toISOString?.() ?? null,
      planned_end_time: (o as any).plannedEndTime?.toISOString?.() ?? null,
      actual_start_time: (o as any).actualStartTime?.toISOString?.() ?? null,
      actual_end_time: (o as any).actualEndTime?.toISOString?.() ?? null,
      comment: o.comment,
      organization_id: o.organizationId,
      organization_name: org?.name ?? null,
      organization_address: org?.address ?? null,
      organization_phone: org?.phone ?? null,
      organization_business_kind: org
        ? normalizeOrganizationBusinessKind((org as any).businessKind)
        : null,
      organization_scheduling_mode: org ? normalizeSchedulingMode((org as any).schedulingMode) : null,
      master_id: o.masterId,
      master_name: (o as any).master?.name ?? null,
      bay_id: bid ?? null,
      bay_name: bid && bayNames.size ? bayNames.get(bid) ?? null : null,
      created_at: order.createdAt?.toISOString?.() ?? null,
      updated_at: order.updatedAt?.toISOString?.() ?? null,
      items: (o.items || []).map((i) => ({
        id: i.id,
        name: i.name,
        price_kopecks: i.priceKopecks,
        estimated_minutes: i.estimatedMinutes,
        is_completed: i.isCompleted,
        is_additional: i.isAdditional,
        master_id: (i as any).masterId ?? null,
        service_id: (i as any).organizationServiceId ?? null,
        catalog_item_id: (i as any).catalogItemId ?? null,
      })),
    };
  }
}
