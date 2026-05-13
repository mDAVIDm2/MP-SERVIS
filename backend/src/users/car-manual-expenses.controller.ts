import { Body, Controller, Delete, Get, Param, Post, Put, Query, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { User } from './user.entity';
import { ClientCarsService } from './client-cars.service';
import { CarManualExpensesService } from './car-manual-expenses.service';
import {
  ListManualExpensesQueryDto,
  SyncManualExpensesDto,
  UpsertManualExpenseDto,
} from './dto/car-manual-expense.dto';

@Controller('profile/cars/:carId/manual-expenses')
@UseGuards(AuthGuard('jwt'))
export class CarManualExpensesController {
  constructor(
    private readonly manual: CarManualExpensesService,
    private readonly cars: ClientCarsService,
  ) {}

  @Get()
  async list(
    @Req() req: { user: User },
    @Param('carId') carId: string,
    @Query() query: ListManualExpensesQueryDto,
  ) {
    this.cars.assertClientUser(req.user);
    return this.manual.list(req.user, carId, query);
  }

  @Put(':clientRecordId')
  async put(
    @Req() req: { user: User },
    @Param('carId') carId: string,
    @Param('clientRecordId') clientRecordId: string,
    @Body() body: UpsertManualExpenseDto,
  ) {
    this.cars.assertClientUser(req.user);
    return this.manual.putByClientId(req.user, carId, clientRecordId, body);
  }

  @Delete(':clientRecordId')
  async remove(
    @Req() req: { user: User },
    @Param('carId') carId: string,
    @Param('clientRecordId') clientRecordId: string,
  ) {
    this.cars.assertClientUser(req.user);
    return this.manual.softDelete(req.user, carId, clientRecordId);
  }

  @Post('sync')
  async sync(
    @Req() req: { user: User },
    @Param('carId') carId: string,
    @Body() body: SyncManualExpensesDto,
  ) {
    this.cars.assertClientUser(req.user);
    return this.manual.bulkSync(req.user, carId, body);
  }
}
