import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
} from 'typeorm';
import { ChatMessage } from './chat-message.entity';
import { MediaAsset } from '../media/media-asset.entity';

@Entity('chat_message_attachments')
export class ChatMessageAttachment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'message_id', type: 'uuid' })
  messageId: string;

  @ManyToOne(() => ChatMessage, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'message_id' })
  message: ChatMessage;

  @Column({ name: 'media_asset_id', type: 'uuid', unique: true })
  mediaAssetId: string;

  @ManyToOne(() => MediaAsset, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'media_asset_id' })
  mediaAsset: MediaAsset;

  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
