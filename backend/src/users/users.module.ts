import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Chat } from '../chats/chat.entity';
import { Order } from '../orders/order.entity';
import { User } from './user.entity';
import { ClientCar } from './client-car.entity';
import { UserClientHiddenCar } from './user-client-hidden-car.entity';
import { UserOrganizationMembership } from './user-organization-membership.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { UsersController } from './users.controller';
import { ClientCarsController } from './client-cars.controller';
import { UsersService } from './users.service';
import { ClientCarsService } from './client-cars.service';
import { OrganizationsModule } from '../organizations/organizations.module';
import { OrganizationInvitation } from '../organizations/organization-invitation.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      ClientCar,
      UserClientHiddenCar,
      UserOrganizationMembership,
      StaffMember,
      OrganizationInvitation,
      Chat,
      Order,
    ]),
    forwardRef(() => OrganizationsModule),
  ],
  controllers: [UsersController, ClientCarsController],
  providers: [UsersService, ClientCarsService],
  exports: [UsersService, ClientCarsService],
})
export class UsersModule {}
