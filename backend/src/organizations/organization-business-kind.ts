/** Тип точки на карте / вида бизнеса (для клиентского UI и настроек организации). */
export const ORGANIZATION_BUSINESS_KINDS = [
  'sto',
  'car_wash',
  'detailing',
  'car_audio',
  'tire_service',
  'body_shop',
  'glass',
  'tuning',
  'ev_service',
  'other',
] as const;

export type OrganizationBusinessKind = (typeof ORGANIZATION_BUSINESS_KINDS)[number];

export function normalizeOrganizationBusinessKind(v: string | null | undefined): OrganizationBusinessKind {
  const s = String(v ?? 'sto')
    .trim()
    .toLowerCase()
    .replace(/-/g, '_');
  return (ORGANIZATION_BUSINESS_KINDS as readonly string[]).includes(s)
    ? (s as OrganizationBusinessKind)
    : 'sto';
}
