"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DatabaseModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const organization_entity_1 = require("../organizations/organization.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const master_schedule_entity_1 = require("../organizations/master-schedule.entity");
const organization_settings_entity_1 = require("../organizations/organization-settings.entity");
const user_entity_1 = require("../users/user.entity");
const order_entity_1 = require("../orders/order.entity");
const order_item_entity_1 = require("../orders/order-item.entity");
const chat_entity_1 = require("../chats/chat.entity");
const chat_message_entity_1 = require("../chats/chat-message.entity");
const car_brand_entity_1 = require("../reference/car-brand.entity");
const car_model_entity_1 = require("../reference/car-model.entity");
const car_generation_entity_1 = require("../reference/car-generation.entity");
const seed_service_1 = require("./seed.service");
let DatabaseModule = class DatabaseModule {
};
exports.DatabaseModule = DatabaseModule;
exports.DatabaseModule = DatabaseModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                organization_entity_1.Organization,
                staff_member_entity_1.StaffMember,
                master_schedule_entity_1.MasterSchedule,
                organization_settings_entity_1.OrganizationSettings,
                user_entity_1.User,
                order_entity_1.Order,
                order_item_entity_1.OrderItem,
                chat_entity_1.Chat,
                chat_message_entity_1.ChatMessage,
                car_brand_entity_1.CarBrand,
                car_model_entity_1.CarModel,
                car_generation_entity_1.CarGeneration,
            ]),
        ],
        providers: [seed_service_1.SeedService],
        exports: [seed_service_1.SeedService],
    })
], DatabaseModule);
//# sourceMappingURL=database.module.js.map