import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ReferenceService } from './reference.service';
import { ServiceCatalogService } from './service-catalog.service';

/** Справочник марок, моделей, поколений; при необходимости — отправка данных «ожидает подтверждения». */
@Controller('reference')
export class ReferenceController {
  constructor(
    private readonly reference: ReferenceService,
    private readonly serviceCatalog: ServiceCatalogService,
  ) {}

  @Get('car-brands')
  async getCarBrands() {
    return this.reference.getCarBrands();
  }

  @Get('car-brands/:id/models')
  async getCarModels(@Param('id', ParseIntPipe) brandId: number) {
    return this.reference.getCarModels(brandId);
  }

  @Get('car-models/:modelId/generations')
  async getCarGenerations(@Param('modelId', ParseIntPipe) modelId: number) {
    return this.reference.getCarGenerations(modelId);
  }

  /** Отправить на подтверждение разработчиком введённые вручную марку/модель/поколение. */
  @Post('pending-car')
  @UseGuards(AuthGuard('jwt'))
  async createPending(
    @Req() req: { user: { id: string } },
    @Body() body: Record<string, unknown>,
  ) {
    const carId = String(body?.carId ?? '');
    const pendingBrand = typeof body?.pendingBrand === 'string' ? body.pendingBrand : (typeof body?.pending_brand === 'string' ? body.pending_brand : undefined);
    const pendingModel = typeof body?.pendingModel === 'string' ? body.pendingModel : (typeof body?.pending_model === 'string' ? body.pending_model : undefined);
    const pendingGeneration = typeof body?.pendingGeneration === 'string' ? body.pendingGeneration : (typeof body?.pending_generation === 'string' ? body.pending_generation : undefined);
    return this.reference.createPending(req.user.id, carId, {
      pendingBrand: pendingBrand?.trim() || undefined,
      pendingModel: pendingModel?.trim() || undefined,
      pendingGeneration: pendingGeneration?.trim() || undefined,
    });
  }

  /** Список заявок на подтверждение марки/модели/поколения (для разработчиков). */
  @Get('pending-car')
  @UseGuards(AuthGuard('jwt'))
  async listPending() {
    return this.reference.listPending();
  }

  /**
   * Единый справочник услуг AutoHub (для настроек организации).
   * - `organization_id` (или организация из JWT) — фильтр по `business_kind` этой организации.
   * - без организации: опционально `business_kind` — только позиции, разрешённые для этого вида точки.
   */
  @Get('service-catalog')
  @UseGuards(AuthGuard('jwt'))
  async getServiceCatalog(
    @Query('organization_id') organizationId?: string,
    @Query('business_kind') businessKind?: string,
    @Req() req?: { user?: { organizationId?: string | null } },
  ) {
    const orgId =
      (organizationId && organizationId.trim()) || req?.user?.organizationId || null;
    if (orgId) {
      return this.serviceCatalog.getCatalogGrouped(orgId);
    }
    const bk =
      businessKind != null && String(businessKind).trim() !== '' ? String(businessKind).trim() : null;
    return this.serviceCatalog.getCatalogGrouped(null, bk);
  }

  /** Запрос на добавление услуги в справочник (увидят разработчики). */
  @Post('service-catalog/suggestions')
  @UseGuards(AuthGuard('jwt'))
  async suggestServiceCatalog(
    @Req() req: { user: { organizationId: string | null } },
    @Body() body: { requested_name?: string; category_hint?: string; note?: string },
  ) {
    const orgId = req.user.organizationId;
    if (!orgId) throw new BadRequestException('Пользователь не привязан к организации');
    return this.serviceCatalog.createSuggestion(orgId, {
      requested_name: String(body?.requested_name ?? ''),
      category_hint: body?.category_hint,
      note: body?.note,
    });
  }
}
