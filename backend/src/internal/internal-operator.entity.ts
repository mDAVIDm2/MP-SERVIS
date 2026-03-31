import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('internal_operators')
export class InternalOperator {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @Column({ default: '' })
  name: string;

  @Column({ type: 'varchar', length: 32, default: 'support' })
  role: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'created_at', type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;
}
