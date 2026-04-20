import { Entity, PrimaryGeneratedColumn, Column, Index, Unique } from 'typeorm';

/**
 * Авто скрыто у клиента в приложении (гараж и заказы с этим car_id не отображаются).
 * Запись в client_cars может отсутствовать — скрытие только по паре user_id + car_id.
 */
@Entity('user_client_hidden_cars')
@Unique(['userId', 'carId'])
@Index('IDX_user_client_hidden_cars_user', ['userId'])
export class UserClientHiddenCar {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'car_id', type: 'varchar', length: 64 })
  carId: string;

  @Column({ name: 'hidden_at', type: 'timestamptz' })
  hiddenAt: Date;
}
