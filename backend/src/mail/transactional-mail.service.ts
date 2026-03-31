import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

/**
 * Простая отправка транзакционных писем (SMTP или Resend), та же логика, что у OTP email.
 */
@Injectable()
export class TransactionalMailService {
  private readonly log = new Logger(TransactionalMailService.name);

  constructor(private readonly config: ConfigService) {}

  private resolveFromAddress(): string {
    return (
      this.config.get<string>('EMAIL_FROM')?.trim() ||
      this.config.get<string>('SMTP_FROM')?.trim() ||
      this.config.get<string>('SMTP_USER')?.trim() ||
      'noreply@localhost'
    );
  }

  /**
   * Возвращает false, если почта не настроена (не бросает исключение).
   */
  isConfigured(): boolean {
    const backend = (this.config.get<string>('EMAIL_PROVIDER') || 'smtp').toLowerCase().trim();
    if (backend === 'resend') {
      const apiKey =
        this.config.get<string>('EMAIL_API_KEY')?.trim() || this.config.get<string>('RESEND_API_KEY')?.trim();
      return !!apiKey && this.resolveFromAddress() !== 'noreply@localhost';
    }
    return !!this.config.get<string>('SMTP_HOST')?.trim();
  }

  async send(params: { to: string; subject: string; text: string; html?: string }): Promise<void> {
    const to = params.to.trim();
    if (!to) return;

    const emailBackend = (this.config.get<string>('EMAIL_PROVIDER') || 'smtp').toLowerCase().trim();

    if (emailBackend === 'resend') {
      return this.sendViaResend(params);
    }

    const host = this.config.get<string>('SMTP_HOST')?.trim();
    const port = parseInt(this.config.get<string>('SMTP_PORT') || '587', 10);
    const user = this.config.get<string>('SMTP_USER')?.trim();
    const pass = this.config.get<string>('SMTP_PASS') ?? '';
    const from = this.resolveFromAddress();

    if (!host) {
      throw new ServiceUnavailableException(
        'Почта не настроена: задайте SMTP_HOST или EMAIL_PROVIDER=resend с ключом и EMAIL_FROM.',
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
        to,
        subject: params.subject,
        text: params.text,
        html: params.html ?? params.text.replace(/\n/g, '<br/>'),
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.log.error(`SMTP send failed: ${msg}`);
      throw new ServiceUnavailableException('Не удалось отправить письмо. Попробуйте позже.');
    }
  }

  private async sendViaResend(params: { to: string; subject: string; text: string; html?: string }): Promise<void> {
    const apiKey =
      this.config.get<string>('EMAIL_API_KEY')?.trim() || this.config.get<string>('RESEND_API_KEY')?.trim();
    const from = this.resolveFromAddress();

    if (!apiKey) {
      throw new ServiceUnavailableException('Resend: задайте EMAIL_API_KEY (или RESEND_API_KEY).');
    }
    if (!from || from === 'noreply@localhost') {
      throw new ServiceUnavailableException('Resend: задайте EMAIL_FROM.');
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
          to: [params.to],
          subject: params.subject,
          text: params.text,
          html: params.html ?? params.text.replace(/\n/g, '<br/>'),
        }),
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.log.error(`Resend request failed: ${msg}`);
      throw new ServiceUnavailableException('Не удалось отправить письмо. Попробуйте позже.');
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
      throw new ServiceUnavailableException('Не удалось отправить письмо. Попробуйте позже.');
    }
  }
}
