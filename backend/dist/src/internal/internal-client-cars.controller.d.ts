import { Response } from 'express';
import { OrdersService } from '../orders/orders.service';
import { ClientCarsService } from '../users/client-cars.service';
import { UsersService } from '../users/users.service';
export declare class InternalClientCarsController {
    private readonly orders;
    private readonly clientCars;
    private readonly users;
    constructor(orders: OrdersService, clientCars: ClientCarsService, users: UsersService);
    list(): Promise<{
        items: {
            client_phone: string;
            car_id: string;
            car_info: string;
            client_name: string | null;
            orders_count: number;
            last_order_at: string;
            car_photo_url: string | null;
        }[];
    }>;
    moderateClear(body: {
        client_phone: string;
        car_id: string;
        vin?: boolean;
        license_plate?: boolean;
        car_info?: boolean;
        car_photo_url?: boolean;
    }): Promise<{
        updated: number;
        ok: boolean;
    }>;
    hideFromClient(body: {
        client_phone?: string;
        car_id?: string;
    }): Promise<{
        ok: boolean;
    }>;
    restoreForClient(body: {
        client_phone?: string;
        car_id?: string;
    }): Promise<{
        ok: boolean;
    }>;
    hardDelete(body: {
        client_phone?: string;
        car_id?: string;
        confirm?: string;
    }): Promise<{
        deletedOrders: number;
        deletedItems: number;
        deletedPhotos: number;
        ok: boolean;
    }>;
    history(clientPhone: string, carId: string): Promise<{
        items: Record<string, unknown>[];
    }>;
    carPhotoFile(carId: string, filename: string, res: Response): Promise<void>;
}
