import type { OtpDeliveryContext } from './otp-delivery.types';
import type { OtpDeliveryProvider } from './otp-delivery.types';
export declare class ConsoleOtpDeliveryProvider implements OtpDeliveryProvider {
    readonly id = "console";
    private readonly log;
    deliver(ctx: OtpDeliveryContext): Promise<void>;
}
