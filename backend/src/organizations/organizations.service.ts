import { BadRequestException, ConflictException, forwardRef, Inject, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import * as path from 'path';
import * as fs from 'fs';
import { Organization } from './organization.entity';
import { OrganizationSubscription } from './organization-subscription.entity';
import { StaffMember } from './staff-member.entity';
import { OrganizationSettings } from './organization-settings.entity';
import { normalizeOrganizationBusinessKind } from './organization-business-kind';
import { defaultSchedulingModeForBusinessKind, normalizeSchedulingMode } from './organization-scheduling';
import { MasterSchedule } from './master-schedule.entity';
import { ServiceCatalogItem } from '../reference/service-catalog-item.entity';
import { OrganizationInvitation, OrganizationInvitationStatus } from './organization-invitation.entity';
import { SubscriptionQuotaService } from '../subscriptions/subscription-quota.service';
import { UsersService } from '../users/users.service';
import { NotificationsService } from '../notifications/notifications.service';
import { TransactionalMailService } from '../mail/transactional-mail.service';
import {
  getPlanLimits,
  listPublicSubscriptionPlans,
  mergePlanLimitsWithOverride,
  normalizePlanKey,
  sanitizeLimitOverrideValue,
  SubscriptionPlanKey,
} from '../subscriptions/plan-definitions';

export interface CurrentUserForMaster {
  id: string;
  name: string;
  phone: string | null;
  organizationId: string | null;
}

const ORG_PHOTOS_DIR = path.join(process.cwd(), 'uploads', 'organizations');

/** По умолчанию приглашение действует 14 дней, если не передан expires_in_days. */
const DEFAULT_ORG_INVITE_EXPIRY_DAYS = 14;

export interface ScheduleSlotDto {
  day_of_week: number;
  start_time: string;
  end_time: string;
  is_working_day: boolean;
}

@Injectable()
export class OrganizationsService {
  private readonly log = new Logger(OrganizationsService.name);

  constructor(
    @InjectRepository(Organization) private orgRepo: Repository<Organization>,
    @InjectRepository(OrganizationSubscription) private subRepo: Repository<OrganizationSubscription>,
    @InjectRepository(StaffMember) private staffRepo: Repository<StaffMember>,
    @InjectRepository(OrganizationSettings) private settingsRepo: Repository<OrganizationSettings>,
    @InjectRepository(OrganizationInvitation) private invitationRepo: Repository<OrganizationInvitation>,
    @InjectRepository(MasterSchedule) private scheduleRepo: Repository<MasterSchedule>,
    @InjectRepository(ServiceCatalogItem) private catalogItemRepo: Repository<ServiceCatalogItem>,
    private readonly subscriptionQuota: SubscriptionQuotaService,
    private readonly dataSource: DataSource,
    @Inject(forwardRef(() => UsersService)) private readonly usersService: UsersService,
    @Inject(forwardRef(() => NotificationsService)) private readonly notificationsService: NotificationsService,
    private readonly mail: TransactionalMailService,
  ) {}

  listSubscriptionPlansPublic() {
    return { items: listPublicSubscriptionPlans() };
  }

  /** План ключей организаций (для списка в профиле). */
  async getPlanKeysForOrganizations(orgIds: string[]): Promise<Record<string, SubscriptionPlanKey>> {
    if (orgIds.length === 0) return {};
    const subs = await this.subRepo.find({ where: { organizationId: In(orgIds) } });
    const out: Record<string, SubscriptionPlanKey> = {};
    for (const s of subs) {
      out[s.organizationId] = normalizePlanKey((s as any).planKey);
    }
    return out;
  }

  /** Подпись типа организации для клиентского каталога. */
  businessKindLabelRu(kind: string): string {
    const k = normalizeOrganizationBusinessKind(kind);
    const map: Record<string, string> = {
      sto: 'СТО',
      car_wash: 'Мойка',
      detailing: 'Детейлинг',
      car_audio: 'Автозвук',
      tire_service: 'Шиномонтаж',
      body_shop: 'Кузовной',
      glass: 'Стёкла',
      tuning: 'Тюнинг',
      ev_service: 'EV-сервис',
      other: 'Сервис',
    };
    return map[k] ?? 'Автосервис';
  }

  async findAll() {
    return this.orgRepo.find({ order: { name: 'ASC' } });
  }

  async findAllSubscriptions() {
    const list = await this.subRepo.find({
      relations: ['organization'],
      order: { endDate: 'DESC' },
    });
    return list.map((s) => ({
      id: s.id,
      organization_id: s.organizationId,
      organization_name: (s as any).organization?.name ?? null,
      start_date: s.startDate instanceof Date ? s.startDate.toISOString().slice(0, 10) : s.startDate,
      end_date: s.endDate instanceof Date ? s.endDate.toISOString().slice(0, 10) : s.endDate,
      is_active: s.isActive,
      status: s.status,
      plan_key: normalizePlanKey((s as any).planKey),
      limits_override: s.limitsOverride ?? null,
    }));
  }

  /**
   * Патч переопределений: только переданные ключи; null по ключу — убрать переопределение (наследовать тариф).
   */
  private parseLimitsOverridePatch(raw: unknown): Record<string, unknown> {
    if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
      throw new BadRequestException('limits_override должен быть объектом');
    }
    const o = raw as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    const take = (snake: string, camel: string) => {
      if (o[snake] === undefined && o[camel] === undefined) return;
      const v = o[snake] !== undefined ? o[snake] : o[camel];
      if (v === null || v === undefined || (typeof v === 'string' && (v as string).trim() === '')) {
        out[camel] = null;
        return;
      }
      const s = sanitizeLimitOverrideValue(v);
      if (s === undefined) {
        throw new BadRequestException(`Недопустимое значение лимита: ${snake}`);
      }
      out[camel] = s;
    };
    take('max_active_staff', 'maxActiveStaff');
    take('max_confirmed_orders_per_month', 'maxConfirmedOrdersPerMonth');
    take('max_order_media_attachments', 'maxOrderMediaAttachments');
    take('max_chat_images_per_message', 'maxChatImagesPerMessage');
    return out;
  }

  private mergeLimitsOverridePatch(
    previous: Record<string, unknown> | null,
    patch: Record<string, unknown>,
  ): Record<string, unknown> | null {
    const merged: Record<string, unknown> = { ...(previous ?? {}) };
    for (const [k, v] of Object.entries(patch)) {
      if (v === null) delete merged[k];
      else merged[k] = v;
    }
    return Object.keys(merged).length === 0 ? null : merged;
  }

  async updateSubscription(
    organizationId: string,
    dto: { is_active?: boolean; status?: string; plan_key?: string; limits_override?: unknown },
  ): Promise<OrganizationSubscription | null> {
    const sub = await this.subRepo.findOne({ where: { organizationId } });
    if (!sub) return null;

    const oldKey = normalizePlanKey((sub as any).planKey);
    const nextPlanKey = dto.plan_key !== undefined ? normalizePlanKey(dto.plan_key) : oldKey;
    let nextOverride: Record<string, unknown> | null;
    if (!('limits_override' in dto)) {
      nextOverride = (sub.limitsOverride as Record<string, unknown> | null) ?? null;
    } else if (dto.limits_override === null) {
      nextOverride = null;
    } else {
      const patch = this.parseLimitsOverridePatch(dto.limits_override);
      nextOverride = this.mergeLimitsOverridePatch((sub.limitsOverride as Record<string, unknown> | null) ?? null, patch);
    }
    const planKeyChanging = dto.plan_key !== undefined && nextPlanKey !== oldKey;

    if (dto.plan_key !== undefined || 'limits_override' in dto) {
      const mergedNext = mergePlanLimitsWithOverride(getPlanLimits(nextPlanKey), nextOverride);
      const effMaxStaff = mergedNext.maxActiveStaff;
      if (effMaxStaff !== null) {
        const activeCount = await this.subscriptionQuota.countActiveStaff(organizationId);
        if (activeCount > effMaxStaff) {
          if (planKeyChanging) {
            const staffRows = await this.staffRepo.find({
              where: { organizationId },
              order: { name: 'ASC' },
            });
            throw new ConflictException({
              code: 'STAFF_DOWNGRADE_REQUIRED',
              message: `Активных сотрудников: ${activeCount}, эффективный лимит при тарифе «${nextPlanKey}»: ${effMaxStaff}. Используйте apply-plan-with-staff или увеличьте лимит в переопределении.`,
              organization_id: organizationId,
              current_plan_key: oldKey,
              requested_plan_key: nextPlanKey,
              max_active_staff: effMaxStaff,
              active_staff_count: activeCount,
              staff: staffRows.map((s) => ({
                id: s.id,
                name: s.name,
                role: s.role,
                is_active: (s as any).isActive !== false,
              })),
            });
          }
          throw new BadRequestException(
            `Активных сотрудников: ${activeCount}, эффективный лимит: ${effMaxStaff}. Уменьшите активных или увеличьте лимит.`,
          );
        }
      }
    }

    if (dto.is_active !== undefined) sub.isActive = dto.is_active;
    if (dto.status !== undefined) sub.status = dto.status;
    if (dto.plan_key !== undefined) (sub as any).planKey = nextPlanKey;
    if ('limits_override' in dto) sub.limitsOverride = nextOverride;
    await this.subRepo.save(sub);
    return sub;
  }

  /**
   * Смена тарифа с явным набором активных сотрудников (понижение плана).
   * Остальные сотрудники организации переводятся в is_active=false.
   */
  async applySubscriptionPlanWithActiveStaff(
    organizationId: string,
    dto: { plan_key: string; keep_active_staff_ids: string[] },
  ) {
    const newKey = normalizePlanKey(dto.plan_key);
    const subRow = await this.subRepo.findOne({ where: { organizationId } });
    const merged = mergePlanLimitsWithOverride(getPlanLimits(newKey), subRow?.limitsOverride ?? null);
    const max = merged.maxActiveStaff;
    const keep = [...new Set((dto.keep_active_staff_ids ?? []).map((x) => String(x).trim()).filter(Boolean))];

    if (max !== null && keep.length > max) {
      throw new BadRequestException(
        `Можно оставить активными не более ${max} сотрудник(ов) для тарифа «${newKey}».`,
      );
    }

    const allStaff = await this.staffRepo.find({ where: { organizationId } });
    const idSet = new Set(allStaff.map((s) => s.id));
    for (const sid of keep) {
      if (!idSet.has(sid)) {
        throw new BadRequestException(`Сотрудник не найден в организации: ${sid}`);
      }
    }

    await this.dataSource.transaction(async (em) => {
      for (const s of allStaff) {
        const active = keep.includes(s.id);
        if ((s as any).isActive !== active) {
          await em.update(StaffMember, { id: s.id, organizationId }, { isActive: active } as any);
        }
      }
      const sub = await em.findOne(OrganizationSubscription, { where: { organizationId } });
      if (!sub) {
        throw new BadRequestException('Подписка организации не найдена');
      }
      (sub as any).planKey = newKey;
      await em.save(sub);
    });

    return this.getSubscriptionUsageSummary(organizationId);
  }

  /** Сводка тарифа и расхода лимитов для бизнес-приложения / Control Center. */
  async getSubscriptionUsageSummary(organizationId: string) {
    return this.subscriptionQuota.getSubscriptionUsageSummary(organizationId);
  }

  /** Проверить, активна ли подписка организации (для блокировки бизнес-пользователей). */
  async isSubscriptionActive(organizationId: string): Promise<boolean> {
    const sub = await this.subRepo.findOne({ where: { organizationId } });
    if (!sub) return true; // нет записи — считаем активной (обратная совместимость)
    if (!sub.isActive) return false;
    if (sub.status === 'deactivated' || sub.status === 'expired') return false;
    if (sub.endDate && new Date(sub.endDate) < new Date()) return false; // просрочена по дате
    return true;
  }

  async findOne(id: string) {
    return this.orgRepo.findOne({ where: { id } });
  }

  /** Новая организация с подпиской и пустыми настройками (владелец — через membership у пользователя). */
  async createOrganizationWithDefaults(dto: {
    name: string;
    address?: string;
    phone?: string;
    /** Тариф при создании (по умолчанию team). */
    plan_key?: string;
  }): Promise<Organization> {
    const org = this.orgRepo.create({
      name: (dto.name && dto.name.trim()) || 'Новая организация',
      address: dto.address != null ? String(dto.address).trim() : '',
      phone: dto.phone != null ? String(dto.phone).trim() : '',
      workingHours: 'Пн–Пт 9:00–19:00',
      timezone: 'Europe/Moscow',
    });
    await this.orgRepo.save(org);
    const startDate = new Date();
    const endDate = new Date(startDate);
    endDate.setFullYear(endDate.getFullYear() + 1);
    const planKey = normalizePlanKey(dto.plan_key);
    const sub = this.subRepo.create({
      organizationId: org.id,
      startDate,
      endDate,
      isActive: true,
      status: 'active',
      planKey,
      limitsOverride: null,
    });
    await this.subRepo.save(sub);
    const settings = this.settingsRepo.create({ organizationId: org.id, data: {} });
    await this.settingsRepo.save(settings);
    return org;
  }

  async update(
    id: string,
    dto: {
      name?: string;
      address?: string;
      phone?: string;
      working_hours?: string;
      timezone?: string;
      latitude?: number | null;
      longitude?: number | null;
      business_kind?: string;
      scheduling_mode?: string;
    },
  ) {
    const updateData: Record<string, string | number | null> = {};
    if (dto.name != null) updateData['name'] = dto.name;
    if (dto.address != null) updateData['address'] = dto.address;
    if (dto.phone != null) updateData['phone'] = dto.phone;
    if (dto.working_hours != null) updateData['workingHours'] = dto.working_hours;
    if (dto.timezone != null) updateData['timezone'] = dto.timezone;
    if (dto.latitude !== undefined) updateData['latitude'] = dto.latitude;
    if (dto.longitude !== undefined) updateData['longitude'] = dto.longitude;
    if (dto.business_kind != null) {
      const nk = normalizeOrganizationBusinessKind(dto.business_kind);
      updateData['businessKind'] = nk;
      if (dto.scheduling_mode == null) {
        updateData['schedulingMode'] = defaultSchedulingModeForBusinessKind(nk);
      }
    }
    if (dto.scheduling_mode != null) {
      updateData['schedulingMode'] = normalizeSchedulingMode(dto.scheduling_mode);
    }
    if (Object.keys(updateData).length > 0) {
      await this.orgRepo.update(id, updateData);
    }
    return this.orgRepo.findOne({ where: { id } });
  }

  async getStaff(orgId: string) {
    const list = await this.staffRepo.find({
      where: { organizationId: orgId },
      relations: ['schedule'],
      order: { invitedAt: 'DESC' },
    });
    return { items: list.map((s) => this._staffToItem(s)) };
  }

  /** Добавить текущего пользователя (владелец/админ) как мастера. После вызова нужно задать график работы. */
  async addCurrentUserAsMaster(orgId: string, user: CurrentUserForMaster) {
    if (user.organizationId !== orgId) {
      throw new BadRequestException('Пользователь не принадлежит этой организации');
    }
    const existing = await this.staffRepo.findOne({
      where: { organizationId: orgId, userId: user.id },
    });
    if (existing) {
      throw new ConflictException('Вы уже добавлены как мастер в этой организации');
    }
    const staff = this.staffRepo.create({
      organizationId: orgId,
      userId: user.id,
      name: user.name || 'Мастер',
      phone: user.phone || null,
      role: 'master',
      isActive: true,
      invitedAt: new Date(),
      skills: [],
    });
    await this.staffRepo.save(staff);
    const withSchedule = await this.staffRepo.findOne({
      where: { id: staff.id },
      relations: ['schedule'],
    });
    return this._staffToItem(withSchedule!);
  }

  private _staffToItem(s: StaffMember) {
    return {
      id: s.id,
      user_id: (s as any).userId ?? null,
      name: s.name,
      phone: s.phone,
      email: (s as any).email ?? null,
      role: s.role,
      is_active: (s as any).isActive !== false,
      invited_at: (s as any).invitedAt?.toISOString?.(),
      skills: Array.isArray((s as any).skills) ? (s as any).skills : [],
      schedule: Array.isArray((s as any).schedule)
        ? (s as any).schedule.map((sch: MasterSchedule) => ({
            id: sch.id,
            day_of_week: sch.dayOfWeek,
            start_time: sch.startTime,
            end_time: sch.endTime,
            is_working_day: sch.isWorkingDay,
          }))
        : [],
    };
  }

  private normalizePhoneLoose(raw?: string | null): string | null {
    if (!raw) return null;
    const d = String(raw).replace(/\D/g, '');
    if (!d) return null;
    if (d.length === 11 && d.startsWith('8')) return '7' + d.slice(1);
    if (d.length === 10 && !d.startsWith('7')) return '7' + d;
    return d;
  }

  private normalizeEmail(raw?: string | null): string | null {
    if (!raw) return null;
    const v = String(raw).trim().toLowerCase();
    return v || null;
  }

  private invitationToItem(inv: OrganizationInvitation) {
    return {
      id: inv.id,
      organization_id: inv.organizationId,
      invited_by_user_id: inv.invitedByUserId,
      accepted_by_user_id: inv.acceptedByUserId,
      staff_member_id: inv.staffMemberId,
      role: inv.role,
      invited_name: inv.invitedName,
      invited_email: inv.invitedEmail,
      invited_phone: inv.invitedPhone,
      status: inv.status,
      message: inv.message,
      expires_at: inv.expiresAt?.toISOString() ?? null,
      responded_at: inv.respondedAt?.toISOString() ?? null,
      created_at: inv.createdAt?.toISOString() ?? null,
      updated_at: inv.updatedAt?.toISOString() ?? null,
      organization_name: inv.organization?.name ?? null,
    };
  }

  private async dispatchInvitationSideEffects(inv: OrganizationInvitation, invitedByUserId: string): Promise<void> {
    const orgName = inv.organization?.name ?? 'Организация';
    const recipientId = await this.usersService.findUserIdForInviteContact(inv.invitedEmailNorm, inv.invitedPhoneNorm);
    if (recipientId) {
      await this.notificationsService.notifyOrganizationInvite({
        userId: recipientId,
        organizationName: orgName,
        role: inv.role,
        invitationId: inv.id,
        organizationId: inv.organizationId,
      });
    }

    const toEmail = inv.invitedEmail?.trim();
    if (toEmail && this.mail.isConfigured()) {
      const inviter = await this.usersService.findById(invitedByUserId);
      const inviterName = inviter?.name?.trim() || 'Сотрудник';
      const expiresText = inv.expiresAt
        ? `Срок действия: до ${inv.expiresAt.toISOString().slice(0, 10)} (UTC).`
        : '';
      const text = [
        'Здравствуйте!',
        '',
        `${inviterName} приглашает вас в организацию «${orgName}» (роль: ${inv.role}).`,
        expiresText,
        '',
        'Откройте приложение AutoHub Business, войдите под этим email и перейдите: Профиль → Входящие приглашения.',
        '',
        '— AutoHub',
      ]
        .filter((line) => line !== '')
        .join('\n');

      try {
        await this.mail.send({
          to: toEmail,
          subject: `Приглашение в «${orgName}» — AutoHub`,
          text,
        });
      } catch (e) {
        this.log.warn(`Не удалось отправить письмо с приглашением: ${e}`);
      }
    }
  }

  async createInvitation(
    orgId: string,
    invitedByUserId: string,
    dto: { name?: string; phone?: string; email?: string; role: string; message?: string; expires_in_days?: number },
  ) {
    const emailNorm = this.normalizeEmail(dto.email);
    const phoneNorm = this.normalizePhoneLoose(dto.phone);
    if (!emailNorm && !phoneNorm) {
      throw new BadRequestException('Укажите email и/или телефон');
    }
    await this.subscriptionQuota.assertCanAddOrActivateStaff(orgId);
    if (emailNorm) {
      const dup = await this.invitationRepo.findOne({
        where: { organizationId: orgId, invitedEmailNorm: emailNorm, status: 'pending' },
      });
      if (dup) throw new ConflictException('Приглашение на этот email уже отправлено и ожидает подтверждения');
    }
    if (phoneNorm) {
      const dup = await this.invitationRepo.findOne({
        where: { organizationId: orgId, invitedPhoneNorm: phoneNorm, status: 'pending' },
      });
      if (dup) throw new ConflictException('Приглашение на этот телефон уже отправлено и ожидает подтверждения');
    }
    const expiresInDays = Number(dto.expires_in_days);
    const expiresAt =
      Number.isFinite(expiresInDays) && expiresInDays > 0
        ? new Date(Date.now() + Math.floor(expiresInDays) * 24 * 60 * 60 * 1000)
        : new Date(Date.now() + DEFAULT_ORG_INVITE_EXPIRY_DAYS * 24 * 60 * 60 * 1000);
    const row = this.invitationRepo.create({
      organizationId: orgId,
      invitedByUserId,
      role: String(dto.role || 'master'),
      invitedName: dto.name?.trim() || null,
      invitedEmail: dto.email?.trim() || null,
      invitedEmailNorm: emailNorm,
      invitedPhone: dto.phone?.trim() || null,
      invitedPhoneNorm: phoneNorm,
      message: dto.message?.trim() || null,
      status: 'pending',
      expiresAt,
      respondedAt: null,
      acceptedByUserId: null,
      staffMemberId: null,
    });
    await this.invitationRepo.save(row);
    const fresh = await this.invitationRepo.findOne({
      where: { id: row.id },
      relations: ['organization'],
    });
    if (fresh) {
      void this.dispatchInvitationSideEffects(fresh, invitedByUserId).catch((e) => this.log.warn(String(e)));
    }
    return this.invitationToItem(fresh!);
  }

  async listInvitations(orgId: string, status?: OrganizationInvitationStatus) {
    const qb = this.invitationRepo
      .createQueryBuilder('inv')
      .leftJoinAndSelect('inv.organization', 'org')
      .where('inv.organization_id = :orgId', { orgId })
      .orderBy('inv.created_at', 'DESC');
    if (status) {
      qb.andWhere('inv.status = :status', { status });
    }
    if (status === 'pending') {
      qb.andWhere('(inv.expires_at IS NULL OR inv.expires_at > :now)', { now: new Date() });
    }
    const rows = await qb.getMany();
    return { items: rows.map((x) => this.invitationToItem(x)) };
  }

  async cancelInvitation(orgId: string, invitationId: string) {
    const inv = await this.invitationRepo.findOne({ where: { id: invitationId, organizationId: orgId } });
    if (!inv) {
      throw new BadRequestException('Приглашение не найдено');
    }
    if (inv.status !== 'pending') {
      throw new BadRequestException('Можно отменить только приглашение в статусе pending');
    }
    inv.status = 'cancelled';
    inv.respondedAt = new Date();
    await this.invitationRepo.save(inv);
    const fresh = await this.invitationRepo.findOne({ where: { id: invitationId }, relations: ['organization'] });
    return this.invitationToItem(fresh!);
  }

  async inviteStaff(orgId: string, dto: { name: string; phone?: string; email?: string; role: string }) {
    await this.subscriptionQuota.assertCanAddOrActivateStaff(orgId);
    const s = this.staffRepo.create({ ...dto, organizationId: orgId, invitedAt: new Date() });
    await this.staffRepo.save(s);
    const withSchedule = await this.staffRepo.findOne({ where: { id: s.id }, relations: ['schedule'] });
    return withSchedule ? this._staffToItem(withSchedule) : this._staffToItem(s);
  }

  async updateStaffMember(orgId: string, staffId: string, dto: Record<string, unknown>) {
    const staff = await this.staffRepo.findOne({ where: { id: staffId, organizationId: orgId }, relations: ['schedule'] });
    if (!staff) return null;

    const newRole = dto.role !== undefined ? String(dto.role) : staff.role;
    const scheduleFromDto = Array.isArray(dto.schedule) ? (dto.schedule as ScheduleSlotDto[]) : null;
    const effectiveSchedule = scheduleFromDto ?? (staff as any).schedule ?? [];

    const wasActive = (staff as any).isActive !== false;
    if (dto.is_active === true && !wasActive) {
      await this.subscriptionQuota.assertCanAddOrActivateStaff(orgId, staffId);
    }

    // Для роли «мастер» обязателен график: хотя бы один рабочий день.
    if (newRole === 'master') {
      const workingSlots = scheduleFromDto
        ? scheduleFromDto.filter((slot) => slot.is_working_day !== false)
        : (Array.isArray((staff as any).schedule) ? (staff as any).schedule : []).filter((sch: MasterSchedule) => sch.isWorkingDay);
      if (workingSlots.length === 0) {
        throw new BadRequestException('У мастера должен быть указан график работы: выберите хотя бы один рабочий день');
      }
    }

    const setObj: Record<string, unknown> = {};
    if (dto.name !== undefined) setObj.name = String(dto.name);
    if (dto.phone !== undefined) setObj.phone = dto.phone === null ? null : String(dto.phone);
    if (dto.email !== undefined) setObj.email = dto.email === null ? null : String(dto.email);
    if (dto.role !== undefined) setObj.role = String(dto.role);
    if (dto.is_active !== undefined) setObj.isActive = Boolean(dto.is_active);
    if (Array.isArray(dto.skills)) setObj.skills = dto.skills as string[];

    try {
      if (Object.keys(setObj).length > 0) {
        await this.staffRepo.update({ id: staffId, organizationId: orgId }, setObj as any);
      }

      if (Array.isArray(dto.schedule)) {
        await this.scheduleRepo.delete({ masterId: staffId });
        const slots = dto.schedule as ScheduleSlotDto[];
        for (const slot of slots) {
          const dayOfWeek = Number(slot.day_of_week);
          if (Number.isNaN(dayOfWeek) || dayOfWeek < 0 || dayOfWeek > 6) continue;
          const startTime = slot.start_time != null ? String(slot.start_time).slice(0, 5) : '09:00';
          const endTime = slot.end_time != null ? String(slot.end_time).slice(0, 5) : '18:00';
          const row = this.scheduleRepo.create({
            masterId: staffId,
            dayOfWeek,
            startTime: /^\d{1,2}:\d{2}$/.test(startTime) ? startTime : '09:00',
            endTime: /^\d{1,2}:\d{2}$/.test(endTime) ? endTime : '18:00',
            isWorkingDay: slot.is_working_day !== false,
          });
          await this.scheduleRepo.save(row);
        }
      }
    } catch (err: any) {
      if (err instanceof BadRequestException) throw err;
      throw new BadRequestException(err?.message ?? 'Не удалось обновить сотрудника');
    }

    const s = await this.staffRepo.findOne({ where: { id: staffId }, relations: ['schedule'] });
    if (!s) return null;
    return this._staffToItem(s);
  }

  async getSettings(orgId: string): Promise<Record<string, unknown>> {
    let row = await this.settingsRepo.findOne({ where: { organizationId: orgId } });
    if (!row) {
      row = this.settingsRepo.create({ organizationId: orgId, data: {} });
      await this.settingsRepo.save(row);
    }
    const data = row.data;
    if (data === null || typeof data !== 'object') return {};
    const out = data as Record<string, unknown>;
    return {
      ...out,
      categories: Array.isArray(out.categories) ? out.categories : [],
      services: Array.isArray(out.services) ? out.services : [],
    };
  }

  async updateSettings(orgId: string, data: Record<string, unknown>) {
    await this.assertServicesAllowedForOrganizationKind(orgId, data);
    let row = await this.settingsRepo.findOne({ where: { organizationId: orgId } });
    if (!row) {
      row = this.settingsRepo.create({ organizationId: orgId, data });
      await this.settingsRepo.save(row);
    } else {
      row.data = data;
      await this.settingsRepo.save(row);
    }
    return row.data;
  }

  /** Позиции из единого справочника (id svc_*) должны быть разрешены для business_kind организации. */
  private async assertServicesAllowedForOrganizationKind(orgId: string, data: Record<string, unknown>): Promise<void> {
    const org = await this.orgRepo.findOne({ where: { id: orgId } });
    if (!org) return;
    const kind = normalizeOrganizationBusinessKind((org as any).businessKind);
    const services = data['services'];
    if (!Array.isArray(services)) return;
    const catalogIds: string[] = [];
    for (const s of services) {
      if (s && typeof s === 'object' && 'id' in s) {
        const id = String((s as { id?: string }).id ?? '');
        if (id.startsWith('svc_')) catalogIds.push(id);
      }
    }
    if (catalogIds.length === 0) return;
    const rows = await this.catalogItemRepo.find({ where: { id: In(catalogIds) } });
    const byId = new Map(rows.map((r) => [r.id, r]));
    for (const id of catalogIds) {
      const row = byId.get(id);
      if (!row) {
        throw new BadRequestException(
          `Неизвестная позиция справочника (${id}). Выберите услугу из актуального каталога или уберите эту строку.`,
        );
      }
      const allowed = Array.isArray(row.allowedBusinessKinds) ? row.allowedBusinessKinds : ['sto'];
      if (!allowed.includes(kind)) {
        throw new BadRequestException(
          `Услуга «${row.name}» из справочника недоступна для типа организации «${this.businessKindLabelRu(kind)}». Выберите другой тип точки в настройках или уберите услугу.`,
        );
      }
    }
  }

  async addPhoto(orgId: string, file: Express.Multer.File): Promise<{ url: string } | null> {
    const org = await this.orgRepo.findOne({ where: { id: orgId } });
    if (!org) return null;
    const dir = path.join(ORG_PHOTOS_DIR, orgId);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const ext = path.extname(file.originalname) || '.jpg';
    const filename = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${ext}`;
    const filePath = path.join(dir, filename);
    if (file.buffer?.length) {
      fs.writeFileSync(filePath, file.buffer);
    } else if (file.path && fs.existsSync(file.path)) {
      fs.copyFileSync(file.path, filePath);
    } else {
      return null;
    }
    const baseUrl = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
    const url = `${baseUrl}/organizations/${orgId}/photos/${filename}`;
    const photoUrls = Array.isArray((org as any).photoUrls) ? [...(org as any).photoUrls] : [];
    photoUrls.push(url);
    await this.orgRepo.update(orgId, { photoUrls } as any);
    return { url };
  }

  async getPhotoPath(orgId: string, filename: string): Promise<string | null> {
    const org = await this.orgRepo.findOne({ where: { id: orgId } });
    if (!org) return null;
    const fullPath = path.join(ORG_PHOTOS_DIR, orgId, filename);
    if (!fs.existsSync(fullPath)) return null;
    return fullPath;
  }

  getPhotoUrls(org: Organization): string[] {
    const urls = (org as any).photoUrls;
    return Array.isArray(urls) ? urls : [];
  }
}
