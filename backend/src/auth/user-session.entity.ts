import { Entity, PrimaryColumn, Column, CreateDateColumn, Index } from 'typeorm';

@Entity('user_sessions')
@Index(['userId', 'revokedAt'])
@Index(['familyId'])
export class UserSession {
  @PrimaryColumn('uuid')
  id: string;

  @Column({ name: 'family_id', type: 'uuid' })
  familyId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'refresh_hash', type: 'varchar', length: 128 })
  refreshHash: string;

  @Column({ name: 'device_id', type: 'varchar', length: 128, nullable: true })
  deviceId: string | null;

  @Column({ name: 'device_name', type: 'varchar', length: 256, nullable: true })
  deviceName: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  platform: string | null;

  @Column({ name: 'user_agent', type: 'varchar', length: 512, nullable: true })
  userAgent: string | null;

  @Column({ type: 'varchar', length: 64, nullable: true })
  ip: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'last_seen_at', type: 'timestamptz', nullable: true })
  lastSeenAt: Date | null;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @Column({ name: 'replaced_by_session_id', type: 'uuid', nullable: true })
  replacedBySessionId: string | null;

  /** client | business — аудитория access JWT. */
  @Column({ name: 'jwt_audience', type: 'varchar', length: 16, default: 'client' })
  jwtAudience: string;
}
