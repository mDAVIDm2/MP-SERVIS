import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  NotFoundException,
  Query,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { User } from '../users/user.entity';
import { OrganizationsService } from './organizations.service';

@Controller('organizations')
@UseGuards(AuthGuard('jwt'))
export class OrganizationsController {
  constructor(private org: OrganizationsService) {}

  private assertActiveOrganizationAccess(user: User, orgId: string) {
    if (!user.organizationId || user.organizationId !== orgId) {
      throw new ForbiddenException('Выберите эту организацию как активную в приложении');
    }
  }

  /** Справочник тарифов для выбора при создании организации / смене плана. */
  @Get('subscription-plans')
  listSubscriptionPlans() {
    return this.org.listSubscriptionPlansPublic();
  }

  /**
   * Понижение тарифа: задать новый plan_key и список staff id, которые остаются активными.
   * Остальные сотрудники переводятся в неактивные (их можно снова включить в пределах лимита).
   */
  @Post(':id/subscription/apply-plan-with-staff')
  async applyPlanWithStaff(
    @Param('id') id: string,
    @Req() req: { user: User },
    @Body() body: { plan_key?: string; keep_active_staff_ids?: string[] },
  ) {
    this.assertActiveOrganizationAccess(req.user, id);
    this.org.ensureCallerCanManageOrganizationStaff(req.user);
    const pk = body?.plan_key?.trim();
    if (!pk) throw new BadRequestException('Укажите plan_key');
    return this.org.applySubscriptionPlanWithActiveStaff(id, {
      plan_key: pk,
      keep_active_staff_ids: Array.isArray(body?.keep_active_staff_ids) ? body.keep_active_staff_ids : [],
    });
  }

  @Get(':id')
  async get(@Param('id') id: string, @Req() req: { user: User }) {
    this.assertActiveOrganizationAccess(req.user, id);
    const o = await this.org.findOne(id);
    if (!o) throw new Error('Not found');
    const photoUrls = this.org.getPhotoUrls(o);
    const subscription_usage = await this.org.getSubscriptionUsageSummary(id);
    return {
      name: o.name,
      address: o.address,
      phone: o.phone,
      working_hours: o.workingHours,
      working_hours_week: (o as any).workingHoursWeek ?? null,
      working_hours_exceptions: (o as any).workingHoursExceptions ?? null,
      timezone: (o as any).timezone ?? 'Europe/Moscow',
      photo_urls: photoUrls,
      latitude: (o as any).latitude ?? null,
      longitude: (o as any).longitude ?? null,
      business_kind: (o as any).businessKind ?? 'sto',
      scheduling_mode: (o as any).schedulingMode ?? 'staff_based',
      subscription_usage,
    };
  }

  @Post(':id/photos')
  @UseInterceptors(FileInterceptor('file'))
  async addPhoto(@Param('id') id: string, @Req() req: { user: User }, @UploadedFile() file: Express.Multer.File) {
    this.assertActiveOrganizationAccess(req.user, id);
    if (!file || (!file.buffer && !file.path)) throw new Error('No file');
    const result = await this.org.addPhoto(id, file);
    if (!result) throw new Error('Not found');
    return result;
  }

  @Delete(':id/photos')
  async deletePhoto(
    @Param('id') id: string,
    @Req() req: { user: User },
    @Body() body: { url?: string },
  ) {
    this.assertActiveOrganizationAccess(req.user, id);
    const url = typeof body?.url === 'string' ? body.url.trim() : '';
    if (!url) throw new BadRequestException('Укажите url фото');
    const ok = await this.org.removePhoto(id, url);
    if (!ok) throw new NotFoundException('Фото не найдено или уже удалено');
    return { ok: true };
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Req() req: { user: User },
    @Body() body: {
      name?: string;
      address?: string;
      phone?: string;
      working_hours?: string;
      working_hours_week?: Array<{ open?: string; close?: string; closed?: boolean }> | null;
      working_hours_exceptions?: Array<{ date?: string; closed?: boolean; open?: string; close?: string }> | null;
      timezone?: string;
      latitude?: number | null;
      longitude?: number | null;
      business_kind?: string;
      scheduling_mode?: string;
    },
  ) {
    this.assertActiveOrganizationAccess(req.user, id);
    const o = await this.org.update(id, body);
    if (!o) throw new Error('Not found');
    const subscription_usage = await this.org.getSubscriptionUsageSummary(id);
    return {
      name: o.name,
      address: o.address,
      phone: o.phone,
      working_hours: o.workingHours,
      working_hours_week: (o as any).workingHoursWeek ?? null,
      working_hours_exceptions: (o as any).workingHoursExceptions ?? null,
      timezone: (o as any).timezone ?? 'Europe/Moscow',
      latitude: (o as any).latitude ?? null,
      longitude: (o as any).longitude ?? null,
      business_kind: (o as any).businessKind ?? 'sto',
      scheduling_mode: (o as any).schedulingMode ?? 'staff_based',
      subscription_usage,
    };
  }

  @Get(':id/staff')
  async getStaff(@Param('id') id: string, @Req() req: { user: User }) {
    this.assertActiveOrganizationAccess(req.user, id);
    return this.org.getStaffForCaller(id, req.user);
  }

  @Post(':id/staff/add-me-as-master')
  async addMeAsMaster(@Param('id') id: string, @Req() req: { user: User }) {
    this.assertActiveOrganizationAccess(req.user, id);
    const user = req.user;
    return this.org.addCurrentUserAsMaster(id, {
      id: user.id,
      name: user.name,
      phone: user.phone,
      organizationId: user.organizationId,
      role: user.role,
    });
  }

  @Post(':id/staff')
  async inviteStaff(
    @Param('id') id: string,
    @Req() req: { user: User },
    @Body() body: { name?: string; phone?: string; email?: string; role: string; message?: string; expires_in_days?: number },
  ) {
    this.assertActiveOrganizationAccess(req.user, id);
    return this.org.createInvitation(id, req.user, body);
  }

  @Patch(':id/staff/:staffId')
  async updateStaff(
    @Param('id') id: string,
    @Param('staffId') staffId: string,
    @Req() req: { user: User },
    @Body() body: Record<string, unknown>,
  ) {
    this.assertActiveOrganizationAccess(req.user, id);
    return this.org.updateStaffMember(id, staffId, body as any, req.user);
  }

  @Get(':id/invitations')
  async getInvitations(
    @Param('id') id: string,
    @Req() req: { user: User },
    @Query('status') status?: 'pending' | 'accepted' | 'declined' | 'cancelled' | 'expired',
  ) {
    this.assertActiveOrganizationAccess(req.user, id);
    return this.org.listInvitations(id, req.user, status);
  }

  @Post(':id/invitations/:invitationId/cancel')
  async cancelInvitation(
    @Param('id') id: string,
    @Param('invitationId') invitationId: string,
    @Req() req: { user: User },
  ) {
    this.assertActiveOrganizationAccess(req.user, id);
    return this.org.cancelInvitation(id, invitationId, req.user);
  }

  @Get(':id/settings')
  async getSettings(@Param('id') id: string, @Req() req: { user: User }) {
    this.assertActiveOrganizationAccess(req.user, id);
    return { data: await this.org.getSettings(id) };
  }

  @Patch(':id/settings')
  async updateSettings(@Param('id') id: string, @Req() req: { user: User }, @Body() body: Record<string, unknown>) {
    this.assertActiveOrganizationAccess(req.user, id);
    return { data: await this.org.updateSettings(id, body) };
  }
}
