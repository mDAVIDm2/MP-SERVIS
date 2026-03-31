import { ConfigService } from '@nestjs/config';
import { ConsoleOtpDeliveryProvider } from './console-otp-delivery.provider';
import { EmailOtpDeliveryProvider } from './email-otp-delivery.provider';
import { SmsOtpDeliveryProvider } from './sms-otp-delivery.provider';
import type { OtpDeliveryContext } from './otp-delivery.types';
export declare class OtpDeliveryAggregator {
    private readonly config;
    private readonly consoleProvider;
    private readonly emailProvider;
    private readonly smsProvider;
    constructor(config: ConfigService, consoleProvider: ConsoleOtpDeliveryProvider, emailProvider: EmailOtpDeliveryProvider, smsProvider: SmsOtpDeliveryProvider);
    getConfiguredMode(): string;
    deliver(ctx: OtpDeliveryContext): Promise<void>;
}
