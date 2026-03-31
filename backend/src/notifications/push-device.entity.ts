import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { User } from '../users/user.entity';

@Entity('push_devices')
export class PushDevice {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'device_token' })
  deviceToken: string;

  @Column({ type: 'varchar', length: 20, default: 'android' })
  platform: string;

  /** `client` — FCM из проекта клиента; `business` — из проекта СТО (другой Firebase). */
  @Column({ name: 'fcm_app', type: 'varchar', length: 16, default: 'client' })
  fcmApp: string;
}
