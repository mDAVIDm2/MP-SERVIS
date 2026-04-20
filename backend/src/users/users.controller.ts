import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  Put,
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
    const payload = { ...this.users.profileResponse(u, summaries) } as Record<string, unknown>;
    await this.users.appendStaffCapabilities(u, payload);
    return payload;
  }

  @Post('avatar')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async uploadAvatar(@Req() req: { user: User }, @UploadedFile() file: Express.Multer.File) {
    if (!file || (!file.buffer && !file.path)) {
      throw new BadRequestException('Передайте изображение в поле file');
    }
    const user = await this.users.saveUserAvatar(req.user.id, file);
    const summaries = await this.users.getOrganizationSummariesForUser(user);
    const payload = { ...this.users.profileResponse(user, summaries) } as Record<string, unknown>;
    await this.users.appendStaffCapabilities(user, payload);
    return payload;
  }

  @Get('avatar/:userId/:filename')
  async getAvatarFile(
    @Param('userId') userId: string,
    @Param('filename') filename: string,
    @Req() req: { user: User },
    @Res() res: Response,
  ) {
    if (req.user.id !== userId) {
      const ok = await this.users.canStaffFetchClientAvatar(req.user, userId);
      if (!ok) {
        throw new ForbiddenException('Нет доступа к этому аватару');
      }
    }
    const filePath = this.users.getUserAvatarFilePath(userId, filename);
    if (!filePath) {
      return res.status(404).send('Not found');
    }
    res.setHeader('Cache-Control', 'private, no-store, no-cache, must-revalidate');
    return res.sendFile(filePath);
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
    const payload = { ...this.users.profileResponse(user, summaries) } as Record<string, unknown>;
    await this.users.appendStaffCapabilities(user, payload);
    return payload;
  }

  /** Удаление своего аккаунта (Business и Client — с подтверждением в приложении). */
  @Delete('delete')
  async deleteAccount(@Req() req: { user: User }) {
    await this.users.deleteOwnAccount(req.user.id);
    return { ok: true };
  }

  @Post('switch-organization')
  async switchOrganization(@Req() req: { user: User }, @Body() body: { organization_id?: string }) {
    const orgId = body?.organization_id?.trim();
    if (!orgId) throw new BadRequestException('organization_id обязателен');
    const next = await this.users.switchActiveOrganization(req.user.id, orgId);
    const summaries = await this.users.getOrganizationSummariesForUser(next);
    const payload = { ...this.users.profileResponse(next, summaries) } as Record<string, unknown>;
    await this.users.appendStaffCapabilities(next, payload);
    return payload;
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

  /** Полный снимок настроек клиентского приложения (синхронизация между устройствами). */
  @Get('client-app-state')
  async getClientAppState(@Req() req: { user: User }) {
    return this.users.getClientAppState(req.user.id);
  }

  @Put('client-app-state')
  async putClientAppState(@Req() req: { user: User }, @Body() body: { payload?: Record<string, unknown> }) {
    const payload = body?.payload;
    if (payload == null || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new BadRequestException('Передайте объект payload');
    }
    return this.users.putClientAppState(req.user.id, payload as Record<string, unknown>);
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
    const payload = { ...this.users.profileResponse(user, summaries) } as Record<string, unknown>;
    await this.users.appendStaffCapabilities(user, payload);
    return payload;
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
    const payload = { ...this.users.profileResponse(user, summaries) } as Record<string, unknown>;
    await this.users.appendStaffCapabilities(user, payload);
    return payload;
  }

  @Post('invitations/:id/decline')
  async declineInvitation(@Param('id') invitationId: string, @Req() req: { user: User }) {
    if (!invitationId) throw new BadRequestException('id приглашения обязателен');
    return this.users.declineInvitation(req.user.id, invitationId);
  }
}
