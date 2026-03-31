import { NotificationType } from './notification.entity';

/** Настройки уведомлений клиента (хранятся в users.notification_preferences). */
export interface ClientNotificationPreferences {
  pushEnabled: boolean;
  orderUpdates: boolean;
  chatMessages: boolean;
  promotions: boolean;
  reminders: boolean;
  /** Push о критичных событиях безопасности (сессии, компрометация). */
  securityAlerts: boolean;
}

export const DEFAULT_CLIENT_NOTIFICATION_PREFS: ClientNotificationPreferences = {
  pushEnabled: true,
  orderUpdates: true,
  chatMessages: true,
  promotions: false,
  reminders: true,
  securityAlerts: true,
};

export function mergeClientNotificationPrefs(
  raw: Record<string, unknown> | null | undefined,
): ClientNotificationPreferences {
  const d = DEFAULT_CLIENT_NOTIFICATION_PREFS;
  if (!raw || typeof raw !== 'object') return { ...d };
  return {
    pushEnabled: typeof raw['pushEnabled'] === 'boolean' ? (raw['pushEnabled'] as boolean) : d.pushEnabled,
    orderUpdates: typeof raw['orderUpdates'] === 'boolean' ? (raw['orderUpdates'] as boolean) : d.orderUpdates,
    chatMessages: typeof raw['chatMessages'] === 'boolean' ? (raw['chatMessages'] as boolean) : d.chatMessages,
    promotions: typeof raw['promotions'] === 'boolean' ? (raw['promotions'] as boolean) : d.promotions,
    reminders: typeof raw['reminders'] === 'boolean' ? (raw['reminders'] as boolean) : d.reminders,
    securityAlerts:
      typeof raw['securityAlerts'] === 'boolean' ? (raw['securityAlerts'] as boolean) : d.securityAlerts,
  };
}

export type NotificationChannel = 'chat' | 'order' | 'promotion' | 'reminder' | 'security';

export function channelForNotificationType(type: NotificationType): NotificationChannel {
  if (type === 'security') return 'security';
  if (type === 'chat') return 'chat';
  if (type === 'order') return 'order';
  if (type === 'general') return 'promotion';
  if (type === 'organization_invite') return 'reminder';
  if (type === 'pending_car_approved' || type === 'pending_car_rejected' || type === 'pending_car_suggested') {
    return 'reminder';
  }
  return 'promotion';
}

export function prefsAllowType(prefs: ClientNotificationPreferences, type: NotificationType): boolean {
  const ch = channelForNotificationType(type);
  if (ch === 'security') return prefs.pushEnabled && prefs.securityAlerts !== false;
  if (ch === 'chat' && !prefs.chatMessages) return false;
  if (ch === 'order' && !prefs.orderUpdates) return false;
  if (ch === 'promotion' && !prefs.promotions) return false;
  if (ch === 'reminder' && !prefs.reminders) return false;
  return true;
}

/** Типы уведомлений, которые видит клиент при текущих настройках (для выборки из БД). */
export function notificationTypesAllowedByPrefs(prefs: ClientNotificationPreferences): NotificationType[] {
  const out: NotificationType[] = [];
  if (prefs.chatMessages) out.push('chat');
  if (prefs.orderUpdates) out.push('order');
  if (prefs.promotions) out.push('general');
  if (prefs.reminders) {
    out.push('pending_car_approved', 'pending_car_rejected', 'pending_car_suggested', 'organization_invite');
  }
  if (prefs.securityAlerts !== false) out.push('security');
  return out;
}
