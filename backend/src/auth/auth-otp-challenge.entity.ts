import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

export type OtpRecipientKind = 'email' | 'phone';
export type OtpChallengeStatus = 'pending' | 'consumed' | 'locked';

@Entity('auth_otp_challenges')
@Index(['recipient', 'recipientKind', 'createdAt'])
export class AuthOtpChallenge {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Нормализованный получатель: email lower-case или только цифры телефона (7XXXXXXXXXX). */
  @Column({ type: 'varchar', length: 320 })
  recipient: string;

  @Column({ name: 'recipient_kind', type: 'varchar', length: 16 })
  recipientKind: OtpRecipientKind;

  /** Запрошенный канал доставки (email/sms/console/...). */
  @Column({ type: 'varchar', length: 24, default: 'email' })
  channel: string;

  @Column({ name: 'code_hash', type: 'varchar', length: 128 })
  codeHash: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ type: 'varchar', length: 24, default: 'pending' })
  status: OtpChallengeStatus;

  @Column({ name: 'consumed_at', type: 'timestamptz', nullable: true })
  consumedAt: Date | null;

  @Column({ name: 'attempts_count', type: 'int', default: 0 })
  attemptsCount: number;

  @Column({ name: 'send_count', type: 'int', default: 1 })
  sendCount: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'created_ip', type: 'varchar', length: 64, nullable: true })
  createdIp: string | null;
}
