/**
 * Минимальная проверка нормализации business_kind без поднятия Nest.
 * Запуск: npx ts-node -r tsconfig-paths/register scripts/smoke-organization-business-kind.ts
 */
import {
  normalizeOrganizationBusinessKind,
  ORGANIZATION_BUSINESS_KINDS,
} from '../src/organizations/organization-business-kind';

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

assert(normalizeOrganizationBusinessKind('car_wash') === 'car_wash', 'car_wash');
assert(normalizeOrganizationBusinessKind('STO') === 'sto', 'sto case');
assert(normalizeOrganizationBusinessKind('unknown-xyz') === 'sto', 'fallback sto');
assert(ORGANIZATION_BUSINESS_KINDS.includes('tire_service'), 'kinds seeded');
console.log('smoke-organization-business-kind: ok', ORGANIZATION_BUSINESS_KINDS.length);
