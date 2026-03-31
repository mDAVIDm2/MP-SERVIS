import { Repository } from 'typeorm';
import { OrganizationInvitation } from './organization-invitation.entity';
export declare class OrganizationInvitationsScheduler {
    private readonly invitationRepo;
    private readonly log;
    constructor(invitationRepo: Repository<OrganizationInvitation>);
    expirePendingInvitations(): Promise<void>;
}
