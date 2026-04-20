import { Body, Controller, Get, NotFoundException, Param, Patch, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { UsersService } from '../users/users.service';
import { BusinessRole } from '../users/user.entity';

const ROLE_LABELS: Record<BusinessRole, string> = {
  owner: 'Владелец',
  admin: 'Администратор',
  master: 'Мастер',
  solo: 'Клиент',
};

@Controller('internal/users')
@UseGuards(InternalJwtAuthGuard)
export class InternalUsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  async list() {
    const list = await this.users.findAll();
    return {
      items: list.map((u) => {
        const isBusiness = u.organizationId != null || u.role !== 'solo';
        return {
          id: u.id,
          phone: u.phone,
          name: u.name,
          role: u.role,
          role_label: ROLE_LABELS[u.role] ?? u.role,
          account_type: isBusiness ? 'business' : 'client',
          organization_id: u.organizationId,
          organization_name: (u as any).organization?.name ?? null,
          avatar_url: u.avatarUrl ?? null,
        };
      }),
    };
  }

  /** Файл аватара для Control Center (JWT оператора). Путь выше :id, чтобы не перехватывался как uuid. */
  @Get(':id/avatar/:filename')
  async avatarFile(@Param('id') userId: string, @Param('filename') filename: string, @Res() res: Response) {
    const fp = this.users.getUserAvatarFilePath(userId, filename);
    if (!fp) throw new NotFoundException();
    return res.sendFile(fp);
  }

  @Get(':id')
  async getOne(@Param('id') id: string) {
    return this.users.getInternalUserDetail(id);
  }

  @Patch(':id')
  async patch(@Param('id') id: string, @Body() body: { name?: string; clear_avatar?: boolean }) {
    const exists = await this.users.findById(id);
    if (!exists) throw new NotFoundException('Пользователь не найден');
    if (body.clear_avatar === true) {
      await this.users.clearUserAvatar(id);
    }
    if (body.name != null && String(body.name).trim().length > 0) {
      const ok = await this.users.updateInternalUserDisplayName(id, String(body.name).trim());
      if (!ok) throw new NotFoundException('Пользователь не найден');
    }
    return this.users.getInternalUserDetail(id);
  }
}
