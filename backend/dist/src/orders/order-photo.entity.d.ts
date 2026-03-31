import { Order } from './order.entity';
export declare class OrderPhoto {
    id: string;
    orderId: string;
    order: Order;
    filePath: string;
    createdAt: Date;
}
