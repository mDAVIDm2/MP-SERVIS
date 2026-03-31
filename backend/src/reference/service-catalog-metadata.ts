/**
 * Порядок категорий в справочнике и допустимые business_kind для позиций категории.
 * Общий модуль для сида, сервиса и миграций.
 */
export const SERVICE_CATALOG_CATEGORY_SORT_ORDER: Record<string, number> = {
  maintenance: 10,
  engine: 20,
  suspension: 30,
  brakes: 40,
  electrical: 50,
  tires: 60,
  body: 70,
  diagnostics: 80,
  /** Мойка: кузов, колёса, составы */
  car_wash_exterior: 85,
  /** Салон, химчистка, озон */
  car_wash_interior: 86,
  /** Моторный отсек, предпродажная и т.п. */
  car_wash_extra: 87,
  /** Керамика, PPF, воски */
  detailing_coating: 88,
  /** Полировка ЛКП, фары */
  detailing_correction: 89,
  /** Автозвук, шумоизоляция, камеры */
  car_audio_install: 90,
  /** Ремонт и замена стёкол */
  glass_services: 91,
};

/** Допустимые типы организаций для категории (сиды и миграции). */
export function catalogAllowedKindsForCategoryKey(categoryKey: string): string[] {
  switch (categoryKey) {
    case 'maintenance':
    case 'engine':
    case 'suspension':
      return ['sto', 'tuning', 'ev_service', 'other'];
    case 'brakes':
      return ['sto', 'tire_service', 'other'];
    case 'electrical':
      return ['sto', 'car_audio', 'ev_service', 'other'];
    case 'tires':
      return ['sto', 'tire_service', 'other'];
    case 'body':
      return ['sto', 'body_shop', 'detailing', 'glass', 'car_wash', 'other'];
    case 'diagnostics':
      return ['sto', 'tire_service', 'ev_service', 'detailing', 'other'];
    case 'car_wash_exterior':
    case 'car_wash_interior':
    case 'car_wash_extra':
      return ['car_wash', 'detailing', 'other'];
    case 'detailing_coating':
    case 'detailing_correction':
      return ['detailing', 'body_shop', 'car_wash', 'other'];
    case 'car_audio_install':
      return ['car_audio', 'sto', 'tuning', 'other'];
    case 'glass_services':
      return ['glass', 'sto', 'body_shop', 'detailing', 'other'];
    default:
      return ['sto', 'other'];
  }
}
