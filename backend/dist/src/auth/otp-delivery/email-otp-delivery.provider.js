"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var EmailOtpDeliveryProvider_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmailOtpDeliveryProvider = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const nodemailer = require("nodemailer");
let EmailOtpDeliveryProvider = EmailOtpDeliveryProvider_1 = class EmailOtpDeliveryProvider {
    constructor(config) {
        this.config = config;
        this.id = 'email';
        this.log = new common_1.Logger(EmailOtpDeliveryProvider_1.name);
    }
    buildMail(ctx) {
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
    resolveFromAddress() {
        return (this.config.get('EMAIL_FROM')?.trim() ||
            this.config.get('SMTP_FROM')?.trim() ||
            this.config.get('SMTP_USER')?.trim() ||
            'noreply@localhost');
    }
    async sendViaResend(ctx, subject, text, html) {
        const apiKey = this.config.get('EMAIL_API_KEY')?.trim() || this.config.get('RESEND_API_KEY')?.trim();
        const from = this.resolveFromAddress();
        if (!apiKey) {
            throw new common_1.ServiceUnavailableException('Resend: задайте EMAIL_API_KEY (или RESEND_API_KEY). Для SMTP укажите EMAIL_PROVIDER=smtp и SMTP_HOST.');
        }
        if (!from || from === 'noreply@localhost') {
            throw new common_1.ServiceUnavailableException('Resend: задайте EMAIL_FROM (домен отправителя должен быть подтверждён в панели Resend).');
        }
        let res;
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
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            this.log.error(`Resend request failed: ${msg}`);
            throw new common_1.ServiceUnavailableException('Не удалось отправить письмо с кодом. Попробуйте позже.');
        }
        if (!res.ok) {
            let detail = res.statusText;
            try {
                const j = (await res.json());
                if (j?.message != null) {
                    detail = Array.isArray(j.message) ? j.message.join('; ') : j.message;
                }
            }
            catch {
            }
            this.log.error(`Resend send failed: ${res.status} ${detail}`);
            throw new common_1.ServiceUnavailableException('Не удалось отправить письмо с кодом. Попробуйте позже.');
        }
    }
    async deliver(ctx) {
        if (ctx.recipientKind !== 'email') {
            throw new common_1.ServiceUnavailableException('Email-провайдер принимает только recipient_kind=email');
        }
        const { subject, text, html } = this.buildMail(ctx);
        const emailBackend = (this.config.get('EMAIL_PROVIDER') || 'smtp').toLowerCase().trim();
        if (emailBackend === 'resend') {
            return this.sendViaResend(ctx, subject, text, html);
        }
        const host = this.config.get('SMTP_HOST')?.trim();
        const port = parseInt(this.config.get('SMTP_PORT') || '587', 10);
        const user = this.config.get('SMTP_USER')?.trim();
        const pass = this.config.get('SMTP_PASS') ?? '';
        const from = this.resolveFromAddress();
        if (!host) {
            throw new common_1.ServiceUnavailableException('Отправка email OTP не настроена: задайте SMTP_HOST (SMTP_*) или EMAIL_PROVIDER=resend с EMAIL_API_KEY и EMAIL_FROM. Для разработки: OTP_DELIVERY_PROVIDER=console.');
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
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            this.log.error(`SMTP send failed: ${msg}`);
            throw new common_1.ServiceUnavailableException('Не удалось отправить письмо с кодом. Попробуйте позже.');
        }
    }
};
exports.EmailOtpDeliveryProvider = EmailOtpDeliveryProvider;
exports.EmailOtpDeliveryProvider = EmailOtpDeliveryProvider = EmailOtpDeliveryProvider_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], EmailOtpDeliveryProvider);
//# sourceMappingURL=email-otp-delivery.provider.js.map