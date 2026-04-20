/**
 * Добавляет в организацию «МП Сервис» (поиск по имени, без учёта регистра)
 * категории, услуги из справочника (catalog_item_id + UUID строки), комплекс и допы.
 *
 * Запуск из папки backend (нужен DATABASE_URL в .env):
 *   npx ts-node -r tsconfig-paths/register scripts/seed-mp-servis-org-services.ts
 *
 * Существующие categories/services/service_packages дополняются (по id не дублируем).
 */
import * as path from 'path';

try {
  require('dotenv').config({ path: path.join(__dirname, '../.env') });
} catch {
  /* optional */
}

import { DataSource } from 'typeorm';
import { Organization } from '../src/organizations/organization.entity';
import { OrganizationSettings } from '../src/organizations/organization-settings.entity';

const CAT_TO = 'cat_mp_to';
const CAT_DIAG = 'cat_mp_diag';

/** Фиксированные UUID строк прайса — повторный запуск скрипта не плодит дубликаты. */
const DEMO_SERVICES = [
  {
    id: 'a0000001-0000-4000-8000-000000000001',
    category_id: CAT_TO,
    name: 'Замена моторного масла',
    price_kopecks: 350_000,
    duration_minutes: 45,
    required_skill: 'MAINTENANCE',
    catalog_item_id: 'svc_maint_oil_engine',
  },
  {
    id: 'a0000001-0000-4000-8000-000000000002',
    category_id: CAT_TO,
    name: 'Замена масляного фильтра',
    price_kopecks: 120_000,
    duration_minutes: 30,
    required_skill: 'MAINTENANCE',
    catalog_item_id: 'svc_maint_oil_filter_only',
  },
  {
    id: 'a0000001-0000-4000-8000-000000000003',
    category_id: CAT_TO,
    name: 'Замена воздушного фильтра',
    price_kopecks: 90_000,
    duration_minutes: 30,
    required_skill: 'MAINTENANCE',
    catalog_item_id: 'svc_maint_air_filter',
  },
  {
    id: 'a0000001-0000-4000-8000-000000000004',
    category_id: CAT_TO,
    name: 'Замена передних тормозных колодок',
    price_kopecks: 450_000,
    duration_minutes: 60,
    required_skill: 'MAINTENANCE',
    catalog_item_id: 'svc_brake_pads_f',
  },
  {
    id: 'a0000001-0000-4000-8000-000000000005',
    category_id: CAT_DIAG,
    name: 'Компьютерная диагностика',
    price_kopecks: 200_000,
    duration_minutes: 45,
    required_skill: 'DIAGNOSTICS',
    catalog_item_id: 'svc_diag_computer',
  },
  {
    id: 'a0000001-0000-4000-8000-000000000006',
    category_id: CAT_DIAG,
    name: 'Развал-схождение',
    price_kopecks: 280_000,
    duration_minutes: 60,
    required_skill: 'SUSPENSION',
    catalog_item_id: 'svc_diag_align',
  },
] as const;

function findOrg(orgs: Organization[]): Organization | null {
  const norm = (s: string) =>
    s
      .toLowerCase()
      .replace(/\s+/g, '')
      .replace(/[^a-zа-яё0-9]/gi, '');
  for (const o of orgs) {
    const n = norm(o.name || '');
    if (n.includes('мпсервис') || n.includes('mpservis')) return o;
    if ((o.name || '').toLowerCase().includes('мп') && (o.name || '').toLowerCase().includes('сервис')) {
      return o;
    }
  }
  return null;
}

async function main() {
  const url = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/mp_servis';
  const ds = new DataSource({
    type: 'postgres',
    url,
    entities: [Organization, OrganizationSettings],
    synchronize: false,
  });
  await ds.initialize();
  try {
    const orgRepo = ds.getRepository(Organization);
    const setRepo = ds.getRepository(OrganizationSettings);
    const orgs = await orgRepo.find();
    const org = findOrg(orgs);
    if (!org) {
      console.error(
        '[seed-mp-servis] Организация не найдена (ожидается имя вроде «МП Сервис»). Всего организаций:',
        orgs.length,
      );
      if (orgs.length) console.error('Имена:', orgs.map((o) => o.name).join(', '));
      process.exitCode = 1;
      return;
    }
    let row = await setRepo.findOne({ where: { organizationId: org.id } });
    if (!row) {
      row = setRepo.create({ organizationId: org.id, data: {} });
    }
    const data = { ...(typeof row.data === 'object' && row.data ? row.data : {}) } as Record<string, unknown>;
    const categories = Array.isArray(data.categories) ? [...(data.categories as unknown[])] : [];
    const services = Array.isArray(data.services) ? [...(data.services as unknown[])] : [];
    const packages = Array.isArray(data.service_packages) ? [...(data.service_packages as unknown[])] : [];

    const catIds = new Set(categories.map((c: any) => String(c?.id ?? '')));
    if (!catIds.has(CAT_TO)) {
      categories.push({ id: CAT_TO, name: 'ТО и обслуживание', order: 10 });
    }
    if (!catIds.has(CAT_DIAG)) {
      categories.push({ id: CAT_DIAG, name: 'Диагностика', order: 20 });
    }

    const existingServiceIds = new Set(services.map((s: any) => String(s?.id ?? '')));
    const existingCatalogIds = new Set(
      services
        .map((s: any) => String(s?.catalog_item_id ?? s?.catalogItemId ?? '').trim())
        .filter((x) => x.length > 0),
    );
    for (const s of DEMO_SERVICES) {
      const dupId = existingServiceIds.has(s.id);
      const dupCat = existingCatalogIds.has(s.catalog_item_id);
      if (!dupId && !dupCat) {
        services.push({ ...s });
        existingServiceIds.add(s.id);
        existingCatalogIds.add(s.catalog_item_id);
      }
    }

    const catalogToRowId = (cat: string): string | null => {
      for (const x of services as any[]) {
        const c = String(x?.catalog_item_id ?? x?.catalogItemId ?? '').trim();
        if (c === cat) return String(x?.id ?? '') || null;
      }
      return null;
    };
    const oilId = catalogToRowId('svc_maint_oil_engine') ?? DEMO_SERVICES[0].id;
    const filterId = catalogToRowId('svc_maint_oil_filter_only') ?? DEMO_SERVICES[1].id;
    const airId = catalogToRowId('svc_maint_air_filter') ?? DEMO_SERVICES[2].id;
    const diagId = catalogToRowId('svc_diag_computer') ?? DEMO_SERVICES[4].id;
    const alignId = catalogToRowId('svc_diag_align') ?? DEMO_SERVICES[5].id;

    const pkgId = 'pkg_mp_to_standard';
    const hasPkg = packages.some((p: any) => String(p?.id ?? '') === pkgId);
    if (!hasPkg && oilId && filterId && airId && diagId && alignId) {
      packages.push({
        id: pkgId,
        name: 'ТО Стандарт (масло + фильтры)',
        category_id: CAT_TO,
        package_price_kopecks: 520_000,
        package_duration_minutes: 120,
        included_service_ids: [oilId, filterId, airId],
        addons: [
          {
            service_id: diagId,
            extra_price_kopecks: 150_000,
            extra_duration_minutes: 45,
          },
          {
            service_id: alignId,
            extra_price_kopecks: 220_000,
            extra_duration_minutes: 60,
          },
        ],
      });
    }

    data.categories = categories;
    data.services = services;
    data.service_packages = packages;
    row.data = data;
    await setRepo.save(row);
    console.log('[seed-mp-servis] OK:', org.name, org.id, 'услуг добавлено:', DEMO_SERVICES.length, 'комплекс:', pkgId);
  } finally {
    await ds.destroy();
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
