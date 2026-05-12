import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Chat } from '../chats/chat.entity';
import { Order } from '../orders/order.entity';
import { User } from './user.entity';
import { ClientCar } from './client-car.entity';
import { ClientCarTransfer } from './client-car-transfer.entity';
import { ClientCarFormerOwnership } from './client-car-former-ownership.entity';
import { UserClientHiddenCar } from './user-client-hidden-car.entity';
import { UserOrganizationMembership } from './user-organization-membership.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { UsersController } from './users.controller';
import { ClientCarsController } from './client-cars.controller';
import { CarTransfersController } from './car-transfers.controller';
import { UsersService } from './users.service';
import { ClientCarsService } from './client-cars.service';
import { CarTransferService } from './car-transfer.service';
import { OrganizationsModule } from '../organizations/organizations.module';
import { OrganizationInvitation } from '../organizations/organization-invitation.entity';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      ClientCar,
      ClientCarTransfer,
      ClientCarFormerOwnership,
      UserClientHiddenCar,
      UserOrganizationMembership,
      StaffMember,
      OrganizationInvitation,
      Chat,
      Order,
    ]),
    forwardRef(() => OrganizationsModule),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [UsersController, ClientCarsController, CarTransfersController],
  providers: [UsersService, ClientCarsService, CarTransferService],
  exports: [UsersService, ClientCarsService, CarTransferService],
})
export class UsersModule {}
