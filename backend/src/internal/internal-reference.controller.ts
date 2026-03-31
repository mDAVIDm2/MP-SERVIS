import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { InternalCurrentOperator } from './internal-current-operator.decorator';
import { InternalOperator } from './internal-operator.entity';
import { InternalAuditService } from './internal-audit.service';
import { ReferenceService } from '../reference/reference.service';
import { ServiceCatalogService } from '../reference/service-catalog.service';

@Controller('internal/reference')
@UseGuards(InternalJwtAuthGuard)
export class InternalReferenceController {
  constructor(
    private readonly reference: ReferenceService,
    private readonly serviceCatalog: ServiceCatalogService,
    private readonly audit: InternalAuditService,
  ) {}

  /** Тот же JSON, что `GET /reference/service-catalog` у СТО, но с internal JWT (обход проблем со старым `internal/service-dictionaries` в dist). */
  @Get('service-catalog')
  async getServiceCatalog() {
    return this.serviceCatalog.getCatalogGrouped();
  }

  @Post('service-catalog/categories')
  async createServiceCatalogCategory(
    @Body()
    body: { category_key: string; category_name: string; first_service_name?: string },
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.createCatalogCategoryAdmin(body);
    await this.audit.logInternal(operator, 'service_catalog_category_create', 'service_catalog', body.category_key, {
      category_name: body.category_name,
    });
    return result;
  }

  @Patch('service-catalog/categories')
  async patchServiceCatalogCategory(
    @Body()
    body: { category_key: string; category_name?: string; new_category_key?: string },
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.patchCatalogCategoryAdmin(body.category_key, {
      category_name: body.category_name,
      new_category_key: body.new_category_key,
    });
    await this.audit.logInternal(operator, 'service_catalog_category_patch', 'service_catalog', body.category_key, {
      category_name: body.category_name,
      new_category_key: body.new_category_key,
    });
    return result;
  }

  @Delete('service-catalog/categories')
  async deleteServiceCatalogCategory(
    @Query('category_key') categoryKey: string,
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.deleteCatalogCategoryAdmin(categoryKey);
    await this.audit.logInternal(operator, 'service_catalog_category_delete', 'service_catalog', categoryKey, {});
    return result;
  }

  @Post('service-catalog/categories/reorder')
  async reorderServiceCatalogCategory(
    @Body() body: { category_key: string; delta: number },
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.reorderCatalogCategoryAdmin(body.category_key, body.delta);
    await this.audit.logInternal(operator, 'service_catalog_category_reorder', 'service_catalog', body.category_key, {
      delta: body.delta,
    });
    return result;
  }

  @Post('service-catalog/items')
  async createServiceCatalogItem(
    @Body()
    body: {
      id?: string;
      category_key: string;
      category_name: string;
      name: string;
      default_duration_minutes?: number;
      sort_order?: number;
      required_skill?: string | null;
    },
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.createCatalogItemAdmin(body);
    await this.audit.logInternal(operator, 'service_catalog_item_create', 'service_catalog_item', body.name, {
      category_key: body.category_key,
    });
    return result;
  }

  @Patch('service-catalog/items/:id')
  async patchServiceCatalogItem(
    @Param('id') id: string,
    @Body()
    body: {
      name?: string;
      default_duration_minutes?: number;
      required_skill?: string | null;
      sort_order?: number;
      category_key?: string;
    },
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.updateCatalogItemAdmin(id, body);
    await this.audit.logInternal(operator, 'service_catalog_item_patch', 'service_catalog_item', id, body);
    return result;
  }

  @Delete('service-catalog/items/:id')
  async deleteServiceCatalogItem(
    @Param('id') id: string,
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.deleteCatalogItemAdmin(id);
    await this.audit.logInternal(operator, 'service_catalog_item_delete', 'service_catalog_item', id, {});
    return result;
  }

  @Post('service-catalog/items/:id/reorder')
  async reorderServiceCatalogItem(
    @Param('id') id: string,
    @Body() body: { delta: number },
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.serviceCatalog.reorderCatalogItemAdmin(id, body.delta);
    await this.audit.logInternal(operator, 'service_catalog_item_reorder', 'service_catalog_item', id, {
      delta: body.delta,
    });
    return result;
  }

  @Get('car-brands')
  async getCarBrands() {
    return this.reference.getCarBrands();
  }

  @Post('car-brands')
  async createBrand(@Body() body: { name: string }) {
    return this.reference.createBrand(body.name);
  }

  @Delete('car-brands/:id')
  async deleteBrand(@Param('id', ParseIntPipe) id: number) {
    await this.reference.deleteBrand(id);
    return { ok: true };
  }

  @Get('car-brands/:id/models')
  async getCarModels(@Param('id', ParseIntPipe) brandId: number) {
    return this.reference.getCarModels(brandId);
  }

  @Post('car-brands/:id/models')
  async createModel(@Param('id', ParseIntPipe) brandId: number, @Body() body: { name: string }) {
    return this.reference.createModel(brandId, body.name);
  }

  @Delete('car-models/:id')
  async deleteModel(@Param('id', ParseIntPipe) id: number) {
    await this.reference.deleteModel(id);
    return { ok: true };
  }

  @Get('car-models/:modelId/generations')
  async getCarGenerations(@Param('modelId', ParseIntPipe) modelId: number) {
    return this.reference.getCarGenerations(modelId);
  }

  @Post('car-models/:modelId/generations')
  async createGeneration(
    @Param('modelId', ParseIntPipe) modelId: number,
    @Body() body: { name: string; year_from?: number; year_to?: number },
  ) {
    return this.reference.createGeneration(modelId, body.name, body.year_from, body.year_to);
  }

  @Delete('car-generations/:id')
  async deleteGeneration(@Param('id', ParseIntPipe) id: number) {
    await this.reference.deleteGeneration(id);
    return { ok: true };
  }

  @Get('pending-car')
  async listPending() {
    return this.reference.listPending();
  }

  @Post('pending-car/:id/approve')
  async approvePending(@Param('id') id: string) {
    return this.reference.approvePending(id);
  }

  @Post('pending-car/:id/reject')
  async rejectPending(@Param('id') id: string) {
    await this.reference.rejectPending(id);
    return { ok: true };
  }

  @Post('pending-car/:id/suggest')
  async suggestPending(
    @Param('id') id: string,
    @Body() body: { brandId: number; modelId: number; generationId: number },
  ) {
    await this.reference.suggestPending(id, body);
    return { ok: true };
  }
}
