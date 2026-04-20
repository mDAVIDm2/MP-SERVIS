import { Response, Request } from 'express';
import { OrdersService } from './orders.service';
export declare class OrdersController {
    private orders;
    constructor(orders: OrdersService);
    list(req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<{
        items: Record<string, unknown>[];
    }>;
    getPhotos(orderId: string): Promise<{
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
    }>;
    addPhoto(orderId: string, file: Express.Multer.File, req: Request & {
        user?: {
            id?: string;
        };
    }): Promise<{
        id: string;
        file_path: string;
        url: string;
        created_at: string;
        media_type: string;
        size_bytes: number;
        width: number | null;
        height: number | null;
    }>;
    getPhotoFile(orderId: string, photoId: string, res: Response): Promise<void | Response<any, Record<string, any>>>;
    get(id: string, req: Request & {
        user: {
            id?: string;
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<Record<string, unknown>>;
    create(req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
            name?: string;
        };
    }, body: any): Promise<Record<string, unknown> | null>;
    clearAll(req: {
        user: {
            organizationId?: string | null;
        };
    }): Promise<{
        deletedOrders: number;
        deletedItems: number;
        deletedPhotos: number;
    }>;
    updateStatus(id: string, status: string): Promise<Record<string, unknown> | null>;
    updateTime(id: string, body: {
        planned_start_time?: string;
        planned_end_time?: string;
    }): Promise<Record<string, unknown>>;
    assignMaster(id: string, body: {
        master_id?: string | null;
        bay_id?: string | null;
    }): Promise<Record<string, unknown> | null>;
    cancel(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<Record<string, unknown>>;
    approveByClient(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }, body: {
        approved_item_ids?: string[];
        rejected_item_ids?: string[];
        approval_message_id?: string;
    }): Promise<Record<string, unknown>>;
    confirmByClient(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }, body: {
        date_time?: string;
        accept_proposed?: boolean;
        approval_message_id?: string;
    }): Promise<Record<string, unknown>>;
    confirmByPhone(id: string, req: {
        user: {
            organizationId?: string | null;
        };
    }): Promise<Record<string, unknown>>;
    updateItems(id: string, items: any[], req: {
        user: {
            organizationId?: string | null;
        };
    }): Promise<Record<string, unknown> | null>;
    getChatForOrder(id: string, req: Request & {
        user: {
            organizationId?: string | null;
            phone?: string;
        };
    }): Promise<{
        chat_id: string;
    }>;
}
