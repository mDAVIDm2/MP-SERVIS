import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

/** planned → reserved | not_enough_stock → released | written_off | cancelled */
export type OrderInventoryLineStatus =
  | 'planned'
  | 'reserved'
  | 'not_enough_stock'
  | 'released'
  | 'written_off'
  | 'cancelled';

@Entity('order_inventory_lines')
export class OrderInventoryLine {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @Column({ name: 'order_id', type: 'uuid' })
  orderId: string;

  @Column({ name: 'inventory_item_id', type: 'uuid' })
  inventoryItemId: string;

  @Column({ name: 'order_item_id', type: 'uuid', nullable: true })
  orderItemId: string | null;

  @Column({ name: 'quantity_planned', type: 'double precision' })
  quantityPlanned: number;

  @Column({ name: 'quantity_reserved', type: 'double precision', default: 0 })
  quantityReserved: number;

  @Column({ type: 'varchar', length: 32, default: 'pcs' })
  unit: string;

  @Column({ type: 'varchar', length: 32, default: 'planned' })
  status: OrderInventoryLineStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
