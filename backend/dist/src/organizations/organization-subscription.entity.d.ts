import { Organization } from './organization.entity';
export declare class OrganizationSubscription {
    id: string;
    organizationId: string;
    organization: Organization;
    startDate: Date;
    endDate: Date;
    isActive: boolean;
    status: string;
    planKey: string;
    limitsOverride: Record<string, unknown> | null;
}
