import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { OrdersService } from '../orders/orders.service';

@Controller('internal/client-cars')
@UseGuards(InternalJwtAuthGuard)
export class InternalClientCarsController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  async list() {
    return this.orders.listClientCarsAggregatedForInternal();
  }

  @Get('history')
  async history(@Query('client_phone') clientPhone: string, @Query('car_id') carId: string) {
    const phone = String(clientPhone || '').trim();
    const cid = String(carId || '').trim();
    if (!phone || !cid) return { items: [] };
    const items = await this.orders.findOrdersByCarForInternal(phone, cid);
    return { items };
  }
}
