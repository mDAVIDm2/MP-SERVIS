import { Controller, Get, NotFoundException, Param, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ServiceCatalogService } from '../reference/service-catalog.service';
import { OrganizationsService } from './organizations.service';
import { computeOrganizationHoursLive } from './working-hours-calendar.util';

interface ServiceItem {
  id: string;
  category_id?: string;
  /** Id позиции единого справочника (`svc_*`), если услуга добавлена из каталога в бизнес-приложении. */
  catalog_item_id?: string;
  name: string;
  price_kopecks?: number;
  duration_minutes?: number;
  required_skill?: string;
  use_body_type_pricing?: boolean;
  body_type_pricing?: Array<{
    body_type?: string;
    price_kopecks?: number;
    duration_minutes?: number;
  }>;
}

interface ServicePackageRow {
  included_service_ids?: string[];
  package_price_kopecks?: number;
  package_duration_minutes?: number;
  addons?: Array<{
    service_id?: string;
    extra_price_kopecks?: number;
    extra_duration_minutes?: number;
  }>;
}

type ServicePayloadRow = {
  id: string;
  name: string;
  price_kopecks: number;
  duration_minutes: number;
  catalog_item_id?: string;
  use_body_type_pricing?: boolean;
  body_type_pricing?: Array<{
    body_type?: string;
    price_kopecks?: number;
    duration_minutes?: number;
  }>;
};

/** Каталог организаций для клиентского приложения (поиск СТО). */
@Controller('catalog')
@UseGuards(AuthGuard('jwt'))
export class CatalogController {
  constructor(
    private org: OrganizationsService,
    private serviceCatalog: ServiceCatalogService,
  ) {}

  /** Глобальный справочник услуг (для фильтров клиента). Опционально `business_kind` — только позиции, разрешённые для типа точки. */
  @Get('services')
  async getCatalogServices(@Query('business_kind') businessKind?: string) {
    return this.serviceCatalog.getCatalogGrouped(undefined, businessKind ?? null);
  }

  @Get('search')
  async search(@Query('q') q?: string, @Query('business_kind') businessKind?: string) {
    const list = await this.org.findAll();
    const pendingCatalogIds = new Set<string>();
    const drafts: Array<{
      o: (typeof list)[0];
      carBrands: string[];
      amenityIds: string[];
      publicDescription: string;
      photoUrls: string[];
      byId: Map<string, ServicePayloadRow>;
      catalogItemIdsForSearch: Set<string>;
      bk: string;
      sm: string;
    }> = [];

    for (const o of list) {
      const settings = (await this.org.getSettings(o.id)) as {
        car_brands?: string[];
        services?: ServiceItem[];
        service_packages?: ServicePackageRow[];
        amenity_ids?: string[];
        public_description?: string;
      };
      const carBrands = Array.isArray(settings?.car_brands) ? settings.car_brands : [];
      const amenityIds = Array.isArray(settings?.amenity_ids)
        ? (settings.amenity_ids as string[]).filter((x) => typeof x === 'string' && x.trim() !== '')
        : [];
      const publicDescription =
        settings?.public_description != null && String(settings.public_description).trim() !== ''
          ? String(settings.public_description).trim()
          : '';
      const photoUrls = this.org.getPhotoUrls(o);
      const services = Array.isArray(settings?.services) ? settings.services : [];
      const packages = Array.isArray(settings?.service_packages) ? settings.service_packages : [];

      /** Id из справочника клиентского фильтра — у строк прайса часто свой UUID, а `svc_*` лежит здесь. */
      const catalogItemIdsForSearch = new Set<string>();
      const byId = new Map<string, ServicePayloadRow>();
      for (const s of services) {
        if (!s?.id) continue;
        const id = String(s.id);
        const rawCat = (s as { catalog_item_id?: string; catalogItemId?: string }).catalog_item_id
          ?? (s as { catalogItemId?: string }).catalogItemId;
        const catId = rawCat != null && String(rawCat).trim() !== '' ? String(rawCat).trim() : '';
        if (catId) catalogItemIdsForSearch.add(catId);
        byId.set(id, {
          id,
          name: String(s.name ?? '').trim(),
          price_kopecks: Number(s.price_kopecks ?? 0) || 0,
          duration_minutes: Number(s.duration_minutes ?? 60) || 60,
          ...(catId ? { catalog_item_id: catId } : {}),
          use_body_type_pricing: s.use_body_type_pricing === true,
          body_type_pricing: Array.isArray(s.body_type_pricing) ? s.body_type_pricing : [],
        });
      }

      for (const p of packages) {
        const inc = Array.isArray(p?.included_service_ids)
          ? p.included_service_ids.filter(Boolean).map(String)
          : [];
        const n = inc.length;
        const pkgPrice = Number(p?.package_price_kopecks ?? 0) || 0;
        const pkgDur = Number(p?.package_duration_minutes ?? 0) || 0;
        const perPrice = n > 0 ? Math.floor(pkgPrice / n) : 0;
        const perDur = n > 0 ? Math.max(15, Math.floor(pkgDur / n) || 60) : 60;
        for (const id of inc) {
          if (!byId.has(id)) {
            byId.set(id, { id, name: '', price_kopecks: perPrice, duration_minutes: perDur });
          }
        }
        const addons = Array.isArray(p?.addons) ? p.addons : [];
        for (const a of addons) {
          const sid = a?.service_id != null && String(a.service_id).trim() !== '' ? String(a.service_id) : '';
          if (!sid) continue;
          if (!byId.has(sid)) {
            byId.set(sid, {
              id: sid,
              name: '',
              price_kopecks: Number(a?.extra_price_kopecks ?? 0) || 0,
              duration_minutes: Number(a?.extra_duration_minutes ?? 30) || 30,
            });
          }
        }
      }

      for (const v of byId.values()) {
        if (!v.name) pendingCatalogIds.add(v.id);
      }

      const bk = ((o as any).businessKind ?? 'sto') as string;
      const sm = ((o as any).schedulingMode ?? 'staff_based') as string;
      drafts.push({
        o,
        carBrands,
        amenityIds,
        publicDescription,
        photoUrls,
        byId,
        catalogItemIdsForSearch,
        bk,
        sm,
      });
    }

    const catalogBasics = await this.serviceCatalog.resolveItemBasicsByIds([...pendingCatalogIds]);

    const items: Array<{
      id: string; name: string; address: string; phone: string; working_hours: string;
      working_hours_week: Array<{ open: string; close: string; closed?: boolean }> | null;
      working_hours_exceptions: Array<{ date: string; closed?: boolean; open?: string; close?: string }> | null;
      timezone: string;
      hours_live: ReturnType<typeof computeOrganizationHoursLive>;
      car_brands: string[];
      amenity_ids: string[];
      public_description?: string;
      latitude?: number; longitude?: number; photo_urls: string[];
      service_ids: string[];
      services: ServicePayloadRow[];
      business_kind: string;
      business_kind_label: string;
      scheduling_mode: string;
    }> = [];

    for (const d of drafts) {
      const servicesPayload: ServicePayloadRow[] = [...d.byId.values()].map((v) => {
        let name = v.name.trim();
        if (!name) {
          name = (catalogBasics.get(v.id)?.name ?? '').trim() || 'Услуга';
        }
        let duration = v.duration_minutes;
        const catDur = catalogBasics.get(v.id)?.defaultDurationMinutes;
        if ((!duration || duration < 15) && catDur) duration = catDur;
        if (!duration || duration < 15) duration = 60;
        return {
          id: v.id,
          name,
          price_kopecks: v.price_kopecks,
          duration_minutes: duration,
          ...(v.catalog_item_id ? { catalog_item_id: v.catalog_item_id } : {}),
          ...(v.use_body_type_pricing === true ? { use_body_type_pricing: true } : {}),
          ...(Array.isArray(v.body_type_pricing) && v.body_type_pricing.length > 0
            ? { body_type_pricing: v.body_type_pricing }
            : {}),
        };
      });
      const service_ids = [
        ...new Set([...servicesPayload.map((s) => s.id), ...d.catalogItemIdsForSearch]),
      ];
      const tz = ((d.o as any).timezone ?? 'Europe/Moscow') as string;
      const week = ((d.o as any).workingHoursWeek ?? null) as Array<{
        open: string;
        close: string;
        closed?: boolean;
      }> | null;
      const exceptions = ((d.o as any).workingHoursExceptions ?? null) as Array<{
        date: string;
        closed?: boolean;
        open?: string;
        close?: string;
      }> | null;
      items.push({
        id: d.o.id,
        name: d.o.name,
        address: d.o.address,
        phone: d.o.phone,
        working_hours: d.o.workingHours,
        working_hours_week: week,
        working_hours_exceptions: exceptions,
        timezone: tz,
        hours_live: computeOrganizationHoursLive({ timezone: tz, week, exceptions }),
        car_brands: d.carBrands,
        amenity_ids: d.amenityIds,
        public_description: d.publicDescription || undefined,
        latitude: (d.o as any).latitude ?? undefined,
        longitude: (d.o as any).longitude ?? undefined,
        photo_urls: d.photoUrls,
        service_ids,
        services: servicesPayload,
        business_kind: d.bk,
        business_kind_label: this.org.businessKindLabelRu(d.bk),
        scheduling_mode: d.sm,
      });
    }
    let filtered = items;
    const query = (q ?? '').trim().toLowerCase();
    if (query) {
      filtered = items.filter(
        (o) =>
          o.name.toLowerCase().includes(query) ||
          (o.address && o.address.toLowerCase().includes(query)),
      );
    }
    const kind = (businessKind ?? '').trim().toLowerCase();
    if (kind && kind !== 'all') {
      filtered = filtered.filter((o) => o.business_kind === kind);
    }
    return { items: filtered };
  }

  @Get('organizations/:id')
  async getOrganization(@Param('id') id: string) {
    const o = await this.org.findOne(id);
    if (!o) throw new NotFoundException('Organization not found');
    const settings = (await this.org.getSettings(id)) as {
      car_brands?: string[];
      amenity_ids?: string[];
      public_description?: string;
    };
    const carBrands = Array.isArray(settings?.car_brands) ? settings.car_brands : [];
    const amenityIds = Array.isArray(settings?.amenity_ids)
      ? (settings.amenity_ids as string[]).filter((x) => typeof x === 'string' && x.trim() !== '')
      : [];
    const publicDescription =
      settings?.public_description != null && String(settings.public_description).trim() !== ''
        ? String(settings.public_description).trim()
        : '';
    const photoUrls = this.org.getPhotoUrls(o);
    const bk = ((o as any).businessKind ?? 'sto') as string;
    const sm = ((o as any).schedulingMode ?? 'staff_based') as string;
    const tz = (o as any).timezone ?? 'Europe/Moscow';
    const week = ((o as any).workingHoursWeek ?? null) as Array<{
      open: string;
      close: string;
      closed?: boolean;
    }> | null;
    const exceptions = ((o as any).workingHoursExceptions ?? null) as Array<{
      date: string;
      closed?: boolean;
      open?: string;
      close?: string;
    }> | null;
    return {
      id: o.id,
      name: o.name,
      address: o.address,
      phone: o.phone,
      working_hours: o.workingHours,
      working_hours_week: week,
      working_hours_exceptions: exceptions,
      timezone: tz,
      hours_live: computeOrganizationHoursLive({ timezone: tz, week, exceptions }),
      car_brands: carBrands,
      amenity_ids: amenityIds,
      public_description: publicDescription || undefined,
      latitude: (o as any).latitude ?? undefined,
      longitude: (o as any).longitude ?? undefined,
      photo_urls: photoUrls,
      business_kind: bk,
      business_kind_label: this.org.businessKindLabelRu(bk),
      scheduling_mode: sm,
    };
  }

  @Get('organizations/:id/services')
  async getOrganizationServices(@Param('id') id: string) {
    const o = await this.org.findOne(id);
    if (!o) throw new NotFoundException('Organization not found');
    const settings = (await this.org.getSettings(id)) as {
      categories?: Array<{ id: string; name: string; order?: number }>;
      services?: Array<{
        id: string;
        category_id?: string;
        catalog_item_id?: string;
        catalogItemId?: string;
        name: string;
        price_kopecks?: number;
        duration_minutes?: number;
        required_skill?: string;
        use_body_type_pricing?: boolean;
        body_type_pricing?: Array<{ body_type?: string; price_kopecks?: number; duration_minutes?: number }>;
      }>;
      service_packages?: Array<{
        id: string;
        name: string;
        category_id?: string;
        package_price_kopecks?: number;
        package_duration_minutes?: number;
        included_service_ids?: string[];
        addons?: Array<{
          service_id?: string;
          extra_price_kopecks?: number;
          extra_duration_minutes?: number;
        }>;
      }>;
    };
    const categories = Array.isArray(settings?.categories) ? settings.categories : [];
    const services = Array.isArray(settings?.services) ? settings.services : [];
    const packages = Array.isArray(settings?.service_packages) ? settings.service_packages : [];
    const items = services.map((s) => {
      const catRaw = s.catalog_item_id ?? s.catalogItemId;
      const catalogItemId =
        catRaw != null && String(catRaw).trim() !== '' ? String(catRaw).trim() : undefined;
      return {
        id: s.id,
        category_id: s.category_id ?? '',
        name: s.name,
        price_kopecks: s.price_kopecks ?? 0,
        duration_minutes: s.duration_minutes ?? 60,
        required_skill: (s as any).required_skill ?? 'MAINTENANCE',
        use_body_type_pricing: s.use_body_type_pricing === true,
        body_type_pricing: Array.isArray(s.body_type_pricing) ? s.body_type_pricing : [],
        ...(catalogItemId ? { catalog_item_id: catalogItemId } : {}),
      };
    });
    const packageItems = packages.map((p) => ({
      id: p.id,
      name: p.name,
      category_id: p.category_id ?? '',
      package_price_kopecks: p.package_price_kopecks ?? 0,
      package_duration_minutes: (p as { package_duration_minutes?: number }).package_duration_minutes ?? 0,
      included_service_ids: Array.isArray(p.included_service_ids) ? p.included_service_ids : [],
      addons: Array.isArray(p.addons)
        ? p.addons.map((a) => ({
            service_id: a.service_id,
            extra_price_kopecks: a.extra_price_kopecks ?? 0,
            extra_duration_minutes: (a as { extra_duration_minutes?: number }).extra_duration_minutes ?? 0,
          }))
        : [],
    }));
    return { categories, items, packages: packageItems };
  }
}
