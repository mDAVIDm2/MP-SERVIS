"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthModule = void 0;
const common_1 = require("@nestjs/common");
const throttler_1 = require("@nestjs/throttler");
const jwt_1 = require("@nestjs/jwt");
const passport_1 = require("@nestjs/passport");
const typeorm_1 = require("@nestjs/typeorm");
const config_1 = require("@nestjs/config");
const user_entity_1 = require("../users/user.entity");
const organization_entity_1 = require("../organizations/organization.entity");
const users_module_1 = require("../users/users.module");
const organizations_module_1 = require("../organizations/organizations.module");
const notifications_module_1 = require("../notifications/notifications.module");
const auth_otp_challenge_entity_1 = require("./auth-otp-challenge.entity");
const user_session_entity_1 = require("./user-session.entity");
const security_event_entity_1 = require("./security-event.entity");
const auth_controller_1 = require("./auth.controller");
const auth_sessions_controller_1 = require("./auth-sessions.controller");
const auth_service_1 = require("./auth.service");
const jwt_strategy_1 = require("./jwt.strategy");
const auth_otp_service_1 = require("./auth-otp.service");
const auth_session_service_1 = require("./auth-session.service");
const auth_security_event_service_1 = require("./auth-security-event.service");
const console_otp_delivery_provider_1 = require("./otp-delivery/console-otp-delivery.provider");
const email_otp_delivery_provider_1 = require("./otp-delivery/email-otp-delivery.provider");
const sms_otp_delivery_provider_1 = require("./otp-delivery/sms-otp-delivery.provider");
const otp_delivery_aggregator_1 = require("./otp-delivery/otp-delivery.aggregator");
let AuthModule = class AuthModule {
};
exports.AuthModule = AuthModule;
exports.AuthModule = AuthModule = __decorate([
    (0, common_1.Module)({
        imports: [
            throttler_1.ThrottlerModule,
            typeorm_1.TypeOrmModule.forFeature([user_entity_1.User, organization_entity_1.Organization, auth_otp_challenge_entity_1.AuthOtpChallenge, user_session_entity_1.UserSession, security_event_entity_1.SecurityEvent]),
            users_module_1.UsersModule,
            organizations_module_1.OrganizationsModule,
            notifications_module_1.NotificationsModule,
            passport_1.PassportModule,
            jwt_1.JwtModule.registerAsync({
                imports: [config_1.ConfigModule],
                useFactory: (config) => ({
                    secret: config.get('JWT_SECRET') || 'dev-secret',
                    signOptions: {
                        expiresIn: config.get('JWT_ACCESS_EXPIRES_IN') || config.get('JWT_EXPIRES_IN') || '15m',
                    },
                }),
                inject: [config_1.ConfigService],
            }),
        ],
        controllers: [auth_controller_1.AuthController, auth_sessions_controller_1.AuthSessionsController],
        providers: [
            console_otp_delivery_provider_1.ConsoleOtpDeliveryProvider,
            email_otp_delivery_provider_1.EmailOtpDeliveryProvider,
            sms_otp_delivery_provider_1.SmsOtpDeliveryProvider,
            otp_delivery_aggregator_1.OtpDeliveryAggregator,
            auth_otp_service_1.AuthOtpService,
            auth_security_event_service_1.AuthSecurityEventService,
            auth_session_service_1.AuthSessionService,
            auth_service_1.AuthService,
            jwt_strategy_1.JwtStrategy,
        ],
        exports: [auth_service_1.AuthService, jwt_1.JwtModule, auth_session_service_1.AuthSessionService, auth_security_event_service_1.AuthSecurityEventService],
    })
], AuthModule);
//# sourceMappingURL=auth.module.js.map