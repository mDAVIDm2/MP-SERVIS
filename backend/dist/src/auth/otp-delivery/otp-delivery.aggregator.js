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
Object.defineProperty(exports, "__esModule", { value: true });
exports.OtpDeliveryAggregator = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const console_otp_delivery_provider_1 = require("./console-otp-delivery.provider");
const email_otp_delivery_provider_1 = require("./email-otp-delivery.provider");
const sms_otp_delivery_provider_1 = require("./sms-otp-delivery.provider");
let OtpDeliveryAggregator = class OtpDeliveryAggregator {
    constructor(config, consoleProvider, emailProvider, smsProvider) {
        this.config = config;
        this.consoleProvider = consoleProvider;
        this.emailProvider = emailProvider;
        this.smsProvider = smsProvider;
    }
    getConfiguredMode() {
        const raw = this.config.get('OTP_DELIVERY_PROVIDER')?.trim() ||
            this.config.get('AUTH_OTP_DELIVERY')?.trim() ||
            'console';
        return raw.toLowerCase();
    }
    async deliver(ctx) {
        const mode = this.getConfiguredMode();
        if (mode === 'console') {
            return this.consoleProvider.deliver(ctx);
        }
        if (mode === 'email') {
            if (ctx.recipientKind !== 'email') {
                throw new common_1.BadRequestException('Включён режим email (OTP_DELIVERY_PROVIDER или AUTH_OTP_DELIVERY=email): вход только по email. Для телефона подключите SMS (режим sms).');
            }
            return this.emailProvider.deliver(ctx);
        }
        if (mode === 'sms' || mode === 'voice' || mode === 'flash') {
            return this.smsProvider.deliver(ctx);
        }
        return this.consoleProvider.deliver(ctx);
    }
};
exports.OtpDeliveryAggregator = OtpDeliveryAggregator;
exports.OtpDeliveryAggregator = OtpDeliveryAggregator = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService,
        console_otp_delivery_provider_1.ConsoleOtpDeliveryProvider,
        email_otp_delivery_provider_1.EmailOtpDeliveryProvider,
        sms_otp_delivery_provider_1.SmsOtpDeliveryProvider])
], OtpDeliveryAggregator);
//# sourceMappingURL=otp-delivery.aggregator.js.map