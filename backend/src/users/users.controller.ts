import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { User } from './user.entity';
import { UsersService } from './users.service';
import { ClientNotificationPreferences } from '../notifications/client-notification-preferences';
import { OrganizationsService } from '../organizations/organizations.service';

@Controller('profile')
@UseGuards(AuthGuard('jwt'))
export class UsersController {
  constructor(
    private users: UsersService,
    private organizations: OrganizationsService,
  ) {}

  /** Те же тарифы, что GET /organizations/subscription-plans — удобно при создании организации из профиля. */
  @Get('subscription-plans')
  listSubscriptionPlans() {
    return this.organizations.listSubscriptionPlansPublic();
  }

  @Get()
  async getProfile(@Req() req: { user: User }) {
    const u = req.user;
    const summaries = await this.users.getOrganizationSummariesForUser(u);
    return this.users.profileResponse(u, summaries);
  }

  @Patch()
  async patchProfile(
    @Req() req: { user: User },
    @Body() body: { name?: string; phone?: string },
  ) {
    if (
      (body.name == null || String(body.name).trim() === '') &&
      (body.phone == null || String(body.phone).trim() === '')
    ) {
      throw new BadRequestException('Передайте name и/или phone');
    }
    const user = await this.users.updateOwnProfile(req.user.id, {
      name: body.name,
      phone: body.phone,
    });
    const summaries = await this.users.getOrganizationSummariesForUser(user);
    return this.users.profileResponse(user, summaries);
  }

  /** Удаление своего аккаунта (только клиентское приложение, не Business). */
  @Delete('delete')
  async deleteAccount(@Req() req: { user: User }, @Headers('x-autohub-app') app?: string) {
    if (String(app ?? '').toLowerCase() === 'business') {
      throw new ForbiddenException('Удаление через приложение СТО недоступно. Обратитесь в поддержку.');
    }
    await this.users.deleteOwnAccount(req.user.id);
    return { ok: true };
  }

  @Post('switch-organization')
  async switchOrganization(@Req() req: { user: User }, @Body() body: { organization_id?: string }) {
    const orgId = body?.organization_id?.trim();
    if (!orgId) throw new BadRequestException('organization_id обязателен');
    const next = await this.users.switchActiveOrganization(req.user.id, orgId);
    const summaries = await this.users.getOrganizationSummariesForUser(next);
    return this.users.profileResponse(next, summaries);
  }

  @Get('notification-preferences')
  async getNotificationPreferences(@Req() req: { user: User }) {
    return this.users.getNotificationPreferences(req.user.id);
  }

  @Patch('notification-preferences')
  async patchNotificationPreferences(
    @Req() req: { user: User },
    @Body() body: Partial<ClientNotificationPreferences>,
  ) {
    return this.users.updateNotificationPreferences(req.user.id, body ?? {});
  }

  @Post('organizations')
  async createOrganization(
    @Req() req: { user: User },
    @Body() body: { name?: string; address?: string; phone?: string; plan_key?: string },
  ) {
    const name = body?.name?.trim();
    if (!name) throw new BadRequestException('Укажите название организации');
    const { user, summaries } = await this.users.createOwnedOrganization(req.user.id, {
      name,
      address: body?.address,
      phone: body?.phone,
      plan_key: body?.plan_key,
    });
    return this.users.profileResponse(user, summaries);
  }

  @Get('invitations')
  async incomingInvitations(@Req() req: { user: User }) {
    return this.users.getIncomingInvitations(req.user.id);
  }

  @Post('invitations/:id/accept')
  async acceptInvitation(
    @Param('id') invitationId: string,
    @Req() req: { user: User },
    @Body() body: { set_active_organization?: boolean },
  ) {
    if (!invitationId) throw new BadRequestException('id приглашения обязателен');
    const { user, summaries } = await this.users.acceptInvitation(req.user.id, invitationId, {
      set_active_organization: body?.set_active_organization !== false,
    });
    return this.users.profileResponse(user, summaries);
  }

  @Post('invitations/:id/decline')
  async declineInvitation(@Param('id') invitationId: string, @Req() req: { user: User }) {
    if (!invitationId) throw new BadRequestException('id приглашения обязателен');
    return this.users.declineInvitation(req.user.id, invitationId);
  }
}
