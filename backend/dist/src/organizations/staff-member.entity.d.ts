import { Organization } from './organization.entity';
import { MasterSchedule } from './master-schedule.entity';
export declare class StaffMember {
    id: string;
    userId: string | null;
    name: string;
    phone: string | null;
    email: string | null;
    role: string;
    isActive: boolean;
    invitedAt: Date | null;
    organizationId: string;
    skills: string[];
    canSeeChats: boolean;
    canWriteChats: boolean;
    canManageOrgSettings: boolean;
    organization: Organization;
    schedule: MasterSchedule[];
}
