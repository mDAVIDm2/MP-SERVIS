import { Injectable, Logger } from '@nestjs/common';
import type { OtpDeliveryContext } from './otp-delivery.types';
import type { OtpDeliveryProvider } from './otp-delivery.types';

@Injectable()
export class ConsoleOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly id = 'console';
  private readonly log = new Logger(ConsoleOtpDeliveryProvider.name);

  async deliver(ctx: OtpDeliveryContext): Promise<void> {
    this.log.warn(
      `[OTP console] kind=${ctx.recipientKind} recipient=${ctx.recipient} code=${ctx.code} ttl=${ctx.ttlSeconds}s channel=${ctx.requestedChannel}`,
    );
  }
}
