import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type { OtpDeliveryContext } from './otp-delivery.types';
import type { OtpDeliveryProvider } from './otp-delivery.types';

@Injectable()
export class EmailOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly id = 'email';
  private readonly log = new Logger(EmailOtpDeliveryProvider.name);

  constructor(private readonly config: ConfigService) {}

  private buildMail(ctx: OtpDeliveryContext) {
    const minutes = Math.max(1, Math.ceil(ctx.ttlSeconds / 60));
    const subject = `MP-Servis: код входа (${minutes} мин)`;
    const text = [
      'Здравствуйте!',
      '',
      `Ваш одноразовый код входа в MP-Servis: ${ctx.code}`,
      '',
      `Код действителен ${minutes} мин. Не сообщайте его никому, в том числе сотрудникам поддержки.`,
      '',
      'Если вы не запрашивали вход, просто проигнорируйте это письмо.',
      '',
      '— MP-Servis',
    ].join('\n');

    const html = `
<!DOCTYPE html>
<html><body style="font-family:system-ui,sans-serif;line-height:1.5;color:#111">
  <p>Здравствуйте!</p>
  <p>Ваш одноразовый код входа в <strong>MP-Servis</strong>:</p>
  <p style="font-size:28px;font-weight:700;letter-spacing:4px">${ctx.code}</p>
  <p>Код действителен <strong>${minutes} мин</strong>. Не пересылайте это письмо и не сообщайте код третьим лицам.</p>
  <p style="color:#666;font-size:14px">Если вы не запрашивали вход, проигнорируйте письмо.</p>
  <p style="margin-top:24px;color:#999;font-size:12px">— MP-Servis</p>
</body></html>`;

    return { subject, text, html };
  }

  private resolveFromAddress(): string {
    return (
      this.config.get<string>('EMAIL_FROM')?.trim() ||
      this.config.get<string>('SMTP_FROM')?.trim() ||
      this.config.get<string>('SMTP_USER')?.trim() ||
      'noreply@localhost'
    );
  }

  /** Resend API: https://resend.com/docs/api-reference/emails/send-email */
  private async sendViaResend(ctx: OtpDeliveryContext, subject: string, text: string, html: string): Promise<void> {
    const apiKey =
      this.config.get<string>('EMAIL_API_KEY')?.trim() || this.config.get<string>('RESEND_API_KEY')?.trim();
    const from = this.resolveFromAddress();

    if (!apiKey) {
      throw new ServiceUnavailableException(
        'Resend: задайте EMAIL_API_KEY (или RESEND_API_KEY). Для SMTP укажите EMAIL_PROVIDER=smtp и SMTP_HOST.',
      );
    }
    if (!from || from === 'noreply@localhost') {
      throw new ServiceUnavailableException(
        'Resend: задайте EMAIL_FROM (домен отправителя должен быть подтверждён в панели Resend).',
      );
    }

    let res: Response;
    try {
      res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [ctx.recipient],
          subject,
          text,
          html,
        }),
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.log.error(`Resend request failed: ${msg}`);
      throw new ServiceUnavailableException('Не удалось отправить письмо с кодом. Попробуйте позже.');
    }

    if (!res.ok) {
      let detail = res.statusText;
      try {
        const j = (await res.json()) as { message?: string | string[] };
        if (j?.message != null) {
          detail = Array.isArray(j.message) ? j.message.join('; ') : j.message;
        }
      } catch {
        /* ignore */
      }
      this.log.error(`Resend send failed: ${res.status} ${detail}`);
      throw new ServiceUnavailableException('Не удалось отправить письмо с кодом. Попробуйте позже.');
    }
  }

  async deliver(ctx: OtpDeliveryContext): Promise<void> {
    if (ctx.recipientKind !== 'email') {
      throw new ServiceUnavailableException('Email-провайдер принимает только recipient_kind=email');
    }

    const { subject, text, html } = this.buildMail(ctx);
    const emailBackend = (this.config.get<string>('EMAIL_PROVIDER') || 'smtp').toLowerCase().trim();

    if (emailBackend === 'resend') {
      return this.sendViaResend(ctx, subject, text, html);
    }

    const host = this.config.get<string>('SMTP_HOST')?.trim();
    const port = parseInt(this.config.get<string>('SMTP_PORT') || '587', 10);
    const user = this.config.get<string>('SMTP_USER')?.trim();
    const pass = this.config.get<string>('SMTP_PASS') ?? '';
    const from = this.resolveFromAddress();

    if (!host) {
      throw new ServiceUnavailableException(
        'Отправка email OTP не настроена: задайте SMTP_HOST (SMTP_*) или EMAIL_PROVIDER=resend с EMAIL_API_KEY и EMAIL_FROM. Для разработки: OTP_DELIVERY_PROVIDER=console.',
      );
    }

    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: user ? { user, pass } : undefined,
    });

    try {
      await transporter.sendMail({
        from,
        to: ctx.recipient,
        subject,
        text,
        html,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.log.error(`SMTP send failed: ${msg}`);
      throw new ServiceUnavailableException('Не удалось отправить письмо с кодом. Попробуйте позже.');
    }
  }
}
