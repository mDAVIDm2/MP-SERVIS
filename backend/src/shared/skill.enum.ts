/**
 * Специализация мастера / требуемый навык для услуги.
 * Используется для маршрутизации заказов и расчёта доступных слотов.
 */
export enum Skill {
  MAINTENANCE = 'MAINTENANCE',   // ТО, масло, фильтры
  ENGINE = 'ENGINE',             // Двигатель, ГРМ
  ELECTRICAL = 'ELECTRICAL',     // Электрика, АКБ, генератор
  DIAGNOSTICS = 'DIAGNOSTICS',   // Диагностика
  SUSPENSION = 'SUSPENSION',    // Подвеска, развал-схождение
  TIRES = 'TIRES',              // Шины, шиномонтаж
  BODY = 'BODY',                // Кузов, покраска, полировка
}

export const SKILL_LABELS: Record<Skill, string> = {
  [Skill.MAINTENANCE]: 'ТО и обслуживание',
  [Skill.ENGINE]: 'Двигатель',
  [Skill.ELECTRICAL]: 'Электрика',
  [Skill.DIAGNOSTICS]: 'Диагностика',
  [Skill.SUSPENSION]: 'Подвеска',
  [Skill.TIRES]: 'Шины',
  [Skill.BODY]: 'Кузов',
};
