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
var TransactionalMailService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransactionalMailService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const nodemailer = require("nodemailer");
let TransactionalMailService = TransactionalMailService_1 = class TransactionalMailService {
    constructor(config) {
        this.config = config;
        this.log = new common_1.Logger(TransactionalMailService_1.name);
    }
    resolveFromAddress() {
        return (this.config.get('EMAIL_FROM')?.trim() ||
            this.config.get('SMTP_FROM')?.trim() ||
            this.config.get('SMTP_USER')?.trim() ||
            'noreply@localhost');
    }
    isConfigured() {
        const backend = (this.config.get('EMAIL_PROVIDER') || 'smtp').toLowerCase().trim();
        if (backend === 'resend') {
            const apiKey = this.config.get('EMAIL_API_KEY')?.trim() || this.config.get('RESEND_API_KEY')?.trim();
            return !!apiKey && this.resolveFromAddress() !== 'noreply@localhost';
        }
        return !!this.config.get('SMTP_HOST')?.trim();
    }
    async send(params) {
        const to = params.to.trim();
        if (!to)
            return;
        const emailBackend = (this.config.get('EMAIL_PROVIDER') || 'smtp').toLowerCase().trim();
        if (emailBackend === 'resend') {
            return this.sendViaResend(params);
        }
        const host = this.config.get('SMTP_HOST')?.trim();
        const port = parseInt(this.config.get('SMTP_PORT') || '587', 10);
        const user = this.config.get('SMTP_USER')?.trim();
        const pass = this.config.get('SMTP_PASS') ?? '';
        const from = this.resolveFromAddress();
        if (!host) {
            throw new common_1.ServiceUnavailableException('Почта не настроена: задайте SMTP_HOST или EMAIL_PROVIDER=resend с ключом и EMAIL_FROM.');
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
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            this.log.error(`SMTP send failed: ${msg}`);
            throw new common_1.ServiceUnavailableException('Не удалось отправить письмо. Попробуйте позже.');
        }
    }
    async sendViaResend(params) {
        const apiKey = this.config.get('EMAIL_API_KEY')?.trim() || this.config.get('RESEND_API_KEY')?.trim();
        const from = this.resolveFromAddress();
        if (!apiKey) {
            throw new common_1.ServiceUnavailableException('Resend: задайте EMAIL_API_KEY (или RESEND_API_KEY).');
        }
        if (!from || from === 'noreply@localhost') {
            throw new common_1.ServiceUnavailableException('Resend: задайте EMAIL_FROM.');
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
                    to: [params.to],
                    subject: params.subject,
                    text: params.text,
                    html: params.html ?? params.text.replace(/\n/g, '<br/>'),
                }),
            });
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            this.log.error(`Resend request failed: ${msg}`);
            throw new common_1.ServiceUnavailableException('Не удалось отправить письмо. Попробуйте позже.');
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
            throw new common_1.ServiceUnavailableException('Не удалось отправить письмо. Попробуйте позже.');
        }
    }
};
exports.TransactionalMailService = TransactionalMailService;
exports.TransactionalMailService = TransactionalMailService = TransactionalMailService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], TransactionalMailService);
//# sourceMappingURL=transactional-mail.service.js.map