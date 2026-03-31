"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_CLIENT_NOTIFICATION_PREFS = void 0;
exports.mergeClientNotificationPrefs = mergeClientNotificationPrefs;
exports.channelForNotificationType = channelForNotificationType;
exports.prefsAllowType = prefsAllowType;
exports.notificationTypesAllowedByPrefs = notificationTypesAllowedByPrefs;
exports.DEFAULT_CLIENT_NOTIFICATION_PREFS = {
    pushEnabled: true,
    orderUpdates: true,
    chatMessages: true,
    promotions: false,
    reminders: true,
    securityAlerts: true,
};
function mergeClientNotificationPrefs(raw) {
    const d = exports.DEFAULT_CLIENT_NOTIFICATION_PREFS;
    if (!raw || typeof raw !== 'object')
        return { ...d };
    return {
        pushEnabled: typeof raw['pushEnabled'] === 'boolean' ? raw['pushEnabled'] : d.pushEnabled,
        orderUpdates: typeof raw['orderUpdates'] === 'boolean' ? raw['orderUpdates'] : d.orderUpdates,
        chatMessages: typeof raw['chatMessages'] === 'boolean' ? raw['chatMessages'] : d.chatMessages,
        promotions: typeof raw['promotions'] === 'boolean' ? raw['promotions'] : d.promotions,
        reminders: typeof raw['reminders'] === 'boolean' ? raw['reminders'] : d.reminders,
        securityAlerts: typeof raw['securityAlerts'] === 'boolean' ? raw['securityAlerts'] : d.securityAlerts,
    };
}
function channelForNotificationType(type) {
    if (type === 'security')
        return 'security';
    if (type === 'chat')
        return 'chat';
    if (type === 'order')
        return 'order';
    if (type === 'general')
        return 'promotion';
    if (type === 'organization_invite')
        return 'reminder';
    if (type === 'pending_car_approved' || type === 'pending_car_rejected' || type === 'pending_car_suggested') {
        return 'reminder';
    }
    return 'promotion';
}
function prefsAllowType(prefs, type) {
    const ch = channelForNotificationType(type);
    if (ch === 'security')
        return prefs.pushEnabled && prefs.securityAlerts !== false;
    if (ch === 'chat' && !prefs.chatMessages)
        return false;
    if (ch === 'order' && !prefs.orderUpdates)
        return false;
    if (ch === 'promotion' && !prefs.promotions)
        return false;
    if (ch === 'reminder' && !prefs.reminders)
        return false;
    return true;
}
function notificationTypesAllowedByPrefs(prefs) {
    const out = [];
    if (prefs.chatMessages)
        out.push('chat');
    if (prefs.orderUpdates)
        out.push('order');
    if (prefs.promotions)
        out.push('general');
    if (prefs.reminders) {
        out.push('pending_car_approved', 'pending_car_rejected', 'pending_car_suggested', 'organization_invite');
    }
    if (prefs.securityAlerts !== false)
        out.push('security');
    return out;
}
//# sourceMappingURL=client-notification-preferences.js.map