import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { OrdersService } from '../orders/orders.service';
import { ClientCarsService } from '../users/client-cars.service';
import { UsersService } from '../users/users.service';

@Controller('internal/client-cars')
@UseGuards(InternalJwtAuthGuard)
export class InternalClientCarsController {
  constructor(
    private readonly orders: OrdersService,
    private readonly clientCars: ClientCarsService,
    private readonly users: UsersService,
  ) {}

  @Get()
  async list() {
    const agg = await this.orders.listClientCarsAggregatedForInternal();
    await this.clientCars.mergeGarageOnlyCarsIntoAggregatedInternalList(agg.items);
    await this.clientCars.enrichAggregatedClientCarsWithGaragePhotos(agg.items);
    return agg;
  }

  /** Очистить VIN / госномер / описание / фото авто во всех заказах по паре телефон + car_id. */
  @Post('moderate-clear')
  async moderateClear(
    @Body()
    body: {
      client_phone: string;
      car_id: string;
      vin?: boolean;
      license_plate?: boolean;
      car_info?: boolean;
      car_photo_url?: boolean;
    },
  ) {
    const r = await this.orders.moderateClearCarFieldsForInternal(body.client_phone, body.car_id, {
      vin: body.vin === true,
      license_plate: body.license_plate === true,
      car_info: body.car_info === true,
      car_photo_url: body.car_photo_url === true,
    });
    return { ok: true, ...r };
  }

  /** Скрыть авто у клиента в приложении (гараж + заказы с этим car_id). */
  @Post('hide-from-client')
  async hideFromClient(@Body() body: { client_phone?: string; car_id?: string }) {
    const phone = String(body?.client_phone ?? '').trim();
    const carId = String(body?.car_id ?? '').trim();
    if (!phone || !carId) throw new BadRequestException('Укажите client_phone и car_id');
    const norm = this.orders.normalizePhoneForCompare(phone);
    const userId = await this.users.findIdByNormalizedPhone(norm, 'client');
    if (!userId) throw new BadRequestException('Клиентский аккаунт с таким телефоном не найден');
    await this.clientCars.hideCarFromClientForInternal(userId, carId, phone);
    return { ok: true };
  }

  /** Снова показывать авто клиенту. */
  @Post('restore-for-client')
  async restoreForClient(@Body() body: { client_phone?: string; car_id?: string }) {
    const phone = String(body?.client_phone ?? '').trim();
    const carId = String(body?.car_id ?? '').trim();
    if (!phone || !carId) throw new BadRequestException('Укажите client_phone и car_id');
    const norm = this.orders.normalizePhoneForCompare(phone);
    const userId = await this.users.findIdByNormalizedPhone(norm, 'client');
    if (!userId) throw new BadRequestException('Клиентский аккаунт с таким телефоном не найден');
    await this.clientCars.restoreCarForClientForInternal(userId, carId, phone);
    return { ok: true };
  }

  /**
   * Полное удаление: все заказы с car_id и сама запись гаража (если есть).
   * Тело: `{ "client_phone", "car_id", "confirm": "DELETE" }`.
   */
  @Post('hard-delete')
  async hardDelete(@Body() body: { client_phone?: string; car_id?: string; confirm?: string }) {
    if (body?.confirm !== 'DELETE') {
      throw new BadRequestException('Для подтверждения укажите confirm со значением DELETE');
    }
    const phone = String(body?.client_phone ?? '').trim();
    const carId = String(body?.car_id ?? '').trim();
    if (!phone || !carId) throw new BadRequestException('Укажите client_phone и car_id');
    const norm = this.orders.normalizePhoneForCompare(phone);
    const userId = await this.users.findIdByNormalizedPhone(norm, 'client');
    if (!userId) throw new BadRequestException('Клиентский аккаунт с таким телефоном не найден');
    await this.clientCars.assertCarLinkedToClientUserForInternal(userId, carId, phone);
    const purge = await this.orders.purgeOrdersByCarIdForInternal(carId);
    await this.clientCars.eraseCarAfterHardDeleteForInternal(carId);
    return { ok: true, ...purge };
  }

  @Get('history')
  async history(@Query('client_phone') clientPhone: string, @Query('car_id') carId: string) {
    const phone = String(clientPhone || '').trim();
    const cid = String(carId || '').trim();
    if (!phone || !cid) return { items: [] };
    const items = await this.orders.findOrdersByCarForInternal(phone, cid);
    return { items };
  }

  /** Файл фото авто для Control Center (JWT оператора). */
  @Get('photo-file/:carId/:filename')
  async carPhotoFile(
    @Param('carId') carId: string,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    const car = await this.clientCars.findCarEntityById(carId);
    if (!car) throw new NotFoundException();
    const fp = this.clientCars.getCarPhotoFilePath(car.userId, carId, filename);
    if (!fp) throw new NotFoundException();
    res.setHeader('Cache-Control', 'private, no-store, no-cache, must-revalidate');
    return res.sendFile(fp);
  }
}
