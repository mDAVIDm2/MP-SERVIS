import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

export type NotificationType =
  | 'pending_car_approved'
  | 'pending_car_rejected'
  | 'pending_car_suggested'
  | 'order'
  | 'chat'
  | 'general'
  | 'security'
  /** Приглашение в организацию (бизнес-приложение). */
  | 'organization_invite'
  /** Передача автомобиля между клиентами (гараж). */
  | 'car_transfer_request'
  | 'car_transfer_result';

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'varchar', length: 64 })
  userId: string;

  /** Идентификатор машины в гараже пользователя (для фильтрации по машине). */
  @Column({ name: 'car_id', type: 'varchar', length: 64, nullable: true })
  carId: string | null;

  @Column({ type: 'varchar', length: 64 })
  type: NotificationType;

  @Column({ type: 'varchar', length: 256 })
  title: string;

  @Column({ type: 'text', nullable: true })
  body: string | null;

  @Column({ name: 'is_read', type: 'boolean', default: false })
  isRead: boolean;

  /** JSON: для pending_car_* — brandId, modelId, generationId, brandName, modelName, generationName. */
  @Column({ type: 'jsonb', nullable: true })
  payload: Record<string, unknown> | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
