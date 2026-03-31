import { Organization } from './organization.entity';
import { User } from '../users/user.entity';
import { StaffMember } from './staff-member.entity';
export type OrganizationInvitationStatus = 'pending' | 'accepted' | 'declined' | 'cancelled' | 'expired';
export declare class OrganizationInvitation {
    id: string;
    organizationId: string;
    organization: Organization;
    invitedByUserId: string;
    invitedByUser: User;
    acceptedByUserId: string | null;
    acceptedByUser: User | null;
    staffMemberId: string | null;
    staffMember: StaffMember | null;
    role: string;
    invitedName: string | null;
    invitedEmail: string | null;
    invitedEmailNorm: string | null;
    invitedPhone: string | null;
    invitedPhoneNorm: string | null;
    status: OrganizationInvitationStatus;
    message: string | null;
    expiresAt: Date | null;
    respondedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
}
