import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Organization } from './organization.entity';

@Entity('organization_subscriptions')
export class OrganizationSubscription {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ name: 'start_date', type: 'date' })
  startDate: Date;

  @Column({ name: 'end_date', type: 'date' })
  endDate: Date;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  /** active | deactivated | expired */
  @Column({ type: 'varchar', length: 32, default: 'active' })
  status: string;

  /**
   * Ключ тарифа: solo | team | business | pro | network.
   * Лимиты задаются в subscription/plan-definitions.ts (единый источник правды).
   */
  @Column({ name: 'plan_key', type: 'varchar', length: 32, default: 'team' })
  planKey: string;

  /**
   * Индивидуальные лимиты поверх тарифа (Control Center). Частичный объект;
   * отсутствующие поля берутся из plan_key. null — без отклонений от тарифа.
   */
  @Column({ name: 'limits_override', type: 'jsonb', nullable: true })
  limitsOverride: Record<string, unknown> | null;
}
