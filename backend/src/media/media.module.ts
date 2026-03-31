import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MediaAsset } from './media-asset.entity';
import { OrderMedia } from './order-media.entity';
import { ChatMessageAttachment } from '../chats/chat-message-attachment.entity';
import { LocalStorageService } from './local-storage.service';
import { MediaService } from './media.service';

@Module({
  imports: [TypeOrmModule.forFeature([MediaAsset, OrderMedia, ChatMessageAttachment])],
  providers: [LocalStorageService, MediaService],
  exports: [MediaService, LocalStorageService],
})
export class MediaModule {}
