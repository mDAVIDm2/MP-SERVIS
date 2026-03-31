import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Organization } from '../organizations/organization.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { MasterSchedule } from '../organizations/master-schedule.entity';
import { OrganizationSettings } from '../organizations/organization-settings.entity';
import { User } from '../users/user.entity';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { Chat } from '../chats/chat.entity';
import { ChatMessage } from '../chats/chat-message.entity';
import { CarBrand } from '../reference/car-brand.entity';
import { CarModel } from '../reference/car-model.entity';
import { CarGeneration } from '../reference/car-generation.entity';
import { SeedService } from './seed.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Organization,
      StaffMember,
      MasterSchedule,
      OrganizationSettings,
      User,
      Order,
      OrderItem,
      Chat,
      ChatMessage,
      CarBrand,
      CarModel,
      CarGeneration,
    ]),
  ],
  providers: [SeedService],
  exports: [SeedService],
})
export class DatabaseModule {}
