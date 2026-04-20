"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const schedule_1 = require("@nestjs/schedule");
const throttler_1 = require("@nestjs/throttler");
const typeorm_1 = require("@nestjs/typeorm");
const path_1 = require("path");
const auth_module_1 = require("./auth/auth.module");
const users_module_1 = require("./users/users.module");
const organizations_module_1 = require("./organizations/organizations.module");
const orders_module_1 = require("./orders/orders.module");
const chats_module_1 = require("./chats/chats.module");
const notifications_module_1 = require("./notifications/notifications.module");
const booking_module_1 = require("./booking/booking.module");
const database_module_1 = require("./database/database.module");
const reference_module_1 = require("./reference/reference.module");
const internal_module_1 = require("./internal/internal.module");
const typeorm_config_1 = require("./database/typeorm.config");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({
                isGlobal: true,
                envFilePath: (0, path_1.join)(process.cwd(), '.env'),
            }),
            schedule_1.ScheduleModule.forRoot(),
            typeorm_1.TypeOrmModule.forRootAsync({
                imports: [config_1.ConfigModule],
                useFactory: (config) => (0, typeorm_config_1.getTypeOrmModuleOptions)(config.get('DATABASE_URL') ?? undefined),
                inject: [config_1.ConfigService],
            }),
            throttler_1.ThrottlerModule.forRoot({
                throttlers: [{ name: 'default', ttl: 60000, limit: 120 }],
            }),
            database_module_1.DatabaseModule,
            reference_module_1.ReferenceModule,
            internal_module_1.InternalModule,
            auth_module_1.AuthModule,
            users_module_1.UsersModule,
            organizations_module_1.OrganizationsModule,
            orders_module_1.OrdersModule,
            chats_module_1.ChatsModule,
            notifications_module_1.NotificationsModule,
            booking_module_1.BookingModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map