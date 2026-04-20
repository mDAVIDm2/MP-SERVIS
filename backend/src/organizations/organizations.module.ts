import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Organization } from './organization.entity';
import { OrganizationSubscription } from './organization-subscription.entity';
import { StaffMember } from './staff-member.entity';
import { MasterSchedule } from './master-schedule.entity';
import { OrganizationSettings } from './organization-settings.entity';
import { OrganizationsController } from './organizations.controller';
import { OrganizationPublicPhotosController } from './organization-public-photos.controller';
import { CatalogController } from './catalog.controller';
import { OrganizationsService } from './organizations.service';
import { ServiceCatalogItem } from '../reference/service-catalog-item.entity';
import { User } from '../users/user.entity';
import { UserOrganizationMembership } from '../users/user-organization-membership.entity';
import { ReferenceModule } from '../reference/reference.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { OrganizationInvitation } from './organization-invitation.entity';
import { UsersModule } from '../users/users.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { TransactionalMailService } from '../mail/transactional-mail.service';
import { OrganizationInvitationsScheduler } from './organization-invitations.scheduler';

@Module({
  imports: [
    SubscriptionsModule,
    TypeOrmModule.forFeature([
      Organization,
      OrganizationSubscription,
      StaffMember,
      MasterSchedule,
      OrganizationSettings,
      OrganizationInvitation,
      ServiceCatalogItem,
      User,
      UserOrganizationMembership,
    ]),
    forwardRef(() => ReferenceModule),
    forwardRef(() => UsersModule),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [OrganizationsController, OrganizationPublicPhotosController, CatalogController],
  providers: [OrganizationsService, OrganizationInvitationsScheduler, TransactionalMailService],
  exports: [OrganizationsService],
})
export class OrganizationsModule {}
