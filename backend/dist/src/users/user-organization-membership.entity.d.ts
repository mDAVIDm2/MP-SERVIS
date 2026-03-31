import { User } from './user.entity';
import { Organization } from '../organizations/organization.entity';
export declare class UserOrganizationMembership {
    id: string;
    userId: string;
    user: User;
    organizationId: string;
    organization: Organization;
    role: string;
}
