import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { StaffMember } from './staff-member.entity';

@Entity('master_schedules')
export class MasterSchedule {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'master_id' })
  masterId: string;

  /** 0 = Sunday, 1 = Monday, ... 6 = Saturday */
  @Column({ name: 'day_of_week', type: 'smallint' })
  dayOfWeek: number;

  @Column({ name: 'start_time', type: 'varchar', length: 5, default: '09:00' })
  startTime: string;

  @Column({ name: 'end_time', type: 'varchar', length: 5, default: '18:00' })
  endTime: string;

  @Column({ name: 'is_working_day', default: true })
  isWorkingDay: boolean;

  @ManyToOne(() => StaffMember, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'master_id' })
  master: StaffMember;
}
