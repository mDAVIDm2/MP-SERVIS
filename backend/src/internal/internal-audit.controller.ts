import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { InternalAuditService } from './internal-audit.service';

@Controller('internal/audit')
@UseGuards(InternalJwtAuthGuard)
export class InternalAuditController {
  constructor(private readonly audit: InternalAuditService) {}

  @Get()
  async list(
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const limitNum = Math.min(500, Math.max(1, parseInt(String(limit || '100'), 10) || 100));
    const offsetNum = Math.max(0, parseInt(String(offset || '0'), 10) || 0);
    return this.audit.find(limitNum, offsetNum, from, to);
  }
}
