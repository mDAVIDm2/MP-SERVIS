import { StaffMember } from './staff-member.entity';
import { OrganizationSettings } from './organization-settings.entity';
export declare class Organization {
    id: string;
    name: string;
    address: string;
    phone: string;
    workingHours: string;
    timezone: string;
    latitude: number | null;
    longitude: number | null;
    photoUrls: string[] | null;
    businessKind: string;
    schedulingMode: string;
    staff: StaffMember[];
    settings: OrganizationSettings;
}
