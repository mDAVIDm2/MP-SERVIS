import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Response } from 'express';
import { AuthGuard } from '@nestjs/passport';
import { User } from './user.entity';
import { ClientCarsService, CreateClientCarBody, PatchClientCarBody } from './client-cars.service';
import { UsersService } from './users.service';

@Controller('profile')
@UseGuards(AuthGuard('jwt'))
export class ClientCarsController {
  constructor(
    private readonly cars: ClientCarsService,
    private readonly users: UsersService,
  ) {}

  @Get('cars')
  async list(@Req() req: { user: User }) {
    return this.cars.list(req.user.id);
  }

  @Post('cars')
  async create(@Req() req: { user: User }, @Body() body: CreateClientCarBody) {
    return this.cars.create(req.user, body);
  }

  @Patch('cars/:carId')
  async patch(
    @Req() req: { user: User },
    @Param('carId') carId: string,
    @Body() body: PatchClientCarBody,
  ) {
    return this.cars.patch(req.user, carId, body);
  }

  @Delete('cars/:carId')
  async remove(@Req() req: { user: User }, @Param('carId') carId: string) {
    await this.cars.remove(req.user, carId);
    return { ok: true };
  }

  @Post('cars/:carId/photo')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 8 * 1024 * 1024 } }))
  async uploadPhoto(
    @Req() req: { user: User },
    @Param('carId') carId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.cars.saveCarPhoto(req.user, carId, file);
  }

  /** Раздача загруженного фото (как аватар профиля). */
  @Get('cars/:carId/photo-file/:filename')
  async getPhotoFile(
    @Param('carId') carId: string,
    @Param('filename') filename: string,
    @Req() req: { user: User },
    @Res() res: Response,
  ) {
    const car = await this.cars.findCarEntityById(carId);
    if (!car) return res.status(404).send('Not found');
    const ownerId = car.userId;
    if (req.user.id === ownerId) {
      if (await this.cars.isCarHiddenFromClientApp(ownerId, carId)) {
        return res.status(404).send('Not found');
      }
    } else {
      const ok = await this.users.canStaffFetchClientAvatar(req.user, ownerId);
      if (!ok) {
        throw new ForbiddenException('Нет доступа к фото этого автомобиля');
      }
    }
    const fp = this.cars.getCarPhotoFilePath(ownerId, carId, filename);
    if (!fp) return res.status(404).send('Not found');
    res.setHeader('Cache-Control', 'private, no-store, no-cache, must-revalidate');
    return res.sendFile(fp);
  }
}
