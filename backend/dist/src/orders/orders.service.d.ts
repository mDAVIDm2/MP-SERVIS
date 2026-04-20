import { Repository } from 'typeorm';
import { Order } from './order.entity';
import { OrderItem } from './order-item.entity';
import { OrderPhoto } from './order-photo.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { ChatsService } from '../chats/chats.service';
import { Chat } from '../chats/chat.entity';
import { ChatMessage } from '../chats/chat-message.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { OrganizationsService } from '../organizations/organizations.service';
import { SubscriptionQuotaService } from '../subscriptions/subscription-quota.service';
import { MediaService } from '../media/media.service';
import { UsersService } from '../users/users.service';
import { UserClientHiddenCar } from '../users/user-client-hidden-car.entity';
export declare class OrdersService {
    private orderRepo;
    private itemRepo;
    private photoRepo;
    private staffRepo;
    private chatRepo;
    private chatMsgRepo;
    private chats;
    private notifications;
    private orgService;
    private subscriptionQuota;
    private readonly mediaService;
    private readonly usersService;
    private readonly hiddenCarRepo;
    constructor(orderRepo: Repository<Order>, itemRepo: Repository<OrderItem>, photoRepo: Repository<OrderPhoto>, staffRepo: Repository<StaffMember>, chatRepo: Repository<Chat>, chatMsgRepo: Repository<ChatMessage>, chats: ChatsService, notifications: NotificationsService, orgService: OrganizationsService, subscriptionQuota: SubscriptionQuotaService, mediaService: MediaService, usersService: UsersService, hiddenCarRepo: Repository<UserClientHiddenCar>);
    private loadHiddenCarIdsForClientUser;
    isCarHiddenForClient(userId: string, carId: string | null | undefined): Promise<boolean>;
    private buildClientAvatarMapForOrders;
    private assertOrderMediaAttachmentLimit;
    private mergeFirstBillingConfirmation;
    findAll(organizationId: string): Promise<{
        items: Record<string, unknown>[];
    }>;
    findAllForInternal(limit?: number, offset?: number): Promise<{
        items: Record<string, unknown>[];
        total: number;
    }>;
    findForClient(clientPhoneNorm: string): Promise<{
        items: Record<string, unknown>[];
    }>;
    findOne(id: string, filterHiddenForClientUserId?: string | null): Promise<Record<string, unknown> | null>;
    createFromChat(organizationId: string, clientPhone: string, approvalItems: any[], proposedDateTime?: Date): Promise<string>;
    private nextOrderNumber;
    private sanitizeCarPhotoUrl;
    create(organizationId: string, dto: any): Promise<Record<string, unknown> | null>;
    updateStatus(id: string, status: string): Promise<Record<string, unknown> | null>;
    private notifyClientOrderIfNeeded;
    updateTime(id: string, dto: {
        planned_start_time?: string;
        planned_end_time?: string;
    }): Promise<Record<string, unknown> | null>;
    normalizePhoneForCompare(phone: string): string;
    private notifyOrgStaffClientBookingSystemLine;
    private buildClientApprovalAppliedDisplayNames;
    private applyClientTimeConfirmAfterApproval;
    confirmByClient(orderId: string, clientPhoneNorm: string, newDateTime?: string, acceptProposed?: boolean, approvalMessageId?: string | null): Promise<Record<string, unknown> | null>;
    assignMaster(id: string, body: {
        master_id?: string | null;
        bay_id?: string | null;
    }): Promise<Record<string, unknown> | null>;
    cancel(id: string, opts?: {
        organizationId?: string;
        clientPhone?: string;
    }): Promise<Record<string, unknown> | null>;
    approveByClient(orderId: string, clientPhoneNorm: string, approvedItemIds: string[], _rejectedItemIds: string[], opts?: {
        approvalMessageId?: string | null;
    }): Promise<Record<string, unknown> | null>;
    approveBySto(orderId: string, organizationId: string): Promise<Record<string, unknown> | null>;
    updateItems(id: string, items: any[], organizationId?: string): Promise<Record<string, unknown> | null>;
    getChatForOrder(orderId: string, opts: {
        organizationId?: string;
        clientPhone?: string;
    }): Promise<{
        chat_id: string;
    }>;
    getOrderPhotos(orderId: string): Promise<{
        items: {
            id: string;
            file_path: string;
            url: string;
            created_at: string;
            media_type: string;
            size_bytes: number | null;
            width: number | null;
            height: number | null;
        }[];
    } | null>;
    addOrderPhoto(orderId: string, file: Express.Multer.File, opts?: {
        uploadedByUserId?: string | null;
    }): Promise<{
        id: string;
        file_path: string;
        url: string;
        created_at: string;
        media_type: string;
        size_bytes: number;
        width: number | null;
        height: number | null;
    } | null>;
    getOrderPhotoFile(orderId: string, photoId: string): Promise<string | null>;
    clearAllOrders(organizationId: string): Promise<{
        deletedOrders: number;
        deletedItems: number;
        deletedPhotos: number;
    }>;
    purgeOrdersByCarIdForInternal(carId: string): Promise<{
        deletedOrders: number;
        deletedItems: number;
        deletedPhotos: number;
    }>;
    moderateClearCarFieldsForInternal(clientPhone: string, carId: string, fields: {
        vin?: boolean;
        license_plate?: boolean;
        car_info?: boolean;
        car_photo_url?: boolean;
    }): Promise<{
        updated: number;
    }>;
    listClientCarsAggregatedForInternal(): Promise<{
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
    findOrdersByCarForInternal(clientPhoneDigits: string, carId: string): Promise<Record<string, unknown>[]>;
    toOrderJsonWithApprovalPreview(o: Order, orgBayCaches?: Map<string, Map<string, string>>, clientAvatarByPhoneKey?: Map<string, string | null>): Promise<Record<string, unknown>>;
    private parseApprovalPayloadLocal;
    private buildApprovalPreviewFromPayload;
    toOrderJson(o: Order, bayNames?: Map<string, string>, clientAvatarByPhoneKey?: Map<string, string | null>): {
        id: string;
        order_number: string;
        car_id: string;
        car_info: string;
        vin: any;
        license_plate: any;
        body_type: any;
        color: any;
        mileage: any;
        engine_type: any;
        client_name: string | null;
        client_phone: string | null;
        client_avatar_url: string | null;
        car_photo_url: any;
        status: import("./order.entity").OrderStatus;
        previous_status: any;
        first_confirmed_at: any;
        date_time: string;
        planned_start_time: any;
        planned_end_time: any;
        actual_start_time: any;
        actual_end_time: any;
        comment: string | null;
        organization_id: string;
        organization_name: any;
        organization_address: any;
        organization_phone: any;
        organization_business_kind: "sto" | "car_wash" | "detailing" | "car_audio" | "tire_service" | "body_shop" | "glass" | "tuning" | "ev_service" | "other" | null;
        organization_scheduling_mode: import("../organizations/organization-scheduling").SchedulingMode | null;
        master_id: string | null;
        master_name: any;
        bay_id: string | null;
        bay_name: string | null;
        created_at: any;
        updated_at: any;
        items: {
            id: string;
            name: string;
            price_kopecks: number | null;
            estimated_minutes: number;
            is_completed: boolean;
            is_additional: boolean;
            master_id: any;
        }[];
    };
}
