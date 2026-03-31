import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { OrdersService } from '../orders/orders.service';

@Controller('internal/orders')
@UseGuards(InternalJwtAuthGuard)
export class InternalOrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  async list(
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const limitNum = Math.min(500, Math.max(1, parseInt(String(limit || '100'), 10) || 100));
    const offsetNum = Math.max(0, parseInt(String(offset || '0'), 10) || 0);
    return this.orders.findAllForInternal(limitNum, offsetNum);
  }
}
