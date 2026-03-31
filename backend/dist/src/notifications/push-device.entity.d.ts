import { User } from '../users/user.entity';
export declare class PushDevice {
    id: string;
    userId: string;
    user: User;
    deviceToken: string;
    platform: string;
    fcmApp: string;
}
