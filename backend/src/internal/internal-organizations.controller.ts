import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { OrganizationsService } from '../organizations/organizations.service';
import { Organization } from '../organizations/organization.entity';
import { normalizePlanKey } from '../subscriptions/plan-definitions';

function toOrgDto(o: Organization) {
  return {
    id: o.id,
    name: o.name,
    address: o.address ?? '',
    phone: o.phone ?? '',
    working_hours: o.workingHours ?? '',
    timezone: o.timezone ?? 'Europe/Moscow',
    latitude: o.latitude ?? null,
    longitude: o.longitude ?? null,
    photo_urls: o.photoUrls ?? null,
  };
}

@Controller('internal/organizations')
@UseGuards(InternalJwtAuthGuard)
export class InternalOrganizationsController {
  constructor(private readonly org: OrganizationsService) {}

  @Get()
  async list() {
    const list = await this.org.findAll();
    const subs = await this.org.findAllSubscriptions();
    const subByOrg = new Map(subs.map((s) => [s.organization_id, s]));
    return {
      items: list.map((o) => ({
        ...toOrgDto(o),
        subscription: subByOrg.get(o.id)
          ? {
              is_active: subByOrg.get(o.id)!.is_active,
              status: subByOrg.get(o.id)!.status,
              end_date: subByOrg.get(o.id)!.end_date,
              plan_key: normalizePlanKey((subByOrg.get(o.id) as any).plan_key),
              limits_override: (subByOrg.get(o.id) as any).limits_override ?? null,
            }
          : null,
      })),
    };
  }

  @Get(':id')
  async getOne(@Param('id') id: string) {
    const org = await this.org.findOne(id);
    if (!org) throw new NotFoundException('Организация не найдена');
    const [staff, subs, subscription_usage] = await Promise.all([
      this.org.getStaff(id),
      this.org.findAllSubscriptions(),
      this.org.getSubscriptionUsageSummary(id).catch(() => null),
    ]);
    const sub = subs.find((s) => s.organization_id === id);
    return {
      ...toOrgDto(org),
      staff: staff.items,
      subscription: sub
        ? {
            id: sub.id,
            is_active: sub.is_active,
            status: sub.status,
            start_date: sub.start_date,
            end_date: sub.end_date,
            plan_key: (sub as any).plan_key ?? 'team',
            limits_override: (sub as any).limits_override ?? null,
          }
        : null,
      subscription_usage,
    };
  }

  /** Удалить одно фото по полному URL из списка или все фото точки (`?all=1`). */
  @Delete(':id/photos')
  async deletePhotos(@Param('id') id: string, @Query('all') all?: string, @Query('url') url?: string) {
    if (all === '1' || all === 'true') {
      await this.org.clearAllOrganizationPhotos(id);
      return { ok: true };
    }
    const u = String(url || '').trim();
    if (u.length > 0) {
      const ok = await this.org.removePhoto(id, u);
      return { ok };
    }
    throw new BadRequestException('Укажите query all=1 или url=<полный URL фото>');
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body()
    body: {
      name?: string;
      address?: string;
      phone?: string;
      working_hours?: string;
      timezone?: string;
      latitude?: number | null;
      longitude?: number | null;
    },
  ) {
    const updated = await this.org.update(id, {
      name: body.name,
      address: body.address,
      phone: body.phone,
      working_hours: body.working_hours,
      timezone: body.timezone,
      latitude: body.latitude,
      longitude: body.longitude,
    });
    return updated ? toOrgDto(updated) : null;
  }

  @Get(':id/staff')
  async getStaff(@Param('id') id: string) {
    return this.org.getStaff(id);
  }
}
