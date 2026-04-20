import { forwardRef, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PushDevice } from './push-device.entity';
import { Notification, NotificationType } from './notification.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { FcmPushService } from './fcm-push.service';
import { UsersService } from '../users/users.service';
import {
  channelForNotificationType,
  prefsAllowType,
  notificationTypesAllowedByPrefs,
} from './client-notification-preferences';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(PushDevice) private pushRepo: Repository<PushDevice>,
    @InjectRepository(Notification) private notificationRepo: Repository<Notification>,
    @InjectRepository(StaffMember) private staffRepo: Repository<StaffMember>,
    private fcm: FcmPushService,
    @Inject(forwardRef(() => UsersService)) private users: UsersService,
  ) {}

  async registerDevice(
    userId: string,
    deviceToken: string,
    platform: string,
    fcmApp: 'client' | 'business' = 'client',
  ) {
    const app = fcmApp === 'business' ? 'business' : 'client';
    const existing = await this.pushRepo.findOne({ where: { userId, deviceToken } });
    if (existing) {
      if (existing.fcmApp !== app || existing.platform !== platform) {
        existing.fcmApp = app;
        existing.platform = platform;
        await this.pushRepo.save(existing);
      }
      return;
    }
    const d = this.pushRepo.create({ userId, deviceToken, platform, fcmApp: app });
    await this.pushRepo.save(d);
  }

  private payloadToFcmData(payload: Record<string, unknown> | null | undefined): Record<string, string> {
    const out: Record<string, string> = {};
    if (!payload || typeof payload !== 'object') return out;
    for (const [k, v] of Object.entries(payload)) {
      if (v == null) continue;
      out[k] = typeof v === 'string' ? v : JSON.stringify(v);
    }
    return out;
  }

  /** Push + запись в ленте: приглашение в организацию (если у пользователя уже есть аккаунт). */
  async notifyOrganizationInvite(params: {
    userId: string;
    organizationName: string;
    role: string;
    invitationId: string;
    organizationId: string;
  }): Promise<Notification | null> {
    return this.create({
      userId: params.userId,
      type: 'organization_invite',
      title: `Приглашение в «${params.organizationName}»`,
      body: `Роль: ${params.role}. Откройте MP-Servis Business → Профиль → Входящие приглашения.`,
      payload: {
        invitation_id: params.invitationId,
        organization_id: params.organizationId,
        organization_name: params.organizationName,
        role: params.role,
      },
    });
  }

  /**
   * Создать запись уведомления и отправить FCM (если включено в настройках пользователя).
   * Если тип отключён в настройках — не создаём запись и не шлём push.
   */
  async create(data: {
    userId: string;
    carId?: string | null;
    type: NotificationType;
    title: string;
    body?: string | null;
    payload?: Record<string, unknown> | null;
  }): Promise<Notification | null> {
    const prefs = await this.fcm.getUserPrefs(data.userId);
    if (!prefsAllowType(prefs, data.type)) {
      return null;
    }
    const n = this.notificationRepo.create({
      userId: data.userId,
      carId: data.carId ?? null,
      type: data.type,
      title: data.title,
      body: data.body ?? null,
      payload: data.payload ?? null,
    });
    const saved = await this.notificationRepo.save(n);
    const bodyText = (data.body ?? '').trim() || data.title;
    await this.fcm.sendToUser(
      data.userId,
      channelForNotificationType(data.type),
      data.title,
      bodyText,
      {
        type: data.type,
        notification_id: saved.id,
        ...this.payloadToFcmData(data.payload ?? null),
      },
    );
    return saved;
  }

  /** Уведомление клиента по нормализованному телефону (как в чатах). */
  async createForClientPhone(
    phoneDigits: string,
    data: {
      carId?: string | null;
      type: NotificationType;
      title: string;
      body?: string | null;
      payload?: Record<string, unknown> | null;
    },
  ): Promise<Notification | null> {
    const userId = await this.users.findIdByNormalizedPhone(phoneDigits);
    if (!userId) return null;
    return this.create({ userId, ...data });
  }

  /**
   * Уведомления сотрудникам организации с привязанным user_id (Business): запись в ленту + FCM на business-токены.
   * Канал `order` — те же настройки, что у клиентских «обновления по заказам».
   */
  async notifyOrganizationStaffOrderEvent(
    organizationId: string,
    data: {
      title: string;
      body: string;
      payload: Record<string, unknown> & { order_id: string };
    },
  ): Promise<void> {
    const oid = (organizationId || '').trim();
    if (!oid) return;
    const staff = await this.staffRepo.find({
      where: { organizationId: oid, isActive: true },
      select: ['userId'],
    });
    const userIds = [
      ...new Set(
        staff
          .map((s) => (s.userId ?? '').trim())
          .filter((id) => id.length > 0),
      ),
    ];
    const basePayload = { ...data.payload, organization_id: oid };
    for (const userId of userIds) {
      await this.create({
        userId,
        type: 'order',
        title: data.title,
        body: data.body,
        payload: basePayload,
      });
    }
  }

  /**
   * Сообщение СТО в чате: одно непрочитанное уведомление на chat_id.
   * Заголовок — от кого (передаётся снаружи); в теле копятся строки последних сообщений (новые снизу), пуш в шторке с тем же tag заменяется.
   */
  async createOrRefreshChatMessageForClientPhone(
    phoneDigits: string,
    data: {
      title: string;
      messageLine: string;
      payload: Record<string, unknown> & { chat_id: string };
    },
  ): Promise<Notification | null> {
    const userId = await this.users.findIdByNormalizedPhone(phoneDigits);
    if (!userId) return null;
    const prefs = await this.fcm.getUserPrefs(userId);
    if (!prefsAllowType(prefs, 'chat')) return null;

    const chatId = String(data.payload.chat_id ?? '').trim();
    if (!chatId) return null;

    const dupes = await this.notificationRepo
      .createQueryBuilder('n')
      .where('n.user_id = :userId', { userId })
      .andWhere('n.type = :type', { type: 'chat' })
      .andWhere('n.is_read = false')
      .andWhere("(n.payload->>'chat_id') = :chatId", { chatId })
      .orderBy('n.created_at', 'DESC')
      .getMany();
    const existing = dupes[0];
    if (dupes.length > 1) {
      const extraIds = dupes.slice(1).map((d) => d.id);
      await this.notificationRepo.delete(extraIds);
    }

    const mergedBody = this.mergeChatNotificationBodies(existing?.body ?? null, data.messageLine);
    const mergedPayload = { ...(existing?.payload && typeof existing.payload === 'object' ? existing.payload : {}), ...data.payload };

    let saved: Notification;
    if (existing) {
      await this.notificationRepo.query(
        `UPDATE notifications SET title = $1, body = $2, payload = $3::jsonb, created_at = NOW() WHERE id = $4`,
        [data.title, mergedBody, JSON.stringify(mergedPayload), existing.id],
      );
      const reloaded = await this.notificationRepo.findOne({ where: { id: existing.id } });
      if (!reloaded) return null;
      saved = reloaded;
    } else {
      const n = this.notificationRepo.create({
        userId,
        carId: null,
        type: 'chat',
        title: data.title,
        body: mergedBody,
        payload: mergedPayload,
      });
      saved = await this.notificationRepo.save(n);
    }

    const bodyText = mergedBody.trim() || data.title;
    await this.fcm.sendToUser(
      userId,
      'chat',
      data.title,
      bodyText,
      {
        type: 'chat',
        notification_id: saved.id,
        ...this.payloadToFcmData(saved.payload ?? null),
      },
      { androidTag: `chat_${chatId}`, apnsThreadId: chatId },
    );
    return saved;
  }

  private mergeChatNotificationBodies(prev: string | null, nextLine: string): string {
    const line = (nextLine || '').trim();
    if (!line) return (prev ?? '').trim();
    const lines = (prev ?? '')
      .split('\n')
      .map((l) => l.trimEnd())
      .filter((l) => l.length > 0);
    lines.push(line);
    const maxLines = 6;
    while (lines.length > maxLines) lines.shift();
    let s = lines.join('\n');
    const maxChars = 450;
    if (s.length > maxChars) {
      s = '…\n' + s.slice(s.length - maxChars + 2);
    }
    return s;
  }

  async getNotifications(
    userId: string,
    carId?: string | null,
    respectClientPrefs = false,
  ): Promise<{ items: NotificationDto[] }> {
    let types: NotificationType[] | null = null;
    if (respectClientPrefs) {
      const prefs = await this.fcm.getUserPrefs(userId);
      types = notificationTypesAllowedByPrefs(prefs);
      if (types.length === 0) return { items: [] };
    }
    const qb = this.notificationRepo
      .createQueryBuilder('n')
      .where('n.user_id = :userId', { userId })
      .orderBy('n.created_at', 'DESC');
    if (carId != null && carId !== '') {
      qb.andWhere('(n.car_id = :carId OR n.car_id IS NULL)', { carId });
    }
    if (types) {
      qb.andWhere('n.type IN (:...types)', { types });
    }
    const list = await qb.getMany();
    return {
      items: list.map((n) => ({
        id: n.id,
        carId: n.carId,
        type: n.type,
        title: n.title,
        body: n.body,
        isRead: n.isRead,
        payload: n.payload,
        createdAt: n.createdAt,
      })),
    };
  }

  async markAsRead(userId: string, notificationId: string): Promise<void> {
    const n = await this.notificationRepo.findOne({ where: { id: notificationId, userId } });
    if (!n) throw new NotFoundException('Уведомление не найдено');
    n.isRead = true;
    await this.notificationRepo.save(n);
  }

  async markAllAsRead(userId: string, carId?: string | null): Promise<void> {
    const qb = this.notificationRepo.createQueryBuilder().update(Notification).set({ isRead: true }).where('user_id = :userId', { userId });
    if (carId != null && carId !== '') {
      qb.andWhere('(car_id = :carId OR car_id IS NULL)', { carId });
    }
    await qb.execute();
  }

  /** Пометить непрочитанные уведомления, привязанные к заказу (payload.order_id), после действия в чате / заказе. */
  async markUnreadAsReadByOrderId(userId: string, orderId: string): Promise<void> {
    const oid = (orderId || '').trim();
    if (!oid) return;
    await this.notificationRepo
      .createQueryBuilder()
      .update(Notification)
      .set({ isRead: true })
      .where('user_id = :userId', { userId })
      .andWhere('is_read = false')
      .andWhere("(payload->>'order_id') = :oid", { oid })
      .execute();
  }

  /** Пометить непрочитанные уведомления о сообщениях в этом чате (payload.chat_id). */
  async markUnreadAsReadByChatId(userId: string, chatId: string): Promise<void> {
    const cid = (chatId || '').trim();
    if (!cid) return;
    await this.notificationRepo
      .createQueryBuilder()
      .update(Notification)
      .set({ isRead: true })
      .where('user_id = :userId', { userId })
      .andWhere('is_read = false')
      .andWhere("(payload->>'chat_id') = :cid", { cid })
      .execute();
  }

  async delete(userId: string, notificationId: string): Promise<void> {
    const n = await this.notificationRepo.findOne({ where: { id: notificationId, userId } });
    if (!n) throw new NotFoundException('Уведомление не найдено');
    await this.notificationRepo.remove(n);
  }

  async getUnreadCount(userId: string, respectClientPrefs = false): Promise<number> {
    let types: NotificationType[] | null = null;
    if (respectClientPrefs) {
      const prefs = await this.fcm.getUserPrefs(userId);
      types = notificationTypesAllowedByPrefs(prefs);
      if (types.length === 0) return 0;
    }
    const qb = this.notificationRepo
      .createQueryBuilder('n')
      .where('n.user_id = :userId', { userId })
      .andWhere('n.is_read = false');
    if (types) {
      qb.andWhere('n.type IN (:...types)', { types });
    }
    return qb.getCount();
  }

  async getUnreadCountPerCar(userId: string, respectClientPrefs = false): Promise<Record<string, number>> {
    let types: NotificationType[] | null = null;
    if (respectClientPrefs) {
      const prefs = await this.fcm.getUserPrefs(userId);
      types = notificationTypesAllowedByPrefs(prefs);
      if (types.length === 0) return {};
    }
    const qb = this.notificationRepo
      .createQueryBuilder('n')
      .select('n.car_id', 'carId')
      .addSelect('COUNT(*)', 'cnt')
      .where('n.user_id = :userId', { userId })
      .andWhere('n.is_read = false');
    if (types) {
      qb.andWhere('n.type IN (:...types)', { types });
    }
    qb.groupBy('n.car_id');
    const rows = await qb.getRawMany<{ carId: string | null; cnt: string }>();
    const out: Record<string, number> = {};
    for (const r of rows) {
      const key = r.carId ?? '';
      out[key] = parseInt(r.cnt, 10) || 0;
    }
    return out;
  }
}

export interface NotificationDto {
  id: string;
  carId: string | null;
  type: string;
  title: string;
  body: string | null;
  isRead: boolean;
  payload: Record<string, unknown> | null;
  createdAt: Date;
}
