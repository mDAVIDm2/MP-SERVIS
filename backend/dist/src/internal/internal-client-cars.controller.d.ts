import { OrdersService } from '../orders/orders.service';
export declare class InternalClientCarsController {
    private readonly orders;
    constructor(orders: OrdersService);
    list(): Promise<{
        items: {
            client_phone: string;
            car_id: string;
            car_info: string;
            client_name: string | null;
            orders_count: number;
            last_order_at: string;
        }[];
    }>;
    history(clientPhone: string, carId: string): Promise<{
        items: Record<string, unknown>[];
    }>;
}
