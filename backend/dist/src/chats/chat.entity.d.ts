import { ChatMessage } from './chat-message.entity';
import { Order } from '../orders/order.entity';
export declare class Chat {
    id: string;
    lastOrderId: string | null;
    order: Order | null;
    organizationId: string | null;
    clientPhone: string | null;
    clientLastReadAt: Date | null;
    organizationLastReadAt: Date | null;
    internalSupportLastReadAt: Date | null;
    messages: ChatMessage[];
}
