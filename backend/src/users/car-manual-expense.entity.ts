import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { ClientCar } from './client-car.entity';

@Entity('car_manual_expenses')
export class CarManualExpense {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'car_id', type: 'varchar', length: 64 })
  carId: string;

  @ManyToOne(() => ClientCar, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'car_id', referencedColumnName: 'id' })
  car: ClientCar;

  /** Идемпотентность: совпадает с локальным id клиента (clientRecordId). */
  @Column({ name: 'client_local_id', type: 'varchar', length: 120 })
  clientLocalId: string;

  @Column({ type: 'varchar', length: 40 })
  kind: string;

  @Column({ type: 'timestamptz' })
  date: Date;

  @Column({ name: 'price_kopecks', type: 'int' })
  priceKopecks: number;

  @Column({ name: 'fuel_type', type: 'varchar', length: 40, nullable: true })
  fuelType: string | null;

  @Column({ type: 'numeric', precision: 14, scale: 4, nullable: true })
  liters: string | null;

  @Column({ name: 'price_per_liter_kopecks', type: 'int', nullable: true })
  pricePerLiterKopecks: number | null;

  @Column({ name: 'odometer_km', type: 'int', nullable: true })
  odometerKm: number | null;

  @Column({ name: 'fuel_station_name', type: 'text', nullable: true })
  fuelStationName: string | null;

  @Column({ name: 'full_tank', type: 'boolean', nullable: true })
  fullTank: boolean | null;

  @Column({ name: 'preset_id', type: 'varchar', length: 100, nullable: true })
  presetId: string | null;

  @Column({ name: 'custom_title', type: 'text', nullable: true })
  customTitle: string | null;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ name: 'expense_group_id', type: 'varchar', length: 100, nullable: true })
  expenseGroupId: string | null;

  @Column({ name: 'expense_sub_id', type: 'varchar', length: 100, nullable: true })
  expenseSubId: string | null;

  @Column({ name: 'expense_category_id', type: 'varchar', length: 100, nullable: true })
  expenseCategoryId: string | null;

  @Column({ name: 'expense_item_title', type: 'varchar', length: 200, nullable: true })
  expenseItemTitle: string | null;

  @Column({ name: 'analytics_operation_name', type: 'varchar', length: 100, nullable: true })
  analyticsOperationName: string | null;

  @Column({ name: 'material_price_kopecks', type: 'int', nullable: true })
  materialPriceKopecks: number | null;

  @Column({ name: 'labor_price_kopecks', type: 'int', nullable: true })
  laborPriceKopecks: number | null;

  @Column({ name: 'place_name', type: 'text', nullable: true })
  placeName: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;

  @Column({ name: 'client_updated_at', type: 'timestamptz', nullable: true })
  clientUpdatedAt: Date | null;

  @Column({ name: 'device_id', type: 'varchar', length: 128, nullable: true })
  deviceId: string | null;

  @Column({ type: 'int', default: 1 })
  version: number;
}
