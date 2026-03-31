import { Repository } from 'typeorm';
import { PushDevice } from './push-device.entity';
import { Notification, NotificationType } from './notification.entity';
import { FcmPushService } from './fcm-push.service';
import { UsersService } from '../users/users.service';
export declare class NotificationsService {
    private pushRepo;
    private notificationRepo;
    private fcm;
    private users;
    constructor(pushRepo: Repository<PushDevice>, notificationRepo: Repository<Notification>, fcm: FcmPushService, users: UsersService);
    registerDevice(userId: string, deviceToken: string, platform: string, fcmApp?: 'client' | 'business'): Promise<void>;
    private payloadToFcmData;
    notifyOrganizationInvite(params: {
        userId: string;
        organizationName: string;
        role: string;
        invitationId: string;
        organizationId: string;
    }): Promise<Notification | null>;
    create(data: {
        userId: string;
        carId?: string | null;
        type: NotificationType;
        title: string;
        body?: string | null;
        payload?: Record<string, unknown> | null;
    }): Promise<Notification | null>;
    createForClientPhone(phoneDigits: string, data: {
        carId?: string | null;
        type: NotificationType;
        title: string;
        body?: string | null;
        payload?: Record<string, unknown> | null;
    }): Promise<Notification | null>;
    createOrRefreshChatMessageForClientPhone(phoneDigits: string, data: {
        title: string;
        messageLine: string;
        payload: Record<string, unknown> & {
            chat_id: string;
        };
    }): Promise<Notification | null>;
    private mergeChatNotificationBodies;
    getNotifications(userId: string, carId?: string | null, respectClientPrefs?: boolean): Promise<{
        items: NotificationDto[];
    }>;
    markAsRead(userId: string, notificationId: string): Promise<void>;
    markAllAsRead(userId: string, carId?: string | null): Promise<void>;
    markUnreadAsReadByOrderId(userId: string, orderId: string): Promise<void>;
    markUnreadAsReadByChatId(userId: string, chatId: string): Promise<void>;
    delete(userId: string, notificationId: string): Promise<void>;
    getUnreadCount(userId: string, respectClientPrefs?: boolean): Promise<number>;
    getUnreadCountPerCar(userId: string, respectClientPrefs?: boolean): Promise<Record<string, number>>;
}
export interface NotificationDto {
    id: string;
    carId: string | null;
    type: string;
    title: string;
    body: string | null;
    isRead: boolean;
    payload: Record<string, unknown> | null;
    createdAt: Date;
}
