import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DateTime } from 'luxon';
import { Order } from '../orders/order.entity';
import { Organization } from '../organizations/organization.entity';
import { OrganizationSubscription } from '../organizations/organization-subscription.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import {
  getPlanLimits,
  mergePlanLimitsWithOverride,
  normalizePlanKey,
  SubscriptionPlanKey,
  SubscriptionPlanLimits,
} from './plan-definitions';

/** Лимиты в JSON API (snake_case), единообразно с полями организаций и Control Center. */
export type SubscriptionLimitsSnake = {
  max_active_staff: number | null;
  max_confirmed_orders_per_month: number | null;
  max_order_media_attachments: number | null;
  max_chat_images_per_message: number | null;
};

export function subscriptionLimitsToSnake(l: SubscriptionPlanLimits): SubscriptionLimitsSnake {
  return {
    max_active_staff: l.maxActiveStaff,
    max_confirmed_orders_per_month: l.maxConfirmedOrdersPerMonth,
    max_order_media_attachments: l.maxOrderMediaAttachments,
    max_chat_images_per_message: l.maxChatImagesPerMessage,
  };
}

@Injectable()
export class SubscriptionQuotaService {
  constructor(
    @InjectRepository(Order) private readonly orderRepo: Repository<Order>,
    @InjectRepository(Organization) private readonly orgRepo: Repository<Organization>,
    @InjectRepository(OrganizationSubscription)
    private readonly subRepo: Repository<OrganizationSubscription>,
    @InjectRepository(StaffMember) private readonly staffRepo: Repository<StaffMember>,
  ) {}

  async getPlanKeyForOrganization(organizationId: string): Promise<SubscriptionPlanKey> {
    const sub = await this.subRepo.findOne({ where: { organizationId } });
    return normalizePlanKey(sub?.planKey);
  }

  async getLimitsForOrganization(organizationId: string): Promise<SubscriptionPlanLimits> {
    const sub = await this.getSubscription(organizationId);
    const key = normalizePlanKey(sub?.planKey);
    const base = getPlanLimits(key);
    return mergePlanLimitsWithOverride(base, sub?.limitsOverride ?? null);
  }

  /** Тариф Solo: один исполнитель без staff_members; слот записи — как один мастер. */
  async isSoloPlan(organizationId: string): Promise<boolean> {
    const key = await this.getPlanKeyForOrganization(organizationId);
    return key === 'solo';
  }

  /** Должна совпадать с логикой OrganizationsService.isSubscriptionActive. */
  isSubscriptionRecordActive(sub: OrganizationSubscription | null): boolean {
    if (!sub) return true;
    if (!sub.isActive) return false;
    if (sub.status === 'deactivated' || sub.status === 'expired') return false;
    if (sub.endDate && new Date(sub.endDate) < new Date()) return false;
    return true;
  }

  private async getSubscription(organizationId: string): Promise<OrganizationSubscription | null> {
    return this.subRepo.findOne({ where: { organizationId } });
  }

  async assertSubscriptionAllowsWrites(organizationId: string): Promise<void> {
    const sub = await this.getSubscription(organizationId);
    if (!this.isSubscriptionRecordActive(sub)) {
      throw new BadRequestException(
        'Подписка организации неактивна или истекла. Продлите подписку, чтобы продолжить работу.',
      );
    }
  }

  /**
   * Границы биллингового месяца в UTC по календарю в часовом поясе организации.
   */
  async getBillingMonthUtcRange(
    organizationId: string,
    now: Date = new Date(),
  ): Promise<{ startUtc: Date; endExclusiveUtc: Date }> {
    const org = await this.orgRepo.findOne({ where: { id: organizationId }, select: ['id', 'timezone'] });
    const zone = (org as any)?.timezone && String((org as any).timezone).trim() ? String((org as any).timezone).trim() : 'Europe/Moscow';
    const localNow = DateTime.fromJSDate(now, { zone: 'utc' }).setZone(zone);
    const startLocal = localNow.startOf('month');
    const endLocal = startLocal.plus({ months: 1 });
    return {
      startUtc: startLocal.toUTC().toJSDate(),
      endExclusiveUtc: endLocal.toUTC().toJSDate(),
    };
  }

  async countConfirmedOrdersInBillingMonth(organizationId: string, now?: Date): Promise<number> {
    const { startUtc, endExclusiveUtc } = await this.getBillingMonthUtcRange(organizationId, now);
    return this.orderRepo
      .createQueryBuilder('o')
      .where('o.organization_id = :orgId', { orgId: organizationId })
      .andWhere('o.first_confirmed_at IS NOT NULL')
      .andWhere('o.first_confirmed_at >= :start', { start: startUtc })
      .andWhere('o.first_confirmed_at < :end', { end: endExclusiveUtc })
      .getCount();
  }

  /**
   * Расход одного слота лимита: первый выход из pending_confirmation в confirmed | in_progress.
   */
  async assertCanConsumeConfirmedOrderSlot(organizationId: string): Promise<void> {
    await this.assertSubscriptionAllowsWrites(organizationId);
    const limits = await this.getLimitsForOrganization(organizationId);
    const max = limits.maxConfirmedOrdersPerMonth;
    if (max == null) return;
    const used = await this.countConfirmedOrdersInBillingMonth(organizationId);
    if (used >= max) {
      throw new BadRequestException(
        'Достигнут лимит подтверждённых записей по тарифу на этот месяц. Обновите тариф или дождитесь следующего расчётного периода.',
      );
    }
  }

  async countActiveStaff(organizationId: string): Promise<number> {
    return this.staffRepo.count({
      where: { organizationId, isActive: true },
    });
  }

  /**
   * Перед добавлением нового активного сотрудника или активацией существующего.
   * @param excludeStaffId не учитывать эту запись (при активации того же сотрудника).
   */
  async assertCanAddOrActivateStaff(organizationId: string, excludeStaffId?: string | null): Promise<void> {
    await this.assertSubscriptionAllowsWrites(organizationId);
    const limits = await this.getLimitsForOrganization(organizationId);
    const max = limits.maxActiveStaff;
    if (max == null) return;

    const qb = this.staffRepo
      .createQueryBuilder('s')
      .where('s.organization_id = :orgId', { orgId: organizationId })
      .andWhere('s.is_active = true');
    if (excludeStaffId) {
      qb.andWhere('s.id != :sid', { sid: excludeStaffId });
    }
    const active = await qb.getCount();
    if (active >= max) {
      throw new BadRequestException(
        `Достигнут лимит сотрудников по тарифу (${max}). Обновите тариф, чтобы добавить ещё.`,
      );
    }
  }

  async getSubscriptionUsageSummary(organizationId: string): Promise<{
    plan_key: SubscriptionPlanKey;
    /** Эффективные лимиты (тариф + переопределение из Control Center). */
    limits: SubscriptionLimitsSnake;
    /** Лимиты только по тарифу (без переопределения). */
    plan_limits: SubscriptionLimitsSnake;
    /** Сырое переопределение из БД или null. */
    limits_override: Record<string, unknown> | null;
    subscription_active: boolean;
    subscription_status: string | null;
    subscription_end_date: string | null;
    confirmed_orders_this_month: number;
    active_staff: number;
  }> {
    const sub = await this.getSubscription(organizationId);
    const planKey = normalizePlanKey(sub?.planKey);
    const planLimits = getPlanLimits(planKey);
    const override = sub?.limitsOverride ?? null;
    const limits = mergePlanLimitsWithOverride(planLimits, override);
    const [confirmed_orders_this_month, active_staff] = await Promise.all([
      this.countConfirmedOrdersInBillingMonth(organizationId),
      this.countActiveStaff(organizationId),
    ]);
    return {
      plan_key: planKey,
      limits: subscriptionLimitsToSnake(limits),
      plan_limits: subscriptionLimitsToSnake(planLimits),
      limits_override: override,
      subscription_active: this.isSubscriptionRecordActive(sub),
      subscription_status: sub?.status ?? null,
      subscription_end_date:
        sub?.endDate instanceof Date ? sub.endDate.toISOString().slice(0, 10) : sub?.endDate ? String(sub.endDate).slice(0, 10) : null,
      confirmed_orders_this_month,
      active_staff,
    };
  }
}
