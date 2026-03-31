import { NotificationsService } from './notifications.service';
export declare class NotificationsController {
    private notifications;
    constructor(notifications: NotificationsService);
    registerDevice(req: {
        user: {
            id: string;
        };
    }, body: {
        device_token: string;
        platform?: string;
        fcm_app?: string;
    }): Promise<{}>;
    list(req: {
        user: {
            id: string;
        };
        headers?: any;
    }, carId?: string): Promise<{
        items: import("./notifications.service").NotificationDto[];
    }>;
    unreadCount(req: {
        user: {
            id: string;
        };
        headers?: any;
    }): Promise<{
        count: number;
    }>;
    unreadByCar(req: {
        user: {
            id: string;
        };
        headers?: any;
    }): Promise<Record<string, number>>;
    markAllRead(req: {
        user: {
            id: string;
        };
    }, body: {
        car_id?: string;
    }): Promise<{
        success: boolean;
    }>;
    markReadByOrder(req: {
        user: {
            id: string;
        };
    }, body: {
        order_id?: string;
    }): Promise<{
        success: boolean;
    }>;
    markReadByChat(req: {
        user: {
            id: string;
        };
    }, body: {
        chat_id?: string;
    }): Promise<{
        success: boolean;
    }>;
    markAsRead(req: {
        user: {
            id: string;
        };
    }, id: string): Promise<{
        success: boolean;
    }>;
    delete(req: {
        user: {
            id: string;
        };
    }, id: string): Promise<{
        success: boolean;
    }>;
}
