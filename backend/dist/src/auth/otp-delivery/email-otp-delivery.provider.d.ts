import { ConfigService } from '@nestjs/config';
import type { OtpDeliveryContext } from './otp-delivery.types';
import type { OtpDeliveryProvider } from './otp-delivery.types';
export declare class EmailOtpDeliveryProvider implements OtpDeliveryProvider {
    private readonly config;
    readonly id = "email";
    private readonly log;
    constructor(config: ConfigService);
    private buildMail;
    private resolveFromAddress;
    private sendViaResend;
    deliver(ctx: OtpDeliveryContext): Promise<void>;
}
