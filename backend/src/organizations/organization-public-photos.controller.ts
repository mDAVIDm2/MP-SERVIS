import { BadRequestException, Controller, Get, Param, Res } from '@nestjs/common';
import { Response } from 'express';
import { OrganizationsService } from './organizations.service';

/**
 * Фото точки без JWT: URL попадает в каталог для клиентов, а Image.network не шлёт Authorization.
 * Имя файла генерируется сервером (timestamp + random); проверяем отсутствие path traversal.
 */
@Controller('organizations')
export class OrganizationPublicPhotosController {
  constructor(private readonly org: OrganizationsService) {}

  @Get(':id/photos/:filename')
  async getPhotoFile(
    @Param('id') id: string,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    const safe = filename.trim();
    if (!safe || safe !== filename || /[\\/]|\.\./.test(safe)) {
      throw new BadRequestException('Некорректное имя файла');
    }
    const filePath = await this.org.getPhotoPath(id, safe);
    if (!filePath) return res.status(404).send('Not found');
    return res.sendFile(filePath);
  }
}
