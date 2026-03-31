import { Controller, Get, UseGuards } from '@nestjs/common';
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
        const isBusiness = u.organizationId != null || (u.role !== 'solo');
        return {
          id: u.id,
          phone: u.phone,
          name: u.name,
          role: u.role,
          role_label: ROLE_LABELS[u.role] ?? u.role,
          account_type: isBusiness ? 'business' : 'client',
          organization_id: u.organizationId,
          organization_name: (u as any).organization?.name ?? null,
        };
      }),
    };
  }
}
