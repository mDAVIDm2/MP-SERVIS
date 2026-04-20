"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsersModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const chat_entity_1 = require("../chats/chat.entity");
const order_entity_1 = require("../orders/order.entity");
const user_entity_1 = require("./user.entity");
const client_car_entity_1 = require("./client-car.entity");
const user_client_hidden_car_entity_1 = require("./user-client-hidden-car.entity");
const user_organization_membership_entity_1 = require("./user-organization-membership.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const users_controller_1 = require("./users.controller");
const client_cars_controller_1 = require("./client-cars.controller");
const users_service_1 = require("./users.service");
const client_cars_service_1 = require("./client-cars.service");
const organizations_module_1 = require("../organizations/organizations.module");
const organization_invitation_entity_1 = require("../organizations/organization-invitation.entity");
let UsersModule = class UsersModule {
};
exports.UsersModule = UsersModule;
exports.UsersModule = UsersModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                user_entity_1.User,
                client_car_entity_1.ClientCar,
                user_client_hidden_car_entity_1.UserClientHiddenCar,
                user_organization_membership_entity_1.UserOrganizationMembership,
                staff_member_entity_1.StaffMember,
                organization_invitation_entity_1.OrganizationInvitation,
                chat_entity_1.Chat,
                order_entity_1.Order,
            ]),
            (0, common_1.forwardRef)(() => organizations_module_1.OrganizationsModule),
        ],
        controllers: [users_controller_1.UsersController, client_cars_controller_1.ClientCarsController],
        providers: [users_service_1.UsersService, client_cars_service_1.ClientCarsService],
        exports: [users_service_1.UsersService, client_cars_service_1.ClientCarsService],
    })
], UsersModule);
//# sourceMappingURL=users.module.js.map