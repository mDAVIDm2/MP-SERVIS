import { Controller, Get, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { ServiceCatalogService } from '../reference/service-catalog.service';

/** Единый справочник услуг MP-Servis (те же данные, что у СТО в GET /reference/service-catalog). */
@Controller('internal/service-dictionaries')
@UseGuards(InternalJwtAuthGuard)
export class InternalServiceDictionariesController {
  constructor(private readonly serviceCatalog: ServiceCatalogService) {}

  @Get()
  async list() {
    const grouped = await this.serviceCatalog.getCatalogGrouped();
    const categories = grouped.categories;
    const items: unknown[] = [];
    for (const c of categories) {
      for (const it of c.items) items.push(it);
    }
    return {
      categories: grouped.categories,
      items,
      total_items: items.length,
      total_categories: categories.length,
    };
  }
}
