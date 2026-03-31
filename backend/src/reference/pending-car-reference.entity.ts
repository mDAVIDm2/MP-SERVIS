import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

/** Записи марки/модели/поколения, введённые пользователем вручную — ожидают подтверждения разработчиком для добавления в справочник. */
@Entity('pending_car_references')
export class PendingCarReference {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'varchar', length: 64 })
  userId: string;

  @Column({ name: 'car_id', type: 'varchar', length: 64 })
  carId: string;

  @Column({ name: 'pending_brand', type: 'varchar', length: 128, nullable: true })
  pendingBrand: string | null;

  @Column({ name: 'pending_model', type: 'varchar', length: 128, nullable: true })
  pendingModel: string | null;

  @Column({ name: 'pending_generation', type: 'varchar', length: 128, nullable: true })
  pendingGeneration: string | null;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: 'pending' | 'approved' | 'rejected' | 'suggested';

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
