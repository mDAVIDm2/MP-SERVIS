import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Chat } from './chat.entity';
import { ChatMessage } from './chat-message.entity';
import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { OrdersModule } from '../orders/orders.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { Organization } from '../organizations/organization.entity';
import { MediaModule } from '../media/media.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { ChatMessageAttachment } from './chat-message-attachment.entity';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Chat, ChatMessage, ChatMessageAttachment, Order, OrderItem, Organization]),
    forwardRef(() => OrdersModule),
    forwardRef(() => NotificationsModule),
    MediaModule,
    SubscriptionsModule,
    UsersModule,
  ],
  controllers: [ChatsController],
  providers: [ChatsService],
  exports: [ChatsService],
})
export class ChatsModule {}
