import { Body, Controller, Delete, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { BookingService, AvailableSlotsDto } from './booking.service';

@Controller('booking')
@UseGuards(AuthGuard('jwt'))
export class BookingController {
  constructor(private booking: BookingService) {}

  @Post('available-slots')
  async getAvailableSlots(@Body() body: AvailableSlotsDto) {
    return this.booking.getAvailableSlots(body);
  }

  @Post('nearest-slots-batch')
  async nearestSlotsBatch(
    @Body() body: { organization_ids?: string[]; service_ids?: string[] },
  ) {
    return this.booking.nearestSlotsBatch(body ?? {});
  }

  /** Временный эндпоинт для разработки: очистить все заказы и OrderItem из БД (тестовые данные). */
  @Delete('clear-test-orders')
  async clearTestOrders() {
    return this.booking.clearTestOrders();
  }
}
