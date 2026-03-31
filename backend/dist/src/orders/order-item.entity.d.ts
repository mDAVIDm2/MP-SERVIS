import { Order } from './order.entity';
import { StaffMember } from '../organizations/staff-member.entity';
export declare class OrderItem {
    id: string;
    name: string;
    priceKopecks: number | null;
    estimatedMinutes: number;
    isCompleted: boolean;
    isAdditional: boolean;
    orderId: string;
    masterId: string | null;
    order: Order;
    master: StaffMember | null;
}
