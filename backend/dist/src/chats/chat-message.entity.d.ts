import { Chat } from './chat.entity';
export declare class ChatMessage {
    id: string;
    chatId: string;
    chat: Chat;
    text: string;
    isFromClient: boolean;
    isFromSupportOperator: boolean;
    supportChannel: string | null;
    isSystem: boolean;
    at: Date;
    approvalItems: unknown;
    approvalStatus: string | null;
    proposedDateTime: Date | null;
    orderId: string | null;
    messageType: string | null;
    orderItemsSnapshot: unknown;
}
