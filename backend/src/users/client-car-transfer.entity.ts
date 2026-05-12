import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { ClientCar } from './client-car.entity';

export type ClientCarTransferStatus = 'pending' | 'accepted' | 'rejected' | 'cancelled';

@Entity('client_car_transfers')
export class ClientCarTransfer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'car_id', type: 'varchar', length: 64 })
  carId: string;

  @ManyToOne(() => ClientCar, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'car_id' })
  car: ClientCar;

  @Column({ name: 'from_user_id', type: 'uuid' })
  fromUserId: string;

  /** Получатель, если аккаунт найден по номеру; иначе заполняется при первом входе с этим номером. */
  @Column({ name: 'to_user_id', type: 'uuid', nullable: true })
  toUserId: string | null;

  /** Нормализованные цифры телефона (как в заказах): 7XXXXXXXXXX. */
  @Column({ name: 'to_phone_norm', type: 'varchar', length: 20 })
  toPhoneNorm: string;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: ClientCarTransferStatus;

  /** Опции передачи (история заказов, подсказки для UI). */
  @Column({ type: 'jsonb', nullable: true })
  options: Record<string, unknown> | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
