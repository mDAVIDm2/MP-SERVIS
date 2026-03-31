import { Repository } from 'typeorm';
import { PushDevice } from './push-device.entity';
import { User } from '../users/user.entity';
import { ClientNotificationPreferences, NotificationChannel } from './client-notification-preferences';
export declare class FcmPushService {
    private pushRepo;
    private userRepo;
    private readonly log;
    private messagingClient;
    private messagingBusiness;
    constructor(pushRepo: Repository<PushDevice>, userRepo: Repository<User>);
    getUserPrefs(userId: string): Promise<ClientNotificationPreferences>;
    private channelAllowed;
    sendToUser(userId: string, channel: NotificationChannel, title: string, body: string, data: Record<string, string>, collapse?: {
        androidTag?: string;
        apnsThreadId?: string;
    }): Promise<void>;
    private sendMulticast;
}
