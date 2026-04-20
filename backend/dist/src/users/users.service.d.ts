import { DataSource, Repository } from 'typeorm';
import { User, BusinessRole, AccountRealm } from './user.entity';
import { ClientNotificationPreferences } from '../notifications/client-notification-preferences';
import { UserOrganizationMembership } from './user-organization-membership.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { OrganizationsService } from '../organizations/organizations.service';
import { OrganizationInvitation } from '../organizations/organization-invitation.entity';
import { Chat } from '../chats/chat.entity';
import { Order } from '../orders/order.entity';
export interface OrganizationSummaryDto {
    id: string;
    name: string;
    role: string;
    plan_key?: string;
}
export declare class UsersService {
    private repo;
    private membershipRepo;
    private staffRepo;
    private invitationRepo;
    private chatRepo;
    private orderRepo;
    private orgService;
    private readonly dataSource;
    constructor(repo: Repository<User>, membershipRepo: Repository<UserOrganizationMembership>, staffRepo: Repository<StaffMember>, invitationRepo: Repository<OrganizationInvitation>, chatRepo: Repository<Chat>, orderRepo: Repository<Order>, orgService: OrganizationsService, dataSource: DataSource);
    canStaffFetchClientAvatar(viewer: User, avatarOwnerUserId: string): Promise<boolean>;
    findById(id: string): Promise<User | null>;
    findAll(): Promise<User[]>;
    profileResponse(user: User, organizations?: OrganizationSummaryDto[]): {
        id: string;
        email: string | null;
        email_verified_at: string | null;
        phone: string | null;
        phone_verified_at: string | null;
        name: string;
        avatar_url: string | null;
        account_realm: AccountRealm;
        role: BusinessRole;
        organization_id: string | null;
        organizations: OrganizationSummaryDto[];
    };
    appendStaffCapabilities(user: User, payload: Record<string, unknown>): Promise<void>;
    saveUserAvatar(userId: string, file: Express.Multer.File): Promise<User>;
    getUserAvatarFilePath(userId: string, filename: string): string | null;
    ensureMembership(userId: string, organizationId: string | null | undefined, role: string): Promise<void>;
    getOrganizationSummariesForUser(user: User): Promise<OrganizationSummaryDto[]>;
    canAccessOrganization(userId: string, organizationId: string): Promise<boolean>;
    switchActiveOrganization(userId: string, organizationId: string): Promise<User>;
    private canCreateAdditionalOrganization;
    createOwnedOrganization(userId: string, dto: {
        name: string;
        address?: string;
        phone?: string;
        plan_key?: string;
    }): Promise<{
        user: User;
        summaries: OrganizationSummaryDto[];
    }>;
    getNotificationPreferences(userId: string): Promise<ClientNotificationPreferences>;
    updateNotificationPreferences(userId: string, patch: Partial<ClientNotificationPreferences>): Promise<ClientNotificationPreferences>;
    private assertClientRealm;
    getClientAppState(userId: string): Promise<{
        payload: Record<string, unknown> | null;
        updated_at: string | null;
    }>;
    putClientAppState(userId: string, payload: Record<string, unknown>): Promise<{
        ok: true;
        updated_at: string;
    }>;
    findIdByNormalizedPhone(phoneDigits: string, realm?: AccountRealm): Promise<string | null>;
    clientPhoneMatchKey(raw: string): string;
    mapClientAvatarUrlsByPhoneKeys(keys: Set<string>): Promise<Map<string, string | null>>;
    private normalizePhoneLoose;
    private normalizeEmail;
    private invitationToDto;
    findUserIdForInviteContact(emailNorm: string | null, phoneNorm: string | null): Promise<string | null>;
    getIncomingInvitations(userId: string): Promise<{
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
    acceptInvitation(userId: string, invitationId: string, opts?: {
        set_active_organization?: boolean;
    }): Promise<{
        user: User;
        summaries: OrganizationSummaryDto[];
    }>;
    declineInvitation(userId: string, invitationId: string): Promise<{
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
    updateOwnProfile(userId: string, dto: {
        name?: string;
        phone?: string;
    }): Promise<User>;
    private normalizePhoneForOrdersCompare;
    getOrderCarsSummaryForInternalUser(phone: string | null): Promise<Array<{
        car_id: string;
        car_info: string;
        vin: string | null;
        license_plate: string | null;
        car_photo_url: string | null;
        orders_count: number;
        last_order_at: string;
    }>>;
    getInternalUserDetail(userId: string): Promise<{
        id: string;
        phone: string | null;
        email: string | null;
        name: string;
        role: BusinessRole;
        role_label: string;
        account_type: string;
        account_realm: AccountRealm;
        organization_id: string | null;
        organization_name: string | null;
        avatar_url: string | null;
        cars_from_orders: {
            car_id: string;
            car_info: string;
            vin: string | null;
            license_plate: string | null;
            car_photo_url: string | null;
            orders_count: number;
            last_order_at: string;
        }[];
    }>;
    updateInternalUserDisplayName(userId: string, name: string): Promise<boolean>;
    clearUserAvatar(userId: string): Promise<boolean>;
    deleteOwnAccount(userId: string): Promise<void>;
}
