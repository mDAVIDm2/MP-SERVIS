import { User } from './user.entity';
import { UsersService } from './users.service';
import { ClientNotificationPreferences } from '../notifications/client-notification-preferences';
import { OrganizationsService } from '../organizations/organizations.service';
export declare class UsersController {
    private users;
    private organizations;
    constructor(users: UsersService, organizations: OrganizationsService);
    listSubscriptionPlans(): {
        items: {
            plan_key: import("../subscriptions/plan-definitions").SubscriptionPlanKey;
            limits: import("../subscriptions/plan-definitions").SubscriptionPlanLimits;
        }[];
    };
    getProfile(req: {
        user: User;
    }): Promise<{
        id: string;
        email: string | null;
        email_verified_at: string | null;
        phone: string | null;
        phone_verified_at: string | null;
        name: string;
        role: import("./user.entity").BusinessRole;
        organization_id: string | null;
        organizations: import("./users.service").OrganizationSummaryDto[];
    }>;
    patchProfile(req: {
        user: User;
    }, body: {
        name?: string;
        phone?: string;
    }): Promise<{
        id: string;
        email: string | null;
        email_verified_at: string | null;
        phone: string | null;
        phone_verified_at: string | null;
        name: string;
        role: import("./user.entity").BusinessRole;
        organization_id: string | null;
        organizations: import("./users.service").OrganizationSummaryDto[];
    }>;
    deleteAccount(req: {
        user: User;
    }, app?: string): Promise<{
        ok: boolean;
    }>;
    switchOrganization(req: {
        user: User;
    }, body: {
        organization_id?: string;
    }): Promise<{
        id: string;
        email: string | null;
        email_verified_at: string | null;
        phone: string | null;
        phone_verified_at: string | null;
        name: string;
        role: import("./user.entity").BusinessRole;
        organization_id: string | null;
        organizations: import("./users.service").OrganizationSummaryDto[];
    }>;
    getNotificationPreferences(req: {
        user: User;
    }): Promise<ClientNotificationPreferences>;
    patchNotificationPreferences(req: {
        user: User;
    }, body: Partial<ClientNotificationPreferences>): Promise<ClientNotificationPreferences>;
    createOrganization(req: {
        user: User;
    }, body: {
        name?: string;
        address?: string;
        phone?: string;
        plan_key?: string;
    }): Promise<{
        id: string;
        email: string | null;
        email_verified_at: string | null;
        phone: string | null;
        phone_verified_at: string | null;
        name: string;
        role: import("./user.entity").BusinessRole;
        organization_id: string | null;
        organizations: import("./users.service").OrganizationSummaryDto[];
    }>;
    incomingInvitations(req: {
        user: User;
    }): Promise<{
        items: {
            id: string;
            organization_id: string;
            organization_name: string;
            role: string;
            invited_name: string | null;
            invited_email: string | null;
            invited_phone: string | null;
            message: string | null;
            status: import("../organizations/organization-invitation.entity").OrganizationInvitationStatus;
            created_at: string;
            expires_at: string | null;
            responded_at: string | null;
        }[];
    }>;
    acceptInvitation(invitationId: string, req: {
        user: User;
    }, body: {
        set_active_organization?: boolean;
    }): Promise<{
        id: string;
        email: string | null;
        email_verified_at: string | null;
        phone: string | null;
        phone_verified_at: string | null;
        name: string;
        role: import("./user.entity").BusinessRole;
        organization_id: string | null;
        organizations: import("./users.service").OrganizationSummaryDto[];
    }>;
    declineInvitation(invitationId: string, req: {
        user: User;
    }): Promise<{
        id: string;
        organization_id: string;
        organization_name: string;
        role: string;
        invited_name: string | null;
        invited_email: string | null;
        invited_phone: string | null;
        message: string | null;
        status: import("../organizations/organization-invitation.entity").OrganizationInvitationStatus;
        created_at: string;
        expires_at: string | null;
        responded_at: string | null;
    }>;
}
