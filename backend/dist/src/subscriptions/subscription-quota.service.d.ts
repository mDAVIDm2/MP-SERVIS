import { Repository } from 'typeorm';
import { Order } from '../orders/order.entity';
import { Organization } from '../organizations/organization.entity';
import { OrganizationSubscription } from '../organizations/organization-subscription.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { SubscriptionPlanKey, SubscriptionPlanLimits } from './plan-definitions';
export type SubscriptionLimitsSnake = {
    max_active_staff: number | null;
    max_confirmed_orders_per_month: number | null;
    max_order_media_attachments: number | null;
    max_chat_images_per_message: number | null;
};
export declare function subscriptionLimitsToSnake(l: SubscriptionPlanLimits): SubscriptionLimitsSnake;
export declare class SubscriptionQuotaService {
    private readonly orderRepo;
    private readonly orgRepo;
    private readonly subRepo;
    private readonly staffRepo;
    constructor(orderRepo: Repository<Order>, orgRepo: Repository<Organization>, subRepo: Repository<OrganizationSubscription>, staffRepo: Repository<StaffMember>);
    getPlanKeyForOrganization(organizationId: string): Promise<SubscriptionPlanKey>;
    getLimitsForOrganization(organizationId: string): Promise<SubscriptionPlanLimits>;
    isSoloPlan(organizationId: string): Promise<boolean>;
    isSubscriptionRecordActive(sub: OrganizationSubscription | null): boolean;
    private getSubscription;
    assertSubscriptionAllowsWrites(organizationId: string): Promise<void>;
    getBillingMonthUtcRange(organizationId: string, now?: Date): Promise<{
        startUtc: Date;
        endExclusiveUtc: Date;
    }>;
    countConfirmedOrdersInBillingMonth(organizationId: string, now?: Date): Promise<number>;
    assertCanConsumeConfirmedOrderSlot(organizationId: string): Promise<void>;
    countActiveStaff(organizationId: string): Promise<number>;
    assertCanAddOrActivateStaff(organizationId: string, excludeStaffId?: string | null): Promise<void>;
    getSubscriptionUsageSummary(organizationId: string): Promise<{
        plan_key: SubscriptionPlanKey;
        limits: SubscriptionLimitsSnake;
        plan_limits: SubscriptionLimitsSnake;
        limits_override: Record<string, unknown> | null;
        subscription_active: boolean;
        subscription_status: string | null;
        subscription_end_date: string | null;
        confirmed_orders_this_month: number;
        active_staff: number;
    }>;
}
