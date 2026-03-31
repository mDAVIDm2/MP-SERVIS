export type NotificationType = 'pending_car_approved' | 'pending_car_rejected' | 'pending_car_suggested' | 'order' | 'chat' | 'general' | 'security' | 'organization_invite';
export declare class Notification {
    id: string;
    userId: string;
    carId: string | null;
    type: NotificationType;
    title: string;
    body: string | null;
    isRead: boolean;
    payload: Record<string, unknown> | null;
    createdAt: Date;
}
