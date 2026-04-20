import { Response } from 'express';
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
            avatar_url: string | null;
        }[];
    }>;
    avatarFile(userId: string, filename: string, res: Response): Promise<void>;
    getOne(id: string): Promise<{
        id: string;
        phone: string | null;
        email: string | null;
        name: string;
        role: BusinessRole;
        role_label: string;
        account_type: string;
        account_realm: import("../users/user.entity").AccountRealm;
        organization_id: string | null;
        organization_name: string | null;
        avatar_url: string | null;
        cars_from_orders: {
            car_id: string;
            car_info: string;
            vin: string | null;
            license_plate: string | null;
            car_photo_url: string | null;
            orders_count: number;
            last_order_at: string;
        }[];
    }>;
    patch(id: string, body: {
        name?: string;
        clear_avatar?: boolean;
    }): Promise<{
        id: string;
        phone: string | null;
        email: string | null;
        name: string;
        role: BusinessRole;
        role_label: string;
        account_type: string;
        account_realm: import("../users/user.entity").AccountRealm;
        organization_id: string | null;
        organization_name: string | null;
        avatar_url: string | null;
        cars_from_orders: {
            car_id: string;
            car_info: string;
            vin: string | null;
            license_plate: string | null;
            car_photo_url: string | null;
            orders_count: number;
            last_order_at: string;
        }[];
    }>;
}
