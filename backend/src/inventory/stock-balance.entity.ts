import { Column, Entity, JoinColumn, ManyToOne, OneToOne, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { Organization } from '../organizations/organization.entity';
import { InventoryItem } from './inventory-item.entity';

@Entity('stock_balances')
export class StockBalance {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @OneToOne(() => InventoryItem, (i) => i.stockBalance, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'inventory_item_id' })
  inventoryItem: InventoryItem;

  @Column({ name: 'quantity_total', type: 'double precision', default: 0 })
  quantityTotal: number;

  @Column({ name: 'quantity_reserved', type: 'double precision', default: 0 })
  quantityReserved: number;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  quantityAvailable(): number {
    return this.quantityTotal - this.quantityReserved;
  }
}
