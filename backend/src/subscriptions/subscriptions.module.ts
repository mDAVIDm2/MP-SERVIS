import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Order } from '../orders/order.entity';
import { Organization } from '../organizations/organization.entity';
import { OrganizationSubscription } from '../organizations/organization-subscription.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { SubscriptionQuotaService } from './subscription-quota.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([Order, Organization, OrganizationSubscription, StaffMember]),
  ],
  providers: [SubscriptionQuotaService],
  exports: [SubscriptionQuotaService],
})
export class SubscriptionsModule {}
