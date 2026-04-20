import { DataSource, Repository } from 'typeorm';
import { Organization } from './organization.entity';
import { OrganizationSubscription } from './organization-subscription.entity';
import { StaffMember } from './staff-member.entity';
import { OrganizationSettings } from './organization-settings.entity';
import { MasterSchedule } from './master-schedule.entity';
import { ServiceCatalogItem } from '../reference/service-catalog-item.entity';
import { OrganizationInvitation, OrganizationInvitationStatus } from './organization-invitation.entity';
import { SubscriptionQuotaService } from '../subscriptions/subscription-quota.service';
import { UsersService } from '../users/users.service';
import { User } from '../users/user.entity';
import { UserOrganizationMembership } from '../users/user-organization-membership.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { TransactionalMailService } from '../mail/transactional-mail.service';
import { SubscriptionPlanKey } from '../subscriptions/plan-definitions';
export interface CurrentUserForMaster {
    id: string;
    name: string;
    phone: string | null;
    organizationId: string | null;
    role: string;
}
export interface ScheduleSlotDto {
    day_of_week: number;
    start_time: string;
    end_time: string;
    is_working_day: boolean;
}
export declare class OrganizationsService {
    private orgRepo;
    private subRepo;
    private staffRepo;
    private settingsRepo;
    private invitationRepo;
    private scheduleRepo;
    private catalogItemRepo;
    private userRepo;
    private userOrgMembershipRepo;
    private readonly subscriptionQuota;
    private readonly dataSource;
    private readonly usersService;
    private readonly notificationsService;
    private readonly mail;
    private readonly log;
    constructor(orgRepo: Repository<Organization>, subRepo: Repository<OrganizationSubscription>, staffRepo: Repository<StaffMember>, settingsRepo: Repository<OrganizationSettings>, invitationRepo: Repository<OrganizationInvitation>, scheduleRepo: Repository<MasterSchedule>, catalogItemRepo: Repository<ServiceCatalogItem>, userRepo: Repository<User>, userOrgMembershipRepo: Repository<UserOrganizationMembership>, subscriptionQuota: SubscriptionQuotaService, dataSource: DataSource, usersService: UsersService, notificationsService: NotificationsService, mail: TransactionalMailService);
    listSubscriptionPlansPublic(): {
        items: {
            plan_key: SubscriptionPlanKey;
            limits: import("../subscriptions/plan-definitions").SubscriptionPlanLimits;
        }[];
    };
    getPlanKeysForOrganizations(orgIds: string[]): Promise<Record<string, SubscriptionPlanKey>>;
    businessKindLabelRu(kind: string): string;
    findAll(): Promise<Organization[]>;
    findAllSubscriptions(): Promise<{
        id: string;
        organization_id: string;
        organization_name: any;
        start_date: string;
        end_date: string;
        is_active: boolean;
        status: string;
        plan_key: SubscriptionPlanKey;
        limits_override: Record<string, unknown> | null;
    }[]>;
    private parseLimitsOverridePatch;
    private mergeLimitsOverridePatch;
    updateSubscription(organizationId: string, dto: {
        is_active?: boolean;
        status?: string;
        plan_key?: string;
        limits_override?: unknown;
    }): Promise<OrganizationSubscription | null>;
    applySubscriptionPlanWithActiveStaff(organizationId: string, dto: {
        plan_key: string;
        keep_active_staff_ids: string[];
    }): Promise<{
        plan_key: SubscriptionPlanKey;
        limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
        plan_limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
        limits_override: Record<string, unknown> | null;
        subscription_active: boolean;
        subscription_status: string | null;
        subscription_end_date: string | null;
        confirmed_orders_this_month: number;
        active_staff: number;
    }>;
    getSubscriptionUsageSummary(organizationId: string): Promise<{
        plan_key: SubscriptionPlanKey;
        limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
        plan_limits: import("../subscriptions/subscription-quota.service").SubscriptionLimitsSnake;
        limits_override: Record<string, unknown> | null;
        subscription_active: boolean;
        subscription_status: string | null;
        subscription_end_date: string | null;
        confirmed_orders_this_month: number;
        active_staff: number;
    }>;
    isSubscriptionActive(organizationId: string): Promise<boolean>;
    findOne(id: string): Promise<Organization | null>;
    createOrganizationWithDefaults(dto: {
        name: string;
        address?: string;
        phone?: string;
        plan_key?: string;
    }): Promise<Organization>;
    update(id: string, dto: {
        name?: string;
        address?: string;
        phone?: string;
        working_hours?: string;
        timezone?: string;
        latitude?: number | null;
        longitude?: number | null;
        business_kind?: string;
        scheduling_mode?: string;
    }): Promise<Organization | null>;
    getStaff(orgId: string): Promise<{
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
    ensureCallerCanManageOrganizationStaff(caller: User): void;
    private assertCanManageOrganizationStaff;
    getStaffForCaller(orgId: string, caller: User): Promise<{
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
    promoteSoloToOwnerIfNeeded(orgId: string): Promise<void>;
    private countActiveMasters;
    private isSoloSingleMasterOrg;
    private parseHHMMToMinutes;
    private formatMinutesAsHHMM;
    private syncOrgSlotsFromMasterSchedule;
    private syncSoloMasterTimesFromOrgSlots;
    private ensureSoloStaffMember;
    private promoteSoloToOwner;
    addCurrentUserAsMaster(orgId: string, user: CurrentUserForMaster): Promise<{
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
    }>;
    private _staffToItem;
    private normalizePhoneLoose;
    private normalizeEmail;
    private invitationToItem;
    private dispatchInvitationSideEffects;
    createInvitation(orgId: string, caller: User, dto: {
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
        status: OrganizationInvitationStatus;
        message: string | null;
        expires_at: string | null;
        responded_at: string | null;
        created_at: string;
        updated_at: string;
        organization_name: string;
    }>;
    listInvitations(orgId: string, caller: User, status?: OrganizationInvitationStatus): Promise<{
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
            status: OrganizationInvitationStatus;
            message: string | null;
            expires_at: string | null;
            responded_at: string | null;
            created_at: string;
            updated_at: string;
            organization_name: string;
        }[];
    }>;
    cancelInvitation(orgId: string, invitationId: string, caller: User): Promise<{
        id: string;
        organization_id: string;
        invited_by_user_id: string;
        accepted_by_user_id: string | null;
        staff_member_id: string | null;
        role: string;
        invited_name: string | null;
        invited_email: string | null;
        invited_phone: string | null;
        status: OrganizationInvitationStatus;
        message: string | null;
        expires_at: string | null;
        responded_at: string | null;
        created_at: string;
        updated_at: string;
        organization_name: string;
    }>;
    inviteStaff(orgId: string, dto: {
        name: string;
        phone?: string;
        email?: string;
        role: string;
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
        can_see_chats: boolean;
        can_write_chats: boolean;
        can_manage_org_settings: boolean;
        schedule: any;
    }>;
    updateStaffMember(orgId: string, staffId: string, dto: Record<string, unknown>, caller: User): Promise<{
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
    } | null>;
    getSettings(orgId: string): Promise<Record<string, unknown>>;
    updateSettings(orgId: string, data: Record<string, unknown>): Promise<Record<string, unknown>>;
    private assertServicesAllowedForOrganizationKind;
    addPhoto(orgId: string, file: Express.Multer.File): Promise<{
        url: string;
    } | null>;
    removePhoto(orgId: string, photoUrlOrInput: string): Promise<boolean>;
    getPhotoPath(orgId: string, filename: string): Promise<string | null>;
    getPhotoUrls(org: Organization): string[];
    clearAllOrganizationPhotos(orgId: string): Promise<boolean>;
}
