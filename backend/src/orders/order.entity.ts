import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { Organization } from '../organizations/organization.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { OrderItem } from './order-item.entity';

export type OrderStatus =
  | 'pending_confirmation'
  | 'confirmed'
  | 'in_progress'
  | 'pending_approval'
  | 'completed'
  | 'done'
  | 'cancelled';

@Entity('orders')
export class Order {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'order_number', unique: true })
  orderNumber: string;

  @Column({ name: 'car_id' })
  carId: string;

  @Column({ name: 'car_info', default: '' })
  carInfo: string;

  @Column({ name: 'vin', type: 'varchar', length: 32, nullable: true })
  vin: string | null;

  @Column({ name: 'license_plate', type: 'varchar', length: 20, nullable: true })
  licensePlate: string | null;

  @Column({ name: 'body_type', type: 'varchar', length: 64, nullable: true })
  bodyType: string | null;

  @Column({ name: 'color', type: 'varchar', length: 64, nullable: true })
  color: string | null;

  @Column({ name: 'mileage', type: 'int', nullable: true })
  mileage: number | null;

  @Column({ name: 'engine_type', type: 'varchar', length: 64, nullable: true })
  engineType: string | null;

  @Column({ name: 'client_name', type: 'varchar', length: 255, nullable: true })
  clientName: string | null;

  @Column({ name: 'client_phone', type: 'varchar', length: 32, nullable: true })
  clientPhone: string | null;

  @Column({ type: 'varchar', length: 30, default: 'pending_confirmation' })
  status: OrderStatus;

  /** Статус заказа до перехода в pending_approval (для отката при отказе клиента от доп. работ). */
  @Column({ name: 'previous_status', type: 'varchar', length: 30, nullable: true })
  previousStatus: string | null;

  /**
   * Первый момент, когда заказ вышел из ожидания подтверждения записи (в confirmed или in_progress).
   * Используется для лимита тарифа по числу подтверждённых заказов за месяц (часовой пояс организации).
   */
  @Column({ name: 'first_confirmed_at', type: 'timestamptz', nullable: true })
  firstConfirmedAt: Date | null;

  @Column({ name: 'date_time', type: 'timestamptz' })
  dateTime: Date;

  @Column({ name: 'planned_start_time', type: 'timestamptz', nullable: true })
  plannedStartTime: Date | null;

  @Column({ name: 'planned_end_time', type: 'timestamptz', nullable: true })
  plannedEndTime: Date | null;

  @Column({ name: 'actual_start_time', type: 'timestamptz', nullable: true })
  actualStartTime: Date | null;

  @Column({ name: 'actual_end_time', type: 'timestamptz', nullable: true })
  actualEndTime: Date | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  comment: string | null;

  @Column({ name: 'master_id', type: 'uuid', nullable: true })
  masterId: string | null;

  /** Идентификатор поста из настроек slots.bays (именованные боксы). */
  @Column({ name: 'bay_id', type: 'varchar', length: 64, nullable: true })
  bayId: string | null;

  @Column({ name: 'organization_id' })
  organizationId: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @ManyToOne(() => StaffMember, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'master_id' })
  master: StaffMember | null;

  @OneToMany(() => OrderItem, (i) => i.order, { cascade: true })
  items: OrderItem[];
}
