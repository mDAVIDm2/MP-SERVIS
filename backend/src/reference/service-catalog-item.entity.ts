import { Entity, Column, PrimaryColumn } from 'typeorm';

/** Единый справочник услуг MP-Servis: СТО выбирают позиции из списка для единообразия названий. */
@Entity('service_catalog_items')
export class ServiceCatalogItem {
  @PrimaryColumn({ type: 'varchar', length: 96 })
  id: string;

  @Column({ name: 'category_key', type: 'varchar', length: 64 })
  categoryKey: string;

  @Column({ name: 'category_name', type: 'varchar', length: 160 })
  categoryName: string;

  /** Порядок категории в каталоге (одинаковый у всех позиций с тем же category_key). */
  @Column({ name: 'category_sort_order', type: 'int', default: 0 })
  categorySortOrder: number;

  @Column({ type: 'varchar', length: 512 })
  name: string;

  @Column({ name: 'default_duration_minutes', type: 'int', default: 60 })
  defaultDurationMinutes: number;

  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @Column({ name: 'required_skill', type: 'varchar', length: 32, nullable: true })
  requiredSkill: string | null;

  /** Коды business_kind организаций, которым доступна позиция в справочнике. */
  @Column({ name: 'allowed_business_kinds', type: 'jsonb', default: () => `'["sto"]'` })
  allowedBusinessKinds: string[];
}
