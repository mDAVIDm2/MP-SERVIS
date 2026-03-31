import { Organization } from '../organizations/organization.entity';
export type BusinessRole = 'owner' | 'admin' | 'master' | 'solo';
export declare class User {
    id: string;
    phone: string | null;
    phoneVerifiedAt: Date | null;
    email: string | null;
    emailVerifiedAt: Date | null;
    name: string;
    role: BusinessRole;
    organizationId: string | null;
    organization: Organization | null;
    notificationPreferences: Record<string, unknown> | null;
}
