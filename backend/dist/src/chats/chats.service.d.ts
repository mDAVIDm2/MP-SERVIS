import { NotificationsService } from '../notifications/notifications.service';
import { Repository } from 'typeorm';
import { Chat } from './chat.entity';
import { ChatMessage } from './chat-message.entity';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { Organization } from '../organizations/organization.entity';
import { OrdersService } from '../orders/orders.service';
import { MediaService } from '../media/media.service';
import { SubscriptionQuotaService } from '../subscriptions/subscription-quota.service';
export declare class ChatsService {
    private chatRepo;
    private msgRepo;
    private orderRepo;
    private itemRepo;
    private orgRepo;
    private orders;
    private notifications;
    private readonly mediaService;
    private readonly subscriptionQuota;
    constructor(chatRepo: Repository<Chat>, msgRepo: Repository<ChatMessage>, orderRepo: Repository<Order>, itemRepo: Repository<OrderItem>, orgRepo: Repository<Organization>, orders: OrdersService, notifications: NotificationsService, mediaService: MediaService, subscriptionQuota: SubscriptionQuotaService);
    private apiBaseUrl;
    validateChatAccess(chat: Chat, userOrgId: string | null, userPhoneNorm: string | null, asClient: boolean): void;
    getOrCreateSupportChat(clientPhoneRaw: string): Promise<Chat>;
    getOrCreateForClient(organizationId: string, clientPhoneRaw: string): Promise<Chat>;
    getOrCreateForOrderChat(_orderId: string, organizationId: string, clientPhoneRaw: string): Promise<Chat>;
    findChatByOrgAndPhone(organizationId: string, clientPhoneRaw: string): Promise<Chat | null>;
    getChatByOrderId(orderId: string): Promise<Chat | null>;
    private approvalItemNames;
    private parseApprovalPayload;
    private hasApprovalContent;
    private isUsableApprovalMessage;
    getLastApprovalMessageForOrder(orderId: string): Promise<ChatMessage | null>;
    resolveApprovalMessageForOrder(orderId: string, messageId?: string | null): Promise<ChatMessage | null>;
    getLastApprovalMessageByOrderId(orderId: string): Promise<ChatMessage | null>;
    createForOrder(orderId: string): Promise<Chat>;
    addSystemMessage(chatId: string, text: string, orderId?: string | null): Promise<ChatMessage>;
    addOrderCardMessage(chatId: string, orderId: string, items: {
        name: string;
        price_kopecks?: number | null;
        estimated_minutes?: number;
    }[], proposedDateTime?: Date): Promise<void>;
    getChats(organizationId: string): Promise<{
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
    getChatsWithSupportForStaff(organizationId: string, phoneRaw: string): Promise<{
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
    listSupportChatsForInternal(): Promise<{
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
    postInternalSupportOperatorMessage(chatId: string, text: string): Promise<{
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
    markInternalSupportChatRead(chatId: string): Promise<void>;
    findChatEntityById(chatId: string): Promise<Chat | null>;
    findChatForAccess(chatId: string): Promise<Chat | null>;
    getChatById(chatId: string, userOrgId: string | null, userPhoneNorm: string | null, asClient: boolean): Promise<{
        items: any[];
    }>;
    getChatsForClient(clientPhoneNorm: string): Promise<{
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
    private dedupChatsByClient;
    private getLastOrderForChat;
    private getOrderForChat;
    private isPendingApproval;
    private computeUnreadForClient;
    private computeUnreadForSupportParticipant;
    private computeUnreadForInternalSupport;
    private computeUnreadForOrganization;
    markChatRead(chatId: string, userOrgId: string | null, userPhoneNorm: string | null, asClient: boolean): Promise<void>;
    private formatChatsResponse;
    getInternalSupportChatMessages(chatId: string): Promise<{
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
    getMessagesForParticipant(chatId: string, userOrgId: string | null, userPhoneNorm: string | null, asClient: boolean): Promise<{
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
    private buildMessagesPayload;
    resolveChatAttachmentLocalPath(chatId: string, assetId: string, userOrgId: string | null, userPhoneNorm: string | null, asClient: boolean): Promise<string | null>;
    sendMessageWithMedia(chatId: string, dto: {
        text?: string;
    }, files: Express.Multer.File[] | undefined, isFromClient: boolean, access: {
        userOrgId: string | null;
        userPhoneNorm: string | null;
        asClient: boolean;
    }, opts?: {
        supportChannel?: 'client' | 'business' | null;
        uploadedByUserId?: string | null;
    }): Promise<{
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
    sendMessage(chatId: string, dto: {
        text?: string;
        order_id?: string;
        approval_items?: any;
        proposed_date_time?: string;
        is_system?: boolean;
    }, isFromClient?: boolean, opts?: {
        supportChannel?: 'client' | 'business' | null;
    }): Promise<{
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
    private applyApprovalToOrder;
}
