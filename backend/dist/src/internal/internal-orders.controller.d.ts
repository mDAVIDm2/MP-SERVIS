import { OrdersService } from '../orders/orders.service';
export declare class InternalOrdersController {
    private readonly orders;
    constructor(orders: OrdersService);
    list(limit?: string, offset?: string): Promise<{
        items: Record<string, unknown>[];
        total: number;
    }>;
}
