import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Organization } from './organization.entity';
import { User } from '../users/user.entity';
import { StaffMember } from './staff-member.entity';

export type OrganizationInvitationStatus = 'pending' | 'accepted' | 'declined' | 'cancelled' | 'expired';

@Entity('organization_invitations')
@Index('IDX_org_invites_org', ['organizationId'])
@Index('IDX_org_invites_pending_email', ['organizationId', 'invitedEmailNorm', 'status'])
@Index('IDX_org_invites_pending_phone', ['organizationId', 'invitedPhoneNorm', 'status'])
export class OrganizationInvitation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ name: 'invited_by_user_id', type: 'uuid' })
  invitedByUserId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'invited_by_user_id' })
  invitedByUser: User;

  @Column({ name: 'accepted_by_user_id', type: 'uuid', nullable: true })
  acceptedByUserId: string | null;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'accepted_by_user_id' })
  acceptedByUser: User | null;

  @Column({ name: 'staff_member_id', type: 'uuid', nullable: true })
  staffMemberId: string | null;

  @ManyToOne(() => StaffMember, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'staff_member_id' })
  staffMember: StaffMember | null;

  @Column({ type: 'varchar', length: 20, default: 'master' })
  role: string;

  @Column({ name: 'invited_name', type: 'varchar', length: 255, nullable: true })
  invitedName: string | null;

  @Column({ name: 'invited_email', type: 'varchar', length: 320, nullable: true })
  invitedEmail: string | null;

  @Column({ name: 'invited_email_norm', type: 'varchar', length: 320, nullable: true })
  invitedEmailNorm: string | null;

  @Column({ name: 'invited_phone', type: 'varchar', length: 32, nullable: true })
  invitedPhone: string | null;

  @Column({ name: 'invited_phone_norm', type: 'varchar', length: 32, nullable: true })
  invitedPhoneNorm: string | null;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: OrganizationInvitationStatus;

  @Column({ type: 'varchar', length: 500, nullable: true })
  message: string | null;

  @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
  expiresAt: Date | null;

  @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
  respondedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
