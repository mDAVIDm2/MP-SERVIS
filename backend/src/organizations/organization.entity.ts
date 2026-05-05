import { Entity, PrimaryGeneratedColumn, Column, OneToMany, OneToOne } from 'typeorm';
import { StaffMember } from './staff-member.entity';
import { OrganizationSettings } from './organization-settings.entity';

@Entity('organizations')
export class Organization {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ default: 'Мой автосервис' })
  name: string;

  @Column({ default: '' })
  address: string;

  @Column({ default: '' })
  phone: string;

  @Column({ name: 'working_hours', default: 'Пн–Пт 9:00–19:00, Сб 10:00–16:00' })
  workingHours: string;

  /**
   * 7 элементов: пн…вс. { open, close, closed? } — время в локальном поясе организации, формат HH:mm.
   */
  @Column({ name: 'working_hours_week', type: 'jsonb', nullable: true })
  workingHoursWeek: Array<{ open: string; close: string; closed?: boolean }> | null;

  /**
   * Разовые исключения: date YYYY-MM-DD в локальной зоне организации;
   * closed: true — выходной; иначе open/close (HH:mm) — сокращённый или особый день.
   */
  @Column({ name: 'working_hours_exceptions', type: 'jsonb', nullable: true })
  workingHoursExceptions: Array<{ date: string; closed?: boolean; open?: string; close?: string }> | null;

  /** IANA timezone (например Europe/Moscow). Используется для слотов и рабочего времени. */
  @Column({ name: 'timezone', type: 'varchar', length: 64, default: 'Europe/Moscow' })
  timezone: string;

  @Column({ name: 'latitude', type: 'float', nullable: true })
  latitude: number | null;

  @Column({ name: 'longitude', type: 'float', nullable: true })
  longitude: number | null;

  /** URL фото автосервиса для карточки СТО (верхняя часть). */
  @Column({ name: 'photo_urls', type: 'simple-json', nullable: true })
  photoUrls: string[] | null;

  /**
   * Вид бизнеса: sto, car_wash, detailing, car_audio, …
   * Влияет на тексты в клиентском приложении (например «Чат с мойкой»).
   */
  @Column({ name: 'business_kind', type: 'varchar', length: 32, default: 'sto' })
  businessKind: string;

  /**
   * staff_based — слоты и запись к конкретному мастеру (навыки).
   * bay_based — вместимость по числу постов (мойка, шиномонтаж, часть цехов).
   */
  @Column({ name: 'scheduling_mode', type: 'varchar', length: 16, default: 'staff_based' })
  schedulingMode: string;

  @OneToMany(() => StaffMember, (s) => s.organization)
  staff: StaffMember[];

  @OneToOne(() => OrganizationSettings, (s) => s.organization, { cascade: true })
  settings: OrganizationSettings;

  // orders — в Order.entity по organizationId
}
