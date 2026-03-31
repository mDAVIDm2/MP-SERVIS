import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { CarBrand } from './car-brand.entity';

@Entity('car_models')
export class CarModel {
  @PrimaryGeneratedColumn('increment')
  id: number;

  @Column({ name: 'brand_id', type: 'int' })
  brandId: number;

  @Column({ type: 'varchar', length: 128 })
  name: string;

  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @ManyToOne(() => CarBrand, (b) => b.models, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'brand_id' })
  brand: CarBrand;
}
