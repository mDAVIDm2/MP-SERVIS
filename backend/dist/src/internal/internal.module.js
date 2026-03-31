"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.InternalModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const jwt_1 = require("@nestjs/jwt");
const passport_1 = require("@nestjs/passport");
const typeorm_1 = require("@nestjs/typeorm");
const audit_log_entity_1 = require("../audit/audit-log.entity");
const internal_operator_entity_1 = require("./internal-operator.entity");
const internal_auth_service_1 = require("./internal-auth.service");
const internal_auth_controller_1 = require("./internal-auth.controller");
const internal_jwt_strategy_1 = require("./internal-jwt.strategy");
const internal_seed_service_1 = require("./internal-seed.service");
const internal_organizations_controller_1 = require("./internal-organizations.controller");
const internal_users_controller_1 = require("./internal-users.controller");
const internal_orders_controller_1 = require("./internal-orders.controller");
const internal_reference_controller_1 = require("./internal-reference.controller");
const internal_audit_controller_1 = require("./internal-audit.controller");
const internal_audit_service_1 = require("./internal-audit.service");
const internal_subscriptions_controller_1 = require("./internal-subscriptions.controller");
const internal_service_dictionaries_controller_1 = require("./internal-service-dictionaries.controller");
const internal_service_catalog_suggestions_controller_1 = require("./internal-service-catalog-suggestions.controller");
const organizations_module_1 = require("../organizations/organizations.module");
const users_module_1 = require("../users/users.module");
const orders_module_1 = require("../orders/orders.module");
const reference_module_1 = require("../reference/reference.module");
const chats_module_1 = require("../chats/chats.module");
const internal_client_cars_controller_1 = require("./internal-client-cars.controller");
const internal_support_chats_controller_1 = require("./internal-support-chats.controller");
let InternalModule = class InternalModule {
};
exports.InternalModule = InternalModule;
exports.InternalModule = InternalModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([internal_operator_entity_1.InternalOperator, audit_log_entity_1.AuditLog]),
            passport_1.PassportModule,
            jwt_1.JwtModule.registerAsync({
                imports: [config_1.ConfigModule],
                useFactory: (config) => ({
                    secret: config.get('JWT_SECRET') || 'dev-secret',
                    signOptions: { expiresIn: config.get('JWT_EXPIRES_IN') || '7d' },
                }),
                inject: [config_1.ConfigService],
            }),
            organizations_module_1.OrganizationsModule,
            users_module_1.UsersModule,
            orders_module_1.OrdersModule,
            reference_module_1.ReferenceModule,
            chats_module_1.ChatsModule,
        ],
        controllers: [
            internal_auth_controller_1.InternalAuthController,
            internal_organizations_controller_1.InternalOrganizationsController,
            internal_users_controller_1.InternalUsersController,
            internal_orders_controller_1.InternalOrdersController,
            internal_client_cars_controller_1.InternalClientCarsController,
            internal_support_chats_controller_1.InternalSupportChatsController,
            internal_reference_controller_1.InternalReferenceController,
            internal_audit_controller_1.InternalAuditController,
            internal_subscriptions_controller_1.InternalSubscriptionsController,
            internal_service_dictionaries_controller_1.InternalServiceDictionariesController,
            internal_service_catalog_suggestions_controller_1.InternalServiceCatalogSuggestionsController,
        ],
        providers: [internal_auth_service_1.InternalAuthService, internal_jwt_strategy_1.InternalJwtStrategy, internal_seed_service_1.InternalSeedService, internal_audit_service_1.InternalAuditService],
        exports: [internal_auth_service_1.InternalAuthService],
    })
], InternalModule);
//# sourceMappingURL=internal.module.js.map