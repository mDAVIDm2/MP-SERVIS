import { Organization } from '../organizations/organization.entity';
export declare class ServiceCatalogSuggestion {
    id: string;
    organizationId: string;
    organization: Organization;
    requestedName: string;
    categoryHint: string | null;
    note: string | null;
    status: string;
    reviewedAt: Date | null;
    reviewNote: string | null;
    createdAt: Date;
}
