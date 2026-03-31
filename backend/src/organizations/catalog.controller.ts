import { Controller, Get, NotFoundException, Param, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ServiceCatalogService } from '../reference/service-catalog.service';
import { OrganizationsService } from './organizations.service';

interface ServiceItem {
  id: string;
  category_id?: string;
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
    const items: Array<{
      id: string; name: string; address: string; phone: string; working_hours: string;
      car_brands: string[]; latitude?: number; longitude?: number; photo_urls: string[];
      service_ids: string[];
      services: Array<{ id: string; name: string; price_kopecks: number; duration_minutes: number }>;
      business_kind: string;
      business_kind_label: string;
      scheduling_mode: string;
    }> = [];
    for (const o of list) {
      const settings = (await this.org.getSettings(o.id)) as { car_brands?: string[]; services?: ServiceItem[] };
      const carBrands = Array.isArray(settings?.car_brands) ? settings.car_brands : [];
      const photoUrls = this.org.getPhotoUrls(o);
      const services = Array.isArray(settings?.services) ? settings.services : [];
      const serviceIds = services.map((s) => s.id);
      const servicesPayload = services.map((s) => ({
        id: s.id,
        name: s.name,
        price_kopecks: (s.price_kopecks as number) ?? 0,
        duration_minutes: (s.duration_minutes as number) ?? 60,
      }));
      const bk = ((o as any).businessKind ?? 'sto') as string;
      const sm = ((o as any).schedulingMode ?? 'staff_based') as string;
      items.push({
        id: o.id,
        name: o.name,
        address: o.address,
        phone: o.phone,
        working_hours: o.workingHours,
        car_brands: carBrands,
        latitude: (o as any).latitude ?? undefined,
        longitude: (o as any).longitude ?? undefined,
        photo_urls: photoUrls,
        service_ids: serviceIds,
        services: servicesPayload,
        business_kind: bk,
        business_kind_label: this.org.businessKindLabelRu(bk),
        scheduling_mode: sm,
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
    const settings = (await this.org.getSettings(id)) as { car_brands?: string[] };
    const carBrands = Array.isArray(settings?.car_brands) ? settings.car_brands : [];
    const photoUrls = this.org.getPhotoUrls(o);
    const bk = ((o as any).businessKind ?? 'sto') as string;
    const sm = ((o as any).schedulingMode ?? 'staff_based') as string;
    return {
      id: o.id,
      name: o.name,
      address: o.address,
      phone: o.phone,
      working_hours: o.workingHours,
      timezone: (o as any).timezone ?? 'Europe/Moscow',
      car_brands: carBrands,
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
      services?: Array<{ id: string; category_id?: string; name: string; price_kopecks?: number; duration_minutes?: number; required_skill?: string; use_body_type_pricing?: boolean; body_type_pricing?: Array<{ body_type?: string; price_kopecks?: number; duration_minutes?: number }> }>;
      service_packages?: Array<{
        id: string;
        name: string;
        category_id?: string;
        package_price_kopecks?: number;
        included_service_ids?: string[];
        addons?: Array<{ service_id?: string; extra_price_kopecks?: number }>;
      }>;
    };
    const categories = Array.isArray(settings?.categories) ? settings.categories : [];
    const services = Array.isArray(settings?.services) ? settings.services : [];
    const packages = Array.isArray(settings?.service_packages) ? settings.service_packages : [];
    const items = services.map((s) => ({
      id: s.id,
      category_id: s.category_id ?? '',
      name: s.name,
      price_kopecks: s.price_kopecks ?? 0,
      duration_minutes: s.duration_minutes ?? 60,
      required_skill: (s as any).required_skill ?? 'MAINTENANCE',
      use_body_type_pricing: s.use_body_type_pricing === true,
      body_type_pricing: Array.isArray(s.body_type_pricing) ? s.body_type_pricing : [],
    }));
    const packageItems = packages.map((p) => ({
      id: p.id,
      name: p.name,
      category_id: p.category_id ?? '',
      package_price_kopecks: p.package_price_kopecks ?? 0,
      included_service_ids: Array.isArray(p.included_service_ids) ? p.included_service_ids : [],
      addons: Array.isArray(p.addons) ? p.addons : [],
    }));
    return { categories, items, packages: packageItems };
  }
}
