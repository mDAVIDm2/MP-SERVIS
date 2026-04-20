import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { Organization } from './organization.entity';
import { MasterSchedule } from './master-schedule.entity';

@Entity('staff_members')
export class StaffMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Ссылка на пользователя приложения (владелец/админ, добавленный как мастер). */
  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @Column()
  name: string;

  @Column({ type: 'varchar', length: 32, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  email: string | null;

  @Column({ type: 'varchar', length: 20, default: 'master' })
  role: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'invited_at', type: 'timestamptz', nullable: true })
  invitedAt: Date | null;

  @Column({ name: 'organization_id' })
  organizationId: string;

  /** Навыки мастера (MASTER): MAINTENANCE, ENGINE, ELECTRICAL, DIAGNOSTICS, SUSPENSION, TIRES, BODY */
  @Column({ type: 'jsonb', default: [] })
  skills: string[];

  /** Вкладка «Чаты» в Business (для мастера/админа по записи персонала). */
  @Column({ name: 'can_see_chats', default: false })
  canSeeChats: boolean;

  @Column({ name: 'can_write_chats', default: false })
  canWriteChats: boolean;

  /** Рабочее время, услуги, комплексы и пр. в настройках организации. */
  @Column({ name: 'can_manage_org_settings', default: false })
  canManageOrgSettings: boolean;

  @ManyToOne(() => Organization, (o) => o.staff, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @OneToMany(() => MasterSchedule, (s) => s.master, { cascade: true })
  schedule: MasterSchedule[];
}
