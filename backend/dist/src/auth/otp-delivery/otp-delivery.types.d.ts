export type OtpRecipientKind = 'email' | 'phone';
export interface OtpDeliveryContext {
    code: string;
    ttlSeconds: number;
    recipient: string;
    recipientKind: OtpRecipientKind;
    requestedChannel: string;
}
export interface OtpDeliveryProvider {
    readonly id: string;
    deliver(ctx: OtpDeliveryContext): Promise<void>;
}
