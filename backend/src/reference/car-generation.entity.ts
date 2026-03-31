import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { CarModel } from './car-model.entity';

@Entity('car_generations')
export class CarGeneration {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ name: 'model_id', type: 'int' })
  modelId: number;

  @Column({ type: 'varchar', length: 128 })
  name: string;

  @Column({ name: 'year_from', type: 'int', nullable: true })
  yearFrom: number | null;

  @Column({ name: 'year_to', type: 'int', nullable: true })
  yearTo: number | null;

  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @ManyToOne(() => CarModel, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'model_id' })
  model: CarModel;
}
