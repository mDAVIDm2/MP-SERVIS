import { normalizeOrganizationBusinessKind, type OrganizationBusinessKind } from './organization-business-kind';

export type SchedulingMode = 'staff_based' | 'bay_based';

/** Типы точек, где запись логичнее вести по постам/линиям, а не по имени мастера. */
const DEFAULT_BAY_BUSINESS_KINDS: ReadonlySet<OrganizationBusinessKind> = new Set([
  'car_wash',
  'tire_service',
  'detailing',
  'body_shop',
]);

export function defaultSchedulingModeForBusinessKind(kind: string | null | undefined): SchedulingMode {
  const k = normalizeOrganizationBusinessKind(kind);
  return DEFAULT_BAY_BUSINESS_KINDS.has(k) ? 'bay_based' : 'staff_based';
}

export function normalizeSchedulingMode(v: string | null | undefined): SchedulingMode {
  const s = String(v ?? 'staff_based').trim().toLowerCase();
  return s === 'bay_based' ? 'bay_based' : 'staff_based';
}
