import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { User } from './user.entity';
import { CarTransferService } from './car-transfer.service';
import { CreateCarTransferDto } from './dto/create-car-transfer.dto';

@Controller('profile/car-transfers')
@UseGuards(AuthGuard('jwt'))
export class CarTransfersController {
  constructor(private readonly transfers: CarTransferService) {}

  @Post()
  async create(@Req() req: { user: User }, @Body() body: CreateCarTransferDto) {
    return this.transfers.create(req.user, {
      car_id: body.car_id,
      to_phone: body.to_phone,
      options: body.options,
    });
  }

  @Get('incoming')
  async incoming(@Req() req: { user: User }) {
    return this.transfers.listIncoming(req.user);
  }

  @Get('outgoing')
  async outgoing(@Req() req: { user: User }) {
    return this.transfers.listOutgoing(req.user);
  }

  @Post(':transferId/accept')
  async accept(@Req() req: { user: User }, @Param('transferId') transferId: string) {
    return this.transfers.accept(req.user, transferId);
  }

  @Post(':transferId/reject')
  async reject(@Req() req: { user: User }, @Param('transferId') transferId: string) {
    return this.transfers.reject(req.user, transferId);
  }

  @Post(':transferId/cancel')
  async cancel(@Req() req: { user: User }, @Param('transferId') transferId: string) {
    return this.transfers.cancel(req.user, transferId);
  }
}
