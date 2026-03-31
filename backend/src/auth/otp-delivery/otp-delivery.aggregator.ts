import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ConsoleOtpDeliveryProvider } from './console-otp-delivery.provider';
import { EmailOtpDeliveryProvider } from './email-otp-delivery.provider';
import { SmsOtpDeliveryProvider } from './sms-otp-delivery.provider';
import type { OtpDeliveryContext } from './otp-delivery.types';

/**
 * Выбор канала доставки:
 * OTP_DELIVERY_PROVIDER (приоритет) или AUTH_OTP_DELIVERY: console | email | sms | voice | flash.
 * Логика авторизации не зависит от конкретного провайдера.
 */
@Injectable()
export class OtpDeliveryAggregator {
  constructor(
    private readonly config: ConfigService,
    private readonly consoleProvider: ConsoleOtpDeliveryProvider,
    private readonly emailProvider: EmailOtpDeliveryProvider,
    private readonly smsProvider: SmsOtpDeliveryProvider,
  ) {}

  /** Режим из окружения (нижний регистр). */
  getConfiguredMode(): string {
    const raw =
      this.config.get<string>('OTP_DELIVERY_PROVIDER')?.trim() ||
      this.config.get<string>('AUTH_OTP_DELIVERY')?.trim() ||
      'console';
    return raw.toLowerCase();
  }

  async deliver(ctx: OtpDeliveryContext): Promise<void> {
    const mode = this.getConfiguredMode();

    if (mode === 'console') {
      return this.consoleProvider.deliver(ctx);
    }

    if (mode === 'email') {
      if (ctx.recipientKind !== 'email') {
        throw new BadRequestException(
          'Включён режим email (OTP_DELIVERY_PROVIDER или AUTH_OTP_DELIVERY=email): вход только по email. Для телефона подключите SMS (режим sms).',
        );
      }
      return this.emailProvider.deliver(ctx);
    }

    if (mode === 'sms' || mode === 'voice' || mode === 'flash') {
      return this.smsProvider.deliver(ctx);
    }

    return this.consoleProvider.deliver(ctx);
  }
}
