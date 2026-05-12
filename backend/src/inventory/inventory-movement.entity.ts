import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('inventory_movements')
export class InventoryMovement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @Column({ name: 'inventory_item_id', type: 'uuid' })
  inventoryItemId: string;

  @Column({ name: 'stock_balance_id', type: 'uuid', nullable: true })
  stockBalanceId: string | null;

  @Column({ name: 'movement_type', type: 'varchar', length: 32 })
  movementType: string;

  @Column({ name: 'source_type', type: 'varchar', length: 32, default: 'manual' })
  sourceType: string;

  @Column({ type: 'double precision' })
  quantity: number;

  @Column({ type: 'varchar', length: 32, default: 'pcs' })
  unit: string;

  @Column({ name: 'quantity_before_total', type: 'double precision' })
  quantityBeforeTotal: number;

  @Column({ name: 'quantity_after_total', type: 'double precision' })
  quantityAfterTotal: number;

  @Column({ name: 'quantity_before_reserved', type: 'double precision' })
  quantityBeforeReserved: number;

  @Column({ name: 'quantity_after_reserved', type: 'double precision' })
  quantityAfterReserved: number;

  @Column({ name: 'quantity_before_available', type: 'double precision' })
  quantityBeforeAvailable: number;

  @Column({ name: 'quantity_after_available', type: 'double precision' })
  quantityAfterAvailable: number;

  @Column({ name: 'order_id', type: 'uuid', nullable: true })
  orderId: string | null;

  @Column({ name: 'order_work_item_id', type: 'uuid', nullable: true })
  orderWorkItemId: string | null;

  @Column({ name: 'order_material_item_id', type: 'uuid', nullable: true })
  orderMaterialItemId: string | null;

  @Column({ name: 'order_inventory_line_id', type: 'uuid', nullable: true })
  orderInventoryLineId: string | null;

  @Column({ name: 'purchase_order_id', type: 'uuid', nullable: true })
  purchaseOrderId: string | null;

  @Column({ name: 'actor_user_id', type: 'uuid', nullable: true })
  actorUserId: string | null;

  @Column({ name: 'actor_employee_id', type: 'uuid', nullable: true })
  actorEmployeeId: string | null;

  @Column({ name: 'actor_role', type: 'varchar', length: 24, nullable: true })
  actorRole: string | null;

  @Column({ name: 'actor_name_snapshot', type: 'varchar', length: 255, nullable: true })
  actorNameSnapshot: string | null;

  @Column({ name: 'is_automatic', type: 'boolean', default: false })
  isAutomatic: boolean;

  @Column({ name: 'automatic_reason', type: 'text', nullable: true })
  automaticReason: string | null;

  @Column({ type: 'text', nullable: true })
  reason: string | null;

  @Column({ type: 'text', nullable: true })
  comment: string | null;

  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, unknown> | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
