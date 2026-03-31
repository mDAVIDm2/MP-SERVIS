import { OrganizationsService } from '../organizations/organizations.service';
export declare class InternalSubscriptionsController {
    private readonly org;
    constructor(org: OrganizationsService);
    list(): Promise<{
        items: {
            id: string;
            organization_id: string;
            organization_name: any;
            start_date: string;
            end_date: string;
            is_active: boolean;
            status: string;
            plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
            limits_override: Record<string, unknown> | null;
        }[];
    }>;
    subscriptionPlans(): {
        items: {
            plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
            limits: import("../subscriptions/plan-definitions").SubscriptionPlanLimits;
        }[];
    };
    applyPlanWithStaff(organizationId: string, body: {
        plan_key?: string;
        keep_active_staff_ids?: string[];
    }): Promise<{
        ok: boolean;
        subscription_usage: {
            plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
            limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
            plan_limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
            limits_override: Record<string, unknown> | null;
            subscription_active: boolean;
            subscription_status: string | null;
            subscription_end_date: string | null;
            confirmed_orders_this_month: number;
            active_staff: number;
        };
    }>;
    update(organizationId: string, body: {
        is_active?: boolean;
        status?: string;
        plan_key?: string;
        limits_override?: unknown | null;
    }): Promise<{
        ok: boolean;
        message: string;
        subscription?: undefined;
        subscription_usage?: undefined;
    } | {
        ok: boolean;
        subscription: {
            id: string;
            organization_id: string;
            is_active: boolean;
            status: string;
            plan_key: any;
            limits_override: Record<string, unknown> | null;
        };
        subscription_usage: {
            plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
            limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
            plan_limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
            limits_override: Record<string, unknown> | null;
            subscription_active: boolean;
            subscription_status: string | null;
            subscription_end_date: string | null;
            confirmed_orders_this_month: number;
            active_staff: number;
        };
        message?: undefined;
    }>;
}
