import { Entity, PrimaryColumn, Column, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { User } from './user.entity';

/** Автомобиль клиента (гараж в БД). [id] совпадает с orders.car_id при записи. */
@Entity('client_cars')
export class ClientCar {
  @PrimaryColumn({ type: 'varchar', length: 64 })
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ default: '' })
  brand: string;

  @Column({ default: '' })
  model: string;

  @Column({ type: 'varchar', length: 256, nullable: true })
  generation: string | null;

  @Column({ name: 'brand_id', type: 'int', nullable: true })
  brandId: number | null;

  @Column({ name: 'model_id', type: 'int', nullable: true })
  modelId: number | null;

  @Column({ name: 'generation_id', type: 'int', nullable: true })
  generationId: number | null;

  @Column({ type: 'int', default: 0 })
  year: number;

  @Column({ type: 'varchar', length: 128, nullable: true })
  nickname: string | null;

  @Column({ name: 'plate_number', type: 'varchar', length: 32, nullable: true })
  plateNumber: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  vin: string | null;

  @Column({ type: 'int', default: 0 })
  mileage: number;

  @Column({ name: 'engine_type', type: 'varchar', length: 64, nullable: true })
  engineType: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  transmission: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  drivetrain: string | null;

  @Column({ name: 'body_type', type: 'varchar', length: 64, nullable: true })
  bodyType: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  color: string | null;

  @Column({ name: 'photo_url', type: 'varchar', length: 1024, nullable: true })
  photoUrl: string | null;

  @Column({ name: 'merged_from_orders', default: false })
  mergedFromOrders: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
