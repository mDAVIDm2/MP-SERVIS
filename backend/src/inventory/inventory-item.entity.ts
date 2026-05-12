import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Organization } from '../organizations/organization.entity';
import { StockBalance } from './stock-balance.entity';

export type InventoryItemType = 'part' | 'material' | 'consumable' | 'tool';

@Entity('inventory_items')
export class InventoryItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ name: 'item_type', type: 'varchar', length: 24, default: 'material' })
  itemType: InventoryItemType;

  @Column({ type: 'varchar', length: 128, nullable: true })
  category: string | null;

  @Column({ type: 'varchar', length: 512 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 256, nullable: true })
  brand: string | null;

  @Column({ type: 'varchar', length: 128, nullable: true })
  article: string | null;

  @Column({ type: 'varchar', length: 128, nullable: true })
  sku: string | null;

  @Column({ type: 'varchar', length: 128, nullable: true })
  barcode: string | null;

  @Column({ type: 'varchar', length: 32, default: 'pcs' })
  unit: string;

  @Column({ name: 'purchase_price_kopecks', type: 'int', nullable: true })
  purchasePriceKopecks: number | null;

  @Column({ name: 'sale_price_kopecks', type: 'int', nullable: true })
  salePriceKopecks: number | null;

  @Column({ name: 'min_stock', type: 'double precision', default: 0 })
  minStock: number;

  @Column({ name: 'track_stock', type: 'boolean', default: true })
  trackStock: boolean;

  @Column({ name: 'allow_fractional', type: 'boolean', default: false })
  allowFractional: boolean;

  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive: boolean;

  @Column({ name: 'external_id', type: 'varchar', length: 128, nullable: true })
  externalId: string | null;

  @Column({ name: 'external_system', type: 'varchar', length: 64, nullable: true })
  externalSystem: string | null;

  @Column({ name: 'sync_status', type: 'varchar', length: 32, nullable: true })
  syncStatus: string | null;

  @Column({ name: 'last_synced_at', type: 'timestamptz', nullable: true })
  lastSyncedAt: Date | null;

  @Column({ name: 'created_by_user_id', type: 'uuid', nullable: true })
  createdByUserId: string | null;

  @Column({ name: 'updated_by_user_id', type: 'uuid', nullable: true })
  updatedByUserId: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @OneToOne(() => StockBalance, (b) => b.inventoryItem)
  stockBalance?: StockBalance;
}
