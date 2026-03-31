export declare class SendCodeDto {
    email?: string;
    phone?: string;
    channel?: string;
}
export declare class VerifyCodeDto {
    email?: string;
    phone?: string;
    challenge_id: string;
    code: string;
    phone_unverified?: string;
    name?: string;
    device_id?: string;
    device_name?: string;
    platform?: string;
}
export declare class RefreshDto {
    refresh_token: string;
    device_id?: string;
    device_name?: string;
    platform?: string;
}
export declare class LogoutDto {
    refresh_token: string;
}
