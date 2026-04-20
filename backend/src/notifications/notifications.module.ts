import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PushDevice } from './push-device.entity';
import { Notification } from './notification.entity';
import { User } from '../users/user.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { UsersModule } from '../users/users.module';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { FcmPushService } from './fcm-push.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([PushDevice, Notification, User, StaffMember]),
    forwardRef(() => UsersModule),
  ],
  controllers: [NotificationsController],
  providers: [FcmPushService, NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
