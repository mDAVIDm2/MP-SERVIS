import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { OtpDeliveryContext } from './otp-delivery.types';
import type { OtpDeliveryProvider } from './otp-delivery.types';

/**
 * Заглушка под будущий SMS/voice/flash-call. Подключите реализацию без смены auth-flow.
 */
@Injectable()
export class SmsOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly id = 'sms';

  constructor(private readonly config: ConfigService) {}

  async deliver(ctx: OtpDeliveryContext): Promise<void> {
    const prod = this.config.get<string>('NODE_ENV') === 'production';
    if (prod) {
      throw new ServiceUnavailableException(
        'SMS OTP не подключён: реализуйте SmsOtpDeliveryProvider.deliver (провайдер SMS) и зарегистрируйте его.',
      );
    }
    throw new ServiceUnavailableException(
      `[dev] SMS не реализован. recipient=${ctx.recipient} kind=${ctx.recipientKind}. Используйте OTP_DELIVERY_PROVIDER=console или email.`,
    );
  }
}
