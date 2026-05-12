import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Order } from './order.entity';
import { OrderItem } from './order-item.entity';
import { OrderPhoto } from './order-photo.entity';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { ChatsModule } from '../chats/chats.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { StaffMember } from '../organizations/staff-member.entity';
import { Chat } from '../chats/chat.entity';
import { ChatMessage } from '../chats/chat-message.entity';
import { OrganizationsModule } from '../organizations/organizations.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { MediaModule } from '../media/media.module';
import { UsersModule } from '../users/users.module';
import { UserClientHiddenCar } from '../users/user-client-hidden-car.entity';
import { ClientCar } from '../users/client-car.entity';
import { InventoryModule } from '../inventory/inventory.module';
import { OrderInventoryLine } from './order-inventory-line.entity';

@Module({
  imports: [
    InventoryModule,
    MediaModule,
    UsersModule,
    SubscriptionsModule,
    TypeOrmModule.forFeature([
      Order,
      OrderItem,
      OrderPhoto,
      OrderInventoryLine,
      StaffMember,
      Chat,
      ChatMessage,
      UserClientHiddenCar,
      ClientCar,
    ]),
    ChatsModule,
    NotificationsModule,
    OrganizationsModule,
  ],
  controllers: [OrdersController],
  providers: [OrdersService],
  exports: [OrdersService],
})
export class OrdersModule {}
