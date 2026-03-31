import { ConfigService } from '@nestjs/config';
import type { OtpDeliveryContext } from './otp-delivery.types';
import type { OtpDeliveryProvider } from './otp-delivery.types';
export declare class SmsOtpDeliveryProvider implements OtpDeliveryProvider {
    private readonly config;
    readonly id = "sms";
    constructor(config: ConfigService);
    deliver(ctx: OtpDeliveryContext): Promise<void>;
}
