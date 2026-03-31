"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var FcmPushService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.FcmPushService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const fs_1 = require("fs");
const path_1 = require("path");
const typeorm_2 = require("typeorm");
const admin = require("firebase-admin");
const push_device_entity_1 = require("./push-device.entity");
const user_entity_1 = require("../users/user.entity");
const client_notification_preferences_1 = require("./client-notification-preferences");
function readServiceAccountJson(log, inlineEnv, pathEnv, label) {
    const inline = inlineEnv?.trim();
    if (inline)
        return inline;
    const rel = pathEnv?.trim();
    if (!rel)
        return null;
    const abs = (0, path_1.isAbsolute)(rel) ? rel : (0, path_1.join)(process.cwd(), rel);
    try {
        return (0, fs_1.readFileSync)(abs, 'utf8');
    }
    catch (e) {
        log.warn(`FCM ${label}: не удалось прочитать файл (${abs}): ${e}`);
        return null;
    }
}
function defaultFirebaseAppExists() {
    try {
        admin.app();
        return true;
    }
    catch {
        return false;
    }
}
function namedFirebaseAppExists(name) {
    try {
        admin.app(name);
        return true;
    }
    catch {
        return false;
    }
}
let FcmPushService = FcmPushService_1 = class FcmPushService {
    constructor(pushRepo, userRepo) {
        this.pushRepo = pushRepo;
        this.userRepo = userRepo;
        this.log = new common_1.Logger(FcmPushService_1.name);
        this.messagingClient = null;
        this.messagingBusiness = null;
        const clientJson = readServiceAccountJson(this.log, process.env.FIREBASE_SERVICE_ACCOUNT_JSON, process.env.FIREBASE_SERVICE_ACCOUNT_PATH, 'клиент');
        if (clientJson?.length) {
            try {
                const cred = JSON.parse(clientJson);
                if (!defaultFirebaseAppExists()) {
                    admin.initializeApp({ credential: admin.credential.cert(cred) });
                }
                this.messagingClient = admin.messaging();
                this.log.log('FCM: клиентский Firebase-проект инициализирован');
            }
            catch (e) {
                this.log.warn(`FCM клиент: ${e}`);
            }
        }
        else {
            this.log.warn('FCM: задайте FIREBASE_SERVICE_ACCOUNT_JSON или FIREBASE_SERVICE_ACCOUNT_PATH (клиент) — пуши на клиентские токены отключены');
        }
        const businessJson = readServiceAccountJson(this.log, process.env.FIREBASE_BUSINESS_SERVICE_ACCOUNT_JSON, process.env.FIREBASE_BUSINESS_SERVICE_ACCOUNT_PATH, 'Business');
        if (businessJson?.length) {
            try {
                const cred = JSON.parse(businessJson);
                if (!namedFirebaseAppExists('business')) {
                    admin.initializeApp({ credential: admin.credential.cert(cred) }, 'business');
                }
                this.messagingBusiness = admin.messaging(admin.app('business'));
                this.log.log('FCM: Firebase-проект Business инициализирован');
            }
            catch (e) {
                this.log.warn(`FCM Business: ${e}`);
            }
        }
        else {
            this.log.warn('FCM: FIREBASE_BUSINESS_SERVICE_ACCOUNT_PATH не задан — пуши на приложение Business отключены');
        }
    }
    async getUserPrefs(userId) {
        const u = await this.userRepo.findOne({ where: { id: userId } });
        if (!u)
            return { ...client_notification_preferences_1.DEFAULT_CLIENT_NOTIFICATION_PREFS };
        return (0, client_notification_preferences_1.mergeClientNotificationPrefs)(u.notificationPreferences);
    }
    channelAllowed(prefs, channel) {
        if (!prefs.pushEnabled)
            return false;
        switch (channel) {
            case 'chat':
                return prefs.chatMessages;
            case 'order':
                return prefs.orderUpdates;
            case 'promotion':
                return prefs.promotions;
            case 'reminder':
                return prefs.reminders;
            default:
                return true;
        }
    }
    async sendToUser(userId, channel, title, body, data, collapse) {
        const prefs = await this.getUserPrefs(userId);
        if (!prefs.pushEnabled)
            return;
        if (!this.channelAllowed(prefs, channel))
            return;
        const devices = await this.pushRepo.find({ where: { userId } });
        const clientTokens = devices
            .filter((d) => (d.fcmApp ?? 'client') === 'client')
            .map((d) => d.deviceToken)
            .filter((t) => t && t.length > 8);
        const businessTokens = devices
            .filter((d) => d.fcmApp === 'business')
            .map((d) => d.deviceToken)
            .filter((t) => t && t.length > 8);
        const dataStr = { ...data };
        for (const k of Object.keys(dataStr)) {
            if (dataStr[k] == null)
                delete dataStr[k];
        }
        await this.sendMulticast(this.messagingClient, clientTokens, title, body, dataStr, collapse, 'autohub_messages');
        await this.sendMulticast(this.messagingBusiness, businessTokens, title, body, dataStr, collapse, 'autohub_business');
    }
    async sendMulticast(messaging, tokens, title, body, dataStr, collapse, androidChannelId) {
        if (!messaging || !tokens.length)
            return;
        const androidNotif = {
            channelId: androidChannelId,
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: 'public',
        };
        if (collapse?.androidTag) {
            androidNotif['tag'] = collapse.androidTag.slice(0, 64);
        }
        const apsPayload = {
            sound: 'default',
            badge: 1,
        };
        if (collapse?.apnsThreadId) {
            apsPayload['thread-id'] = collapse.apnsThreadId.slice(0, 128);
        }
        try {
            const res = await messaging.sendEachForMulticast({
                tokens,
                notification: { title, body },
                data: dataStr,
                android: {
                    priority: 'high',
                    notification: androidNotif,
                },
                apns: {
                    headers: { 'apns-priority': '10' },
                    payload: {
                        aps: apsPayload,
                    },
                },
            });
            if (res.failureCount > 0) {
                const first = res.responses.find((r) => !r.success);
                const detail = first?.error ? ` (${first.error.code}: ${first.error.message})` : '';
                this.log.warn(`FCM: ${res.failureCount}/${tokens.length} доставок с ошибкой${detail}`);
            }
        }
        catch (e) {
            this.log.warn(`FCM sendEachForMulticast: ${e}`);
        }
    }
};
exports.FcmPushService = FcmPushService;
exports.FcmPushService = FcmPushService = FcmPushService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(push_device_entity_1.PushDevice)),
    __param(1, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository])
], FcmPushService);
//# sourceMappingURL=fcm-push.service.js.map