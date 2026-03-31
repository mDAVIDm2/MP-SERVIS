import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Index, Unique } from 'typeorm';
import { User } from './user.entity';
import { Organization } from '../organizations/organization.entity';

@Entity('user_organization_memberships')
@Unique('UQ_user_org_membership', ['userId', 'organizationId'])
export class UserOrganizationMembership {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index('IDX_user_org_membership_user')
  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Index('IDX_user_org_membership_org')
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  /** owner | admin | master | solo — как в users.role */
  @Column({ type: 'varchar', length: 20, default: 'owner' })
  role: string;
}
