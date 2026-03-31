import type { CatalogSeedRow } from './service-catalog-seed.types';
import { SERVICE_CATALOG_SEED_EXTRA } from './service-catalog.seed-extra';

export type { CatalogSeedRow } from './service-catalog-seed.types';

const SERVICE_CATALOG_SEED_BASE: CatalogSeedRow[] = [
  // ТО и обслуживание
  { id: 'svc_maint_oil_engine', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена моторного масла и масляного фильтра', defaultDurationMinutes: 45, sortOrder: 10 },
  { id: 'svc_maint_oil_filter_only', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена масляного фильтра', defaultDurationMinutes: 30, sortOrder: 20 },
  { id: 'svc_maint_air_filter', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена воздушного фильтра', defaultDurationMinutes: 30, sortOrder: 30 },
  { id: 'svc_maint_cabin_filter', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена салонного фильтра', defaultDurationMinutes: 30, sortOrder: 40 },
  { id: 'svc_maint_spark_plugs', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена свечей зажигания', defaultDurationMinutes: 60, sortOrder: 50 },
  { id: 'svc_maint_brake_fluid', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена тормозной жидкости', defaultDurationMinutes: 45, sortOrder: 60 },
  { id: 'svc_maint_coolant', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена охлаждающей жидкости (антифриз)', defaultDurationMinutes: 90, sortOrder: 70 },
  { id: 'svc_maint_atf', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена жидкости АКПП', defaultDurationMinutes: 90, sortOrder: 80 },
  { id: 'svc_maint_timing_belt', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена ремня ГРМ', defaultDurationMinutes: 240, sortOrder: 90, requiredSkill: 'ENGINE' },
  { id: 'svc_maint_timing_chain', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена цепи ГРМ', defaultDurationMinutes: 360, sortOrder: 100, requiredSkill: 'ENGINE' },
  { id: 'svc_maint_drive_belt', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена приводного ремня (генератор, помпа)', defaultDurationMinutes: 60, sortOrder: 110 },
  { id: 'svc_maint_to_1', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'ТО-1 (регламентное)', defaultDurationMinutes: 60, sortOrder: 120 },
  { id: 'svc_maint_to_2', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'ТО-2 (регламентное)', defaultDurationMinutes: 120, sortOrder: 130 },
  { id: 'svc_maint_to_3', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'ТО-3 (регламентное)', defaultDurationMinutes: 180, sortOrder: 140 },
  // Двигатель
  { id: 'svc_eng_diag', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Диагностика двигателя', defaultDurationMinutes: 60, sortOrder: 10, requiredSkill: 'DIAGNOSTICS' },
  { id: 'svc_eng_compression', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Компрессометрия', defaultDurationMinutes: 90, sortOrder: 20, requiredSkill: 'ENGINE' },
  { id: 'svc_eng_gasket_head', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Замена прокладки ГБЦ', defaultDurationMinutes: 480, sortOrder: 30, requiredSkill: 'ENGINE' },
  { id: 'svc_eng_injectors', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Чистка / замена форсунок', defaultDurationMinutes: 120, sortOrder: 40, requiredSkill: 'ENGINE' },
  { id: 'svc_eng_turbo', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Диагностика и ремонт турбины', defaultDurationMinutes: 180, sortOrder: 50, requiredSkill: 'ENGINE' },
  { id: 'svc_eng_radiator', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Замена радиатора охлаждения', defaultDurationMinutes: 120, sortOrder: 60 },
  { id: 'svc_eng_water_pump', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Замена помпы (водяного насоса)', defaultDurationMinutes: 180, sortOrder: 70, requiredSkill: 'ENGINE' },
  // Подвеска и рулевое
  { id: 'svc_susp_diag', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Диагностика подвески', defaultDurationMinutes: 60, sortOrder: 10, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_shock_f', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена передних амортизаторов', defaultDurationMinutes: 120, sortOrder: 20, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_shock_r', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена задних амортизаторов', defaultDurationMinutes: 120, sortOrder: 30, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_springs', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена пружин подвески', defaultDurationMinutes: 150, sortOrder: 40, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_control_arm', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена рычага подвески', defaultDurationMinutes: 90, sortOrder: 50, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_ball_joint', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена шаровой опоры', defaultDurationMinutes: 90, sortOrder: 60, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_stabilizer', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена стоек / втулок стабилизатора', defaultDurationMinutes: 60, sortOrder: 70, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_steering_rack', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Ремонт / замена рулевой рейки', defaultDurationMinutes: 240, sortOrder: 80, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_wheel_bearing', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена ступичного подшипника', defaultDurationMinutes: 120, sortOrder: 90, requiredSkill: 'SUSPENSION' },
  // Тормозная система
  { id: 'svc_brake_pads_f', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Замена передних тормозных колодок', defaultDurationMinutes: 60, sortOrder: 10 },
  { id: 'svc_brake_pads_r', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Замена задних тормозных колодок', defaultDurationMinutes: 60, sortOrder: 20 },
  { id: 'svc_brake_discs_f', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Замена передних тормозных дисков', defaultDurationMinutes: 90, sortOrder: 30 },
  { id: 'svc_brake_discs_r', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Замена задних тормозных дисков', defaultDurationMinutes: 90, sortOrder: 40 },
  { id: 'svc_brake_caliper', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Ремонт / замена суппорта', defaultDurationMinutes: 120, sortOrder: 50 },
  { id: 'svc_brake_bleed', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Прокачка тормозной системы', defaultDurationMinutes: 45, sortOrder: 60 },
  // Электрика
  { id: 'svc_el_batt', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Замена аккумулятора', defaultDurationMinutes: 30, sortOrder: 10 },
  { id: 'svc_el_gen', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Ремонт / замена генератора', defaultDurationMinutes: 120, sortOrder: 20, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_el_starter', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Ремонт / замена стартера', defaultDurationMinutes: 90, sortOrder: 30, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_el_wiring', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Диагностика электропроводки', defaultDurationMinutes: 90, sortOrder: 40, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_el_lights', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Ремонт / замена фар и фонарей', defaultDurationMinutes: 60, sortOrder: 50 },
  // Шины и колёса
  { id: 'svc_tire_mount', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Шиномонтаж (комплект)', defaultDurationMinutes: 60, sortOrder: 10, requiredSkill: 'TIRES' },
  { id: 'svc_tire_balance', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Балансировка колёс (комплект)', defaultDurationMinutes: 45, sortOrder: 20, requiredSkill: 'TIRES' },
  { id: 'svc_tire_repair', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Ремонт прокола (одно колесо)', defaultDurationMinutes: 30, sortOrder: 30, requiredSkill: 'TIRES' },
  { id: 'svc_tire_storage', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Сезонное хранение шин', defaultDurationMinutes: 15, sortOrder: 40 },
  { id: 'svc_tire_switch', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Переобувка на сезон (комплект)', defaultDurationMinutes: 60, sortOrder: 50, requiredSkill: 'TIRES' },
  // Кузов
  { id: 'svc_body_polish', categoryKey: 'body', categoryName: 'Кузов', name: 'Полировка кузова', defaultDurationMinutes: 240, sortOrder: 10, requiredSkill: 'BODY' },
  { id: 'svc_body_dent', categoryKey: 'body', categoryName: 'Кузов', name: 'Удаление вмятин без покраски', defaultDurationMinutes: 120, sortOrder: 20, requiredSkill: 'BODY' },
  { id: 'svc_body_paint', categoryKey: 'body', categoryName: 'Кузов', name: 'Локальная покраска элемента', defaultDurationMinutes: 480, sortOrder: 30, requiredSkill: 'BODY' },
  { id: 'svc_body_bumper', categoryKey: 'body', categoryName: 'Кузов', name: 'Ремонт / замена бампера', defaultDurationMinutes: 180, sortOrder: 40, requiredSkill: 'BODY' },
  { id: 'svc_body_glass', categoryKey: 'body', categoryName: 'Кузов', name: 'Замена лобового / бокового стекла', defaultDurationMinutes: 120, sortOrder: 50 },
  // Диагностика
  { id: 'svc_diag_computer', categoryKey: 'diagnostics', categoryName: 'Диагностика', name: 'Компьютерная диагностика', defaultDurationMinutes: 45, sortOrder: 10, requiredSkill: 'DIAGNOSTICS' },
  { id: 'svc_diag_pre_purchase', categoryKey: 'diagnostics', categoryName: 'Диагностика', name: 'Диагностика автомобиля перед покупкой', defaultDurationMinutes: 90, sortOrder: 20, requiredSkill: 'DIAGNOSTICS' },
  { id: 'svc_diag_ac', categoryKey: 'diagnostics', categoryName: 'Диагностика', name: 'Диагностика и заправка кондиционера', defaultDurationMinutes: 60, sortOrder: 30 },
  { id: 'svc_diag_align', categoryKey: 'diagnostics', categoryName: 'Диагностика', name: 'Развал-схождение', defaultDurationMinutes: 60, sortOrder: 40, requiredSkill: 'SUSPENSION' },
];

export const SERVICE_CATALOG_SEED: CatalogSeedRow[] = [...SERVICE_CATALOG_SEED_BASE, ...SERVICE_CATALOG_SEED_EXTRA];
