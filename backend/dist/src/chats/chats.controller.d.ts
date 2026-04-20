import { Request, Response } from 'express';
import { ChatsService } from './chats.service';
export declare class ChatsController {
    private chats;
    constructor(chats: ChatsService);
    openSupport(req: Request & {
        user: {
            phone?: string;
        };
    }): Promise<{
        items: any[];
    }>;
    openOrganizationChat(req: Request & {
        user: {
            phone?: string;
        };
    }, body: {
        organization_id?: string;
    }): Promise<{
        items: any[];
    }>;
    list(req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<{
        items: {
            id: string;
            order_id: any;
            order_number: any;
            order_status: any;
            organization_id: string;
            organization_name: any;
            organization_photo_url: string | null;
            organization_phone: string | null;
            client_avatar_url: string | null;
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
    getMessages(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<{
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
    getAttachmentFile(chatId: string, assetId: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }, res: Response): Promise<void | Response<any, Record<string, any>>>;
    getOne(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<{
        items: any[];
    }>;
    markRead(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<void>;
    sendMessageWithMedia(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
            id?: string;
        };
    }, body: {
        text?: string;
    }, files: Express.Multer.File[] | undefined): Promise<{
        id: string;
        text: string;
        is_from_client: boolean;
        is_system: boolean;
        is_from_support_operator: boolean;
        support_channel: string | null;
        at: string;
        approval_items: null;
        approval_status: null;
        proposed_date_time: null;
        order_id: null;
        attachments: {
            id: string;
            url: string;
            mime_type: string;
            width: number | null;
            height: number | null;
            size_bytes: number;
        }[];
    }>;
    sendMessage(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }, body: any): Promise<{
        id: string;
        text: string;
        is_from_client: boolean;
        at: string;
        message_type: string;
        approval_items: unknown;
        approval_status: string | null;
        proposed_date_time: string | null;
        order_id: string;
        is_system?: undefined;
        is_from_support_operator?: undefined;
        support_channel?: undefined;
    } | {
        id: string;
        text: string;
        is_from_client: boolean;
        is_system: boolean;
        is_from_support_operator: boolean;
        support_channel: string | null;
        at: string;
        approval_items: null;
        approval_status: null;
        proposed_date_time: null;
        order_id: null;
        message_type?: undefined;
    }>;
}
