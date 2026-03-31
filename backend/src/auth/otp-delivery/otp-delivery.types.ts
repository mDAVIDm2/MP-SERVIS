export type OtpRecipientKind = 'email' | 'phone';

/** Контекст доставки OTP (код нигде не логируется кроме console-режима). */
export interface OtpDeliveryContext {
  code: string;
  ttlSeconds: number;
  recipient: string;
  recipientKind: OtpRecipientKind;
  /** Канал, запрошенный клиентом (для логов / будущей маршрутизации). */
  requestedChannel: string;
}

export interface OtpDeliveryProvider {
  readonly id: string;
  deliver(ctx: OtpDeliveryContext): Promise<void>;
}
