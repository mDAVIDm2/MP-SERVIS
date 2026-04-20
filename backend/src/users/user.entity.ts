import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Organization } from '../organizations/organization.entity';

export type BusinessRole = 'owner' | 'admin' | 'master' | 'solo';

/** Раздельные аккаунты клиент / бизнес (см. миграцию UserAccountRealm). */
export type AccountRealm = 'business' | 'client';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Телефон (может быть неподтверждённым — см. phoneVerifiedAt). Уникален среди непустых значений (partial index). */
  @Column({ type: 'varchar', length: 32, nullable: true })
  phone: string | null;

  @Column({ name: 'phone_verified_at', type: 'timestamptz', nullable: true })
  phoneVerifiedAt: Date | null;

  @Column({ type: 'varchar', length: 320, nullable: true })
  email: string | null;

  @Column({ name: 'email_verified_at', type: 'timestamptz', nullable: true })
  emailVerifiedAt: Date | null;

  @Column({ default: '' })
  name: string;

  @Column({ name: 'account_realm', type: 'varchar', length: 16, default: 'business' })
  accountRealm: AccountRealm;

  @Column({ name: 'avatar_url', type: 'varchar', length: 1024, nullable: true })
  avatarUrl: string | null;

  @Column({ type: 'varchar', length: 20, default: 'solo' })
  role: BusinessRole;

  @Column({ name: 'organization_id', type: 'uuid', nullable: true })
  organizationId: string | null;

  @ManyToOne(() => Organization, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization | null;

  /** JSON: настройки уведомлений клиентского приложения (push, типы). */
  @Column({ name: 'notification_preferences', type: 'jsonb', nullable: true })
  notificationPreferences: Record<string, unknown> | null;

  /** Синхронизируемое состояние клиентского приложения (экраны, черновики и т.п.). */
  @Column({ name: 'client_app_state', type: 'jsonb', nullable: true })
  clientAppState: Record<string, unknown> | null;

  @Column({ name: 'client_app_state_updated_at', type: 'timestamptz', nullable: true })
  clientAppStateUpdatedAt: Date | null;
}
