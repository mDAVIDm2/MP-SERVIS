import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Organization } from '../organizations/organization.entity';

/** Запрос СТО на добавление услуги в общий справочник (для разработчиков). */
@Entity('service_catalog_suggestions')
export class ServiceCatalogSuggestion {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organization_id' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ name: 'requested_name', type: 'varchar', length: 512 })
  requestedName: string;

  @Column({ name: 'category_hint', type: 'varchar', length: 256, nullable: true })
  categoryHint: string | null;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  /** pending | reviewed */
  @Column({ type: 'varchar', length: 32, default: 'pending' })
  status: string;

  @Column({ name: 'reviewed_at', type: 'timestamp', nullable: true })
  reviewedAt: Date | null;

  /** Заметка внутреннего оператора (не видна СТО). */
  @Column({ name: 'review_note', type: 'text', nullable: true })
  reviewNote: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
