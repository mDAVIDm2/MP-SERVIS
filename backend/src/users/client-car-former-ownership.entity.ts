import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index, Unique } from 'typeorm';

/** Бывший владелец: read-only доступ к карточке авто до «Забыть». */
@Entity('client_car_former_ownership')
@Unique('UQ_former_user_car', ['userId', 'carId'])
@Index('IDX_former_user_id', ['userId'])
@Index('IDX_former_car_id', ['carId'])
export class ClientCarFormerOwnership {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'car_id', type: 'varchar', length: 64 })
  carId: string;

  @Column({ name: 'transfer_id', type: 'uuid', nullable: true })
  transferId: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
