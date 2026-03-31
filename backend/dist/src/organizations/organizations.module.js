"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrganizationsModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const organization_entity_1 = require("./organization.entity");
const organization_subscription_entity_1 = require("./organization-subscription.entity");
const staff_member_entity_1 = require("./staff-member.entity");
const master_schedule_entity_1 = require("./master-schedule.entity");
const organization_settings_entity_1 = require("./organization-settings.entity");
const organizations_controller_1 = require("./organizations.controller");
const catalog_controller_1 = require("./catalog.controller");
const organizations_service_1 = require("./organizations.service");
const service_catalog_item_entity_1 = require("../reference/service-catalog-item.entity");
const reference_module_1 = require("../reference/reference.module");
const subscriptions_module_1 = require("../subscriptions/subscriptions.module");
const organization_invitation_entity_1 = require("./organization-invitation.entity");
const users_module_1 = require("../users/users.module");
const notifications_module_1 = require("../notifications/notifications.module");
const transactional_mail_service_1 = require("../mail/transactional-mail.service");
const organization_invitations_scheduler_1 = require("./organization-invitations.scheduler");
let OrganizationsModule = class OrganizationsModule {
};
exports.OrganizationsModule = OrganizationsModule;
exports.OrganizationsModule = OrganizationsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            subscriptions_module_1.SubscriptionsModule,
            typeorm_1.TypeOrmModule.forFeature([
                organization_entity_1.Organization,
                organization_subscription_entity_1.OrganizationSubscription,
                staff_member_entity_1.StaffMember,
                master_schedule_entity_1.MasterSchedule,
                organization_settings_entity_1.OrganizationSettings,
                organization_invitation_entity_1.OrganizationInvitation,
                service_catalog_item_entity_1.ServiceCatalogItem,
            ]),
            (0, common_1.forwardRef)(() => reference_module_1.ReferenceModule),
            (0, common_1.forwardRef)(() => users_module_1.UsersModule),
            (0, common_1.forwardRef)(() => notifications_module_1.NotificationsModule),
        ],
        controllers: [organizations_controller_1.OrganizationsController, catalog_controller_1.CatalogController],
        providers: [organizations_service_1.OrganizationsService, organization_invitations_scheduler_1.OrganizationInvitationsScheduler, transactional_mail_service_1.TransactionalMailService],
        exports: [organizations_service_1.OrganizationsService],
    })
], OrganizationsModule);
//# sourceMappingURL=organizations.module.js.map