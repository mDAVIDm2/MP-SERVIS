import { Controller, ForbiddenException, Get, Param, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { User } from '../users/user.entity';
import { CarTransferService } from '../users/car-transfer.service';

/**
 * Справочная информация для Business-приложения по автомобилю клиента (передача владельца в клиентском приложении).
 */
@Controller('organizations')
@UseGuards(AuthGuard('jwt'))
export class OrganizationClientCarInsightController {
  constructor(private readonly transfers: CarTransferService) {}

  private assertActiveOrganizationAccess(user: User, orgId: string) {
    if (!user.organizationId || user.organizationId !== orgId) {
      throw new ForbiddenException('Выберите эту организацию как активную в приложении');
    }
  }

  @Get(':orgId/client-cars/:carId/transfer-insight')
  async transferInsight(
    @Param('orgId') orgId: string,
    @Param('carId') carId: string,
    @Req() req: { user: User },
  ) {
    this.assertActiveOrganizationAccess(req.user, orgId);
    return this.transfers.getStaffCarTransferInsight(carId);
  }
}
