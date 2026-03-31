import { NotificationType } from './notification.entity';
export interface ClientNotificationPreferences {
    pushEnabled: boolean;
    orderUpdates: boolean;
    chatMessages: boolean;
    promotions: boolean;
    reminders: boolean;
    securityAlerts: boolean;
}
export declare const DEFAULT_CLIENT_NOTIFICATION_PREFS: ClientNotificationPreferences;
export declare function mergeClientNotificationPrefs(raw: Record<string, unknown> | null | undefined): ClientNotificationPreferences;
export type NotificationChannel = 'chat' | 'order' | 'promotion' | 'reminder' | 'security';
export declare function channelForNotificationType(type: NotificationType): NotificationChannel;
export declare function prefsAllowType(prefs: ClientNotificationPreferences, type: NotificationType): boolean;
export declare function notificationTypesAllowedByPrefs(prefs: ClientNotificationPreferences): NotificationType[];
