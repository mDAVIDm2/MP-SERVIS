import { DataSource, Repository } from 'typeorm';
import { User, BusinessRole } from './user.entity';
import { ClientNotificationPreferences } from '../notifications/client-notification-preferences';
import { UserOrganizationMembership } from './user-organization-membership.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { OrganizationsService } from '../organizations/organizations.service';
import { OrganizationInvitation } from '../organizations/organization-invitation.entity';
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
    private orgService;
    private readonly dataSource;
    constructor(repo: Repository<User>, membershipRepo: Repository<UserOrganizationMembership>, staffRepo: Repository<StaffMember>, invitationRepo: Repository<OrganizationInvitation>, orgService: OrganizationsService, dataSource: DataSource);
    findById(id: string): Promise<User | null>;
    findAll(): Promise<User[]>;
    profileResponse(user: User, organizations?: OrganizationSummaryDto[]): {
        id: string;
        email: string | null;
        email_verified_at: string | null;
        phone: string | null;
        phone_verified_at: string | null;
        name: string;
        role: BusinessRole;
        organization_id: string | null;
        organizations: OrganizationSummaryDto[];
    };
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
    findIdByNormalizedPhone(phoneDigits: string): Promise<string | null>;
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
    deleteOwnAccount(userId: string): Promise<void>;
}
