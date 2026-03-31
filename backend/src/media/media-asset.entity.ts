import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
} from 'typeorm';
import { Organization } from '../organizations/organization.entity';
import { User } from '../users/user.entity';
import { Chat } from '../chats/chat.entity';

@Entity('media_assets')
export class MediaAsset {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Для заказов и медиа организации; NULL — только чат поддержки / без привязки к СТО. */
  @Column({ name: 'organization_id', type: 'uuid', nullable: true })
  organizationId: string | null;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization | null;

  /** Контекст чата (вложения в сообщениях). При удалении чата — каскадное удаление ассетов. */
  @Column({ name: 'chat_id', type: 'uuid', nullable: true })
  chatId: string | null;

  @ManyToOne(() => Chat, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'chat_id' })
  chat: Chat | null;

  @Column({ name: 'uploaded_by_user_id', type: 'uuid', nullable: true })
  uploadedByUserId: string | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'uploaded_by_user_id' })
  uploadedByUser: User | null;

  /** image | video | document */
  @Column({ name: 'media_type', type: 'varchar', length: 16 })
  mediaType: string;

  @Column({ name: 'mime_type', type: 'varchar', length: 128 })
  mimeType: string;

  @Column({ name: 'storage_provider', type: 'varchar', length: 16, default: 'local' })
  storageProvider: string;

  @Column({ name: 'storage_key', type: 'varchar', length: 512, unique: true })
  storageKey: string;

  @Column({ name: 'original_filename', type: 'varchar', length: 255, nullable: true })
  originalFilename: string | null;

  @Column({ name: 'size_bytes', type: 'int', default: 0 })
  sizeBytes: number;

  @Column({ name: 'width', type: 'int', nullable: true })
  width: number | null;

  @Column({ name: 'height', type: 'int', nullable: true })
  height: number | null;

  @Column({ name: 'duration_sec', type: 'int', nullable: true })
  durationSec: number | null;

  /** ready | processing | failed */
  @Column({ type: 'varchar', length: 16, default: 'ready' })
  status: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
