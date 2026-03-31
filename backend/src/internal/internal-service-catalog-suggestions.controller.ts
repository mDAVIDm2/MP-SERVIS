import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Query, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { InternalCurrentOperator } from './internal-current-operator.decorator';
import { InternalOperator } from './internal-operator.entity';
import { ServiceCatalogService } from '../reference/service-catalog.service';
import { PatchServiceCatalogSuggestionDto } from './dto/patch-service-catalog-suggestion.dto';
import { InternalAuditService } from './internal-audit.service';

@Controller('internal/service-catalog/suggestions')
@UseGuards(InternalJwtAuthGuard)
export class InternalServiceCatalogSuggestionsController {
  constructor(
    private readonly catalog: ServiceCatalogService,
    private readonly audit: InternalAuditService,
  ) {}

  @Get('stats')
  async stats() {
    return this.catalog.getSuggestionStats();
  }

  @Get()
  async list(
    @Query('status') status?: string,
    @Query('q') q?: string,
    @Query('page') pageStr?: string,
    @Query('limit') limitStr?: string,
  ) {
    const page = Math.min(10_000, Math.max(1, parseInt(pageStr ?? '1', 10) || 1));
    const limit = Math.min(100, Math.max(1, parseInt(limitStr ?? '24', 10) || 24));
    return this.catalog.listSuggestionsAdmin({ status, page, limit, q });
  }

  @Patch(':id')
  async patch(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: PatchServiceCatalogSuggestionDto,
    @InternalCurrentOperator() operator: InternalOperator,
  ) {
    const result = await this.catalog.updateSuggestionAdmin(id, {
      status: body.status,
      review_note: body.review_note,
    });
    await this.audit.logInternal(operator, 'service_catalog_suggestion_update', 'service_catalog_suggestion', id, {
      requested_name: result.requested_name,
      status: result.status,
    });
    return result;
  }
}
