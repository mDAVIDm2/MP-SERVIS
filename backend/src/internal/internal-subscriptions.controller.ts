import { BadRequestException, Body, Controller, Get, Patch, Post, Param, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('internal/subscriptions')
@UseGuards(InternalJwtAuthGuard)
export class InternalSubscriptionsController {
  constructor(private readonly org: OrganizationsService) {}

  @Get()
  async list() {
    const items = await this.org.findAllSubscriptions();
    return { items };
  }

  /** Справочник тарифов (Control Center). */
  @Get('plans')
  subscriptionPlans() {
    return this.org.listSubscriptionPlansPublic();
  }

  /**
   * Понижение тарифа: выбрать активных сотрудников и записать plan_key.
   * Альтернатива бизнес-эндпоинту POST /organizations/:id/subscription/apply-plan-with-staff.
   */
  @Post(':organizationId/apply-plan-with-staff')
  async applyPlanWithStaff(
    @Param('organizationId') organizationId: string,
    @Body() body: { plan_key?: string; keep_active_staff_ids?: string[] },
  ) {
    const pk = body?.plan_key?.trim();
    if (!pk) throw new BadRequestException('plan_key обязателен');
    const summary = await this.org.applySubscriptionPlanWithActiveStaff(organizationId, {
      plan_key: pk,
      keep_active_staff_ids: Array.isArray(body.keep_active_staff_ids) ? body.keep_active_staff_ids : [],
    });
    return { ok: true, subscription_usage: summary };
  }

  @Patch(':organizationId')
  async update(
    @Param('organizationId') organizationId: string,
    @Body()
    body: { is_active?: boolean; status?: string; plan_key?: string; limits_override?: unknown | null },
  ) {
    const sub = await this.org.updateSubscription(organizationId, {
      is_active: body.is_active,
      status: body.status,
      plan_key: body.plan_key,
      limits_override: body.limits_override,
    });
    if (!sub) return { ok: false, message: 'Подписка не найдена' };
    const subscription_usage = await this.org.getSubscriptionUsageSummary(organizationId);
    return {
      ok: true,
      subscription: {
        id: sub.id,
        organization_id: sub.organizationId,
        is_active: sub.isActive,
        status: sub.status,
        plan_key: (sub as any).planKey ?? 'team',
        limits_override: sub.limitsOverride ?? null,
      },
      subscription_usage,
    };
  }
}
