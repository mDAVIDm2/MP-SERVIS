import { UsersService } from '../users/users.service';
import { BusinessRole } from '../users/user.entity';
export declare class InternalUsersController {
    private readonly users;
    constructor(users: UsersService);
    list(): Promise<{
        items: {
            id: string;
            phone: string | null;
            name: string;
            role: BusinessRole;
            role_label: string;
            account_type: string;
            organization_id: string | null;
            organization_name: any;
        }[];
    }>;
}
