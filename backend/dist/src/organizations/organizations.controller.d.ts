import { Response } from 'express';
import { User } from '../users/user.entity';
import { OrganizationsService } from './organizations.service';
export declare class OrganizationsController {
    private org;
    constructor(org: OrganizationsService);
    private assertActiveOrganizationAccess;
    listSubscriptionPlans(): {
        items: {
            plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
            limits: import("../subscriptions/plan-definitions").SubscriptionPlanLimits;
        }[];
    };
    applyPlanWithStaff(id: string, req: {
        user: User;
    }, body: {
        plan_key?: string;
        keep_active_staff_ids?: string[];
    }): Promise<{
        plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
        limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
        plan_limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
        limits_override: Record<string, unknown> | null;
        subscription_active: boolean;
        subscription_status: string | null;
        subscription_end_date: string | null;
        confirmed_orders_this_month: number;
        active_staff: number;
    }>;
    get(id: string, req: {
        user: User;
    }): Promise<{
        name: string;
        address: string;
        phone: string;
        working_hours: string;
        timezone: any;
        photo_urls: string[];
        latitude: any;
        longitude: any;
        business_kind: any;
        scheduling_mode: any;
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
    addPhoto(id: string, req: {
        user: User;
    }, file: Express.Multer.File): Promise<{
        url: string;
    }>;
    getPhotoFile(id: string, filename: string, req: {
        user: User;
    }, res: Response): Promise<void | Response<any, Record<string, any>>>;
    update(id: string, req: {
        user: User;
    }, body: {
        name?: string;
        address?: string;
        phone?: string;
        working_hours?: string;
        timezone?: string;
        latitude?: number | null;
        longitude?: number | null;
        business_kind?: string;
        scheduling_mode?: string;
    }): Promise<{
        name: string;
        address: string;
        phone: string;
        working_hours: string;
        timezone: any;
        latitude: any;
        longitude: any;
        business_kind: any;
        scheduling_mode: any;
    }>;
    getStaff(id: string, req: {
        user: User;
    }): Promise<{
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
            schedule: any;
        }[];
    }>;
    addMeAsMaster(id: string, req: {
        user: User;
    }): Promise<{
        id: string;
        user_id: any;
        name: string;
        phone: string | null;
        email: any;
        role: string;
        is_active: boolean;
        invited_at: any;
        skills: any;
        schedule: any;
    }>;
    inviteStaff(id: string, req: {
        user: User;
    }, body: {
        name?: string;
        phone?: string;
        email?: string;
        role: string;
        message?: string;
        expires_in_days?: number;
    }): Promise<{
        id: string;
        organization_id: string;
        invited_by_user_id: string;
        accepted_by_user_id: string | null;
        staff_member_id: string | null;
        role: string;
        invited_name: string | null;
        invited_email: string | null;
        invited_phone: string | null;
        status: import("./organization-invitation.entity").OrganizationInvitationStatus;
        message: string | null;
        expires_at: string | null;
        responded_at: string | null;
        created_at: string;
        updated_at: string;
        organization_name: string;
    }>;
    updateStaff(id: string, staffId: string, req: {
        user: User;
    }, body: Record<string, unknown>): Promise<{
        id: string;
        user_id: any;
        name: string;
        phone: string | null;
        email: any;
        role: string;
        is_active: boolean;
        invited_at: any;
        skills: any;
        schedule: any;
    } | null>;
    getInvitations(id: string, req: {
        user: User;
    }, status?: 'pending' | 'accepted' | 'declined' | 'cancelled' | 'expired'): Promise<{
        items: {
            id: string;
            organization_id: string;
            invited_by_user_id: string;
            accepted_by_user_id: string | null;
            staff_member_id: string | null;
            role: string;
            invited_name: string | null;
            invited_email: string | null;
            invited_phone: string | null;
            status: import("./organization-invitation.entity").OrganizationInvitationStatus;
            message: string | null;
            expires_at: string | null;
            responded_at: string | null;
            created_at: string;
            updated_at: string;
            organization_name: string;
        }[];
    }>;
    cancelInvitation(id: string, invitationId: string, req: {
        user: User;
    }): Promise<{
        id: string;
        organization_id: string;
        invited_by_user_id: string;
        accepted_by_user_id: string | null;
        staff_member_id: string | null;
        role: string;
        invited_name: string | null;
        invited_email: string | null;
        invited_phone: string | null;
        status: import("./organization-invitation.entity").OrganizationInvitationStatus;
        message: string | null;
        expires_at: string | null;
        responded_at: string | null;
        created_at: string;
        updated_at: string;
        organization_name: string;
    }>;
    getSettings(id: string, req: {
        user: User;
    }): Promise<{
        data: Record<string, unknown>;
    }>;
    updateSettings(id: string, req: {
        user: User;
    }, body: Record<string, unknown>): Promise<{
        data: Record<string, unknown>;
    }>;
}
