import { ChatsService } from '../chats/chats.service';
export declare class InternalSupportChatsController {
    private readonly chats;
    constructor(chats: ChatsService);
    list(): Promise<{
        items: {
            id: string;
            order_id: any;
            order_number: any;
            order_status: any;
            organization_id: string;
            organization_name: any;
            organization_kind: "sto" | "car_wash" | "detailing" | "car_audio" | "tire_service" | "body_shop" | "glass" | "tuning" | "ev_service" | "other" | null;
            business_kind: "sto" | "car_wash" | "detailing" | "car_audio" | "tire_service" | "body_shop" | "glass" | "tuning" | "ev_service" | "other" | null;
            car_info: any;
            is_support_chat: boolean;
            primary_requester_channel: string | null;
            car_id: any;
            last_message_order_id: string;
            client_name: any;
            client_phone: string;
            last_message_text: string;
            last_message_at: string;
            last_message_from_client: boolean;
            unread_count: number;
        }[];
    }>;
    messages(id: string): Promise<{
        items: {
            id: string;
            text: string;
            at: string;
            is_from_client: boolean;
            is_system: boolean;
            is_from_support_operator: boolean;
            support_channel: any;
            order_id: string | null;
            message_type: string | null;
            order_items_snapshot: {} | null;
            approval_items: {} | null;
            approval_status: string | null;
            proposed_date_time: string | null;
            attachments: {
                id: string;
                url: string;
                mime_type: string;
                width: number | null;
                height: number | null;
                size_bytes: number;
            }[];
        }[];
    }>;
    send(id: string, body: {
        text?: string;
    }): Promise<{
        id: string;
        text: string;
        is_from_client: boolean;
        is_system: boolean;
        is_from_support_operator: boolean;
        support_channel: null;
        message_type: string;
        at: string;
        approval_items: null;
        approval_status: null;
        proposed_date_time: null;
        order_id: null;
    }>;
    markRead(id: string): Promise<void>;
}
