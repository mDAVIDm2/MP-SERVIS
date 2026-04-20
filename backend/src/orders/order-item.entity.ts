import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Order } from './order.entity';
import { StaffMember } from '../organizations/staff-member.entity';

@Entity('order_items')
export class OrderItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ name: 'price_kopecks', type: 'int', nullable: true })
  priceKopecks: number | null;

  @Column({ name: 'estimated_minutes', default: 60 })
  estimatedMinutes: number;

  @Column({ name: 'is_completed', default: false })
  isCompleted: boolean;

  @Column({ name: 'is_additional', default: false })
  isAdditional: boolean;

  /** Id строки услуги в прайсе организации (как в каталоге точки). Цена/время в заказе могут отличаться. */
  @Column({ name: 'organization_service_id', type: 'varchar', length: 64, nullable: true })
  organizationServiceId: string | null;

  /** Id позиции общего справочника (`svc_*`). Опционально, дублирует связь через прайс. */
  @Column({ name: 'catalog_item_id', type: 'varchar', length: 128, nullable: true })
  catalogItemId: string | null;

  @Column({ name: 'order_id' })
  orderId: string;

  @Column({ name: 'master_id', type: 'uuid', nullable: true })
  masterId: string | null;

  @ManyToOne(() => Order, (o) => o.items, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'order_id' })
  order: Order;

  @ManyToOne(() => StaffMember, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'master_id' })
  master: StaffMember | null;
}
