import { OrganizationsService } from '../organizations/organizations.service';
export declare class InternalOrganizationsController {
    private readonly org;
    constructor(org: OrganizationsService);
    list(): Promise<{
        items: {
            subscription: {
                is_active: boolean;
                status: string;
                end_date: string;
                plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
                limits_override: any;
            } | null;
            id: string;
            name: string;
            address: string;
            phone: string;
            working_hours: string;
            timezone: string;
            latitude: number | null;
            longitude: number | null;
            photo_urls: string[] | null;
        }[];
    }>;
    getOne(id: string): Promise<{
        staff: {
            id: string;
            user_id: any;
            name: string;
            phone: string | null;
            email: any;
            role: string;
            is_active: boolean;
            invited_at: any;
            skills: any;
            can_see_chats: boolean;
            can_write_chats: boolean;
            can_manage_org_settings: boolean;
            schedule: any;
        }[];
        subscription: {
            id: string;
            is_active: boolean;
            status: string;
            start_date: string;
            end_date: string;
            plan_key: any;
            limits_override: any;
        } | null;
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
        } | null;
        id: string;
        name: string;
        address: string;
        phone: string;
        working_hours: string;
        timezone: string;
        latitude: number | null;
        longitude: number | null;
        photo_urls: string[] | null;
    }>;
    deletePhotos(id: string, all?: string, url?: string): Promise<{
        ok: boolean;
    }>;
    update(id: string, body: {
        name?: string;
        address?: string;
        phone?: string;
        working_hours?: string;
        timezone?: string;
        latitude?: number | null;
        longitude?: number | null;
    }): Promise<{
        id: string;
        name: string;
        address: string;
        phone: string;
        working_hours: string;
        timezone: string;
        latitude: number | null;
        longitude: number | null;
        photo_urls: string[] | null;
    } | null>;
    getStaff(id: string): Promise<{
        items: {
            id: string;
            user_id: any;
            name: string;
            phone: string | null;
            email: any;
            role: string;
            is_active: boolean;
            invited_at: any;
            skills: any;
            can_see_chats: boolean;
            can_write_chats: boolean;
            can_manage_org_settings: boolean;
            schedule: any;
        }[];
    }>;
}
