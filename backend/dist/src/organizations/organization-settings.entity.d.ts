import { Organization } from './organization.entity';
export declare class OrganizationSettings {
    id: string;
    organizationId: string;
    organization: Organization;
    data: Record<string, unknown>;
}
