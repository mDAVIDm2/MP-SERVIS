"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var ConsoleOtpDeliveryProvider_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ConsoleOtpDeliveryProvider = void 0;
const common_1 = require("@nestjs/common");
let ConsoleOtpDeliveryProvider = ConsoleOtpDeliveryProvider_1 = class ConsoleOtpDeliveryProvider {
    constructor() {
        this.id = 'console';
        this.log = new common_1.Logger(ConsoleOtpDeliveryProvider_1.name);
    }
    async deliver(ctx) {
        this.log.warn(`[OTP console] kind=${ctx.recipientKind} recipient=${ctx.recipient} code=${ctx.code} ttl=${ctx.ttlSeconds}s channel=${ctx.requestedChannel}`);
    }
};
exports.ConsoleOtpDeliveryProvider = ConsoleOtpDeliveryProvider;
exports.ConsoleOtpDeliveryProvider = ConsoleOtpDeliveryProvider = ConsoleOtpDeliveryProvider_1 = __decorate([
    (0, common_1.Injectable)()
], ConsoleOtpDeliveryProvider);
//# sourceMappingURL=console-otp-delivery.provider.js.map