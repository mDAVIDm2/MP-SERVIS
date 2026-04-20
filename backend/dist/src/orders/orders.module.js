"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrdersModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const order_entity_1 = require("./order.entity");
const order_item_entity_1 = require("./order-item.entity");
const order_photo_entity_1 = require("./order-photo.entity");
const orders_controller_1 = require("./orders.controller");
const orders_service_1 = require("./orders.service");
const chats_module_1 = require("../chats/chats.module");
const notifications_module_1 = require("../notifications/notifications.module");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const chat_entity_1 = require("../chats/chat.entity");
const chat_message_entity_1 = require("../chats/chat-message.entity");
const organizations_module_1 = require("../organizations/organizations.module");
const subscriptions_module_1 = require("../subscriptions/subscriptions.module");
const media_module_1 = require("../media/media.module");
const users_module_1 = require("../users/users.module");
const user_client_hidden_car_entity_1 = require("../users/user-client-hidden-car.entity");
let OrdersModule = class OrdersModule {
};
exports.OrdersModule = OrdersModule;
exports.OrdersModule = OrdersModule = __decorate([
    (0, common_1.Module)({
        imports: [
            media_module_1.MediaModule,
            users_module_1.UsersModule,
            subscriptions_module_1.SubscriptionsModule,
            typeorm_1.TypeOrmModule.forFeature([order_entity_1.Order, order_item_entity_1.OrderItem, order_photo_entity_1.OrderPhoto, staff_member_entity_1.StaffMember, chat_entity_1.Chat, chat_message_entity_1.ChatMessage, user_client_hidden_car_entity_1.UserClientHiddenCar]),
            chats_module_1.ChatsModule,
            notifications_module_1.NotificationsModule,
            organizations_module_1.OrganizationsModule,
        ],
        controllers: [orders_controller_1.OrdersController],
        providers: [orders_service_1.OrdersService],
        exports: [orders_service_1.OrdersService],
    })
], OrdersModule);
//# sourceMappingURL=orders.module.js.map