import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { DateTime } from 'luxon';
import { StaffMember } from '../organizations/staff-member.entity';
import { MasterSchedule } from '../organizations/master-schedule.entity';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { OrganizationsService } from '../organizations/organizations.service';
import { normalizeSchedulingMode } from '../organizations/organization-scheduling';
import { effectiveBayCountFromSlots } from '../organizations/bay-settings.util';
import { Skill } from '../shared/skill.enum';

export interface ServiceItemInput {
  service_id?: string;
  estimated_minutes: number;
  required_skill?: string;
}

export interface AvailableSlotsDto {
  organization_id: string;
  date: string; // YYYY-MM-DD
  service_ids?: string[];
  items?: ServiceItemInput[];
}

export interface TimeSlot {
  start: string; // ISO
  end: string;
  master_id: string;
  master_name: string;
  /** staff_based | bay_based — как интерпретировать слот на клиенте */
  scheduling_mode?: string;
}

function parseTime(t: string): number {
  const [h, m] = t.split(':').map(Number);
  return (h ?? 0) * 60 + (m ?? 0);
}

type SlotServiceRow = { id: string; duration_minutes?: number; required_skill?: string };
type SlotPackageAddon = { service_id?: string; extra_duration_minutes?: number };
type SlotPackageRow = {
  included_service_ids?: string[];
  package_duration_minutes?: number;
  addons?: SlotPackageAddon[];
};

/**
 * Если набор service_ids — это комплекс (все входящие услуги + выбранные допы из этого комплекта),
 * длительность визита = package_duration_minutes (или сумма входящих) + extra_duration по каждому допу,
 * а не сумма duration_minutes всех строк прайса (иначе слоты «съезжают» на часы).
 */
function tryResolvePackageBookingMinutes(
  serviceIds: string[],
  services: SlotServiceRow[],
  packages: SlotPackageRow[],
): number | null {
  const incomingArr = [...new Set(serviceIds.filter((x) => x && String(x).trim()))];
  if (incomingArr.length === 0 || !packages.length) return null;
  const incomingSet = new Set(incomingArr);

  const svcById = new Map(services.map((s) => [s.id, s]));
  const durationOf = (id: string) => {
    const n = Number(svcById.get(id)?.duration_minutes);
    return Number.isFinite(n) && n > 0 ? n : 60;
  };

  pkgLoop: for (const pkg of packages) {
    const incl = (pkg.included_service_ids ?? []).filter((x) => x && String(x).trim());
    const inclSet = new Set(incl);
    const addonList = pkg.addons ?? [];
    const addonBySvc = new Map<string, SlotPackageAddon>();
    for (const a of addonList) {
      const sid = a.service_id?.trim();
      if (sid) addonBySvc.set(sid, a);
    }
    const allowedAddonIds = new Set(addonBySvc.keys());
    const allowed = new Set<string>([...inclSet, ...allowedAddonIds]);

    const allIncomingAllowed = [...incomingSet].every((id) => allowed.has(id));
    if (!allIncomingAllowed) continue;

    for (const id of inclSet) {
      if (!incomingSet.has(id)) continue pkgLoop;
    }

    const extras = [...incomingSet].filter((id) => !inclSet.has(id));
    if (!extras.every((id) => allowedAddonIds.has(id))) continue;

    const pkgDur = Number(pkg.package_duration_minutes);
    const base = pkgDur > 0 ? pkgDur : incl.reduce((sum, id) => sum + durationOf(id), 0);

    let total = base;
    for (const aid of extras) {
      const ad = addonBySvc.get(aid);
      const extraRaw = ad != null ? Number(ad.extra_duration_minutes) : NaN;
      const extra = Number.isFinite(extraRaw) && extraRaw > 0 ? extraRaw : durationOf(aid);
      total += extra;
    }
    return total;
  }
  return null;
}

function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

/** Проверка пересечения слота [slotStartMs, slotEndMs) с занятыми интервалами */
function isOverlapping(
  slotStartMs: number,
  slotEndMs: number,
  merged: [Date, Date][],
): boolean {
  return merged.some(([bs, be]) => slotStartMs < be.getTime() && slotEndMs > bs.getTime());
}

@Injectable()
export class BookingService {
  constructor(
    @InjectRepository(StaffMember) private staffRepo: Repository<StaffMember>,
    @InjectRepository(MasterSchedule) private scheduleRepo: Repository<MasterSchedule>,
    @InjectRepository(Order) private orderRepo: Repository<Order>,
    @InjectRepository(OrderItem) private orderItemRepo: Repository<OrderItem>,
    private orgService: OrganizationsService,
  ) {}

  /**
   * Найти свободные слоты: суммарное время работ, требуемые навыки,
   * мастера на смене с этими навыками, исключая пересечения с другими заказами.
   * Слоты выдаются с шагом slot_duration_minutes (по умолчанию 30), чтобы клиент
   * видел все доступные начала приёма (09:00, 09:30, 10:00, ...), а не одно на окно.
   */
  async getAvailableSlots(dto: AvailableSlotsDto): Promise<{
    slots: TimeSlot[];
    total_minutes: number;
    required_skills: string[];
    slot_duration_minutes: number;
    work_day_start: string;
    work_day_end: string;
    scheduling_mode: string;
    bay_count?: number;
  }> {
    let totalMinutes = 0;
    let requiredSkills: string[] = [];

    const org = await this.orgService.findOne(dto.organization_id);
    const timezone = (org as any)?.timezone ?? 'Europe/Moscow';
    const schedulingMode = normalizeSchedulingMode((org as any)?.schedulingMode);

    const settings = (await this.orgService.getSettings(dto.organization_id)) as {
      services?: Array<{ id: string; duration_minutes?: number; required_skill?: string }>;
      service_packages?: SlotPackageRow[];
      slots?: {
        slot_duration_minutes?: number;
        work_day_start?: string;
        work_day_end?: string;
        bay_count?: number;
      };
    };
    const slotDurationMinutes = Math.max(15, Number(settings?.slots?.slot_duration_minutes) || 30);
    const slotsBlock = settings?.slots;
    const orgWorkStart = settings?.slots?.work_day_start ? parseTime(settings.slots.work_day_start) : null;
    const orgWorkEnd = settings?.slots?.work_day_end ? parseTime(settings.slots.work_day_end) : null;

    if (dto.service_ids?.length) {
      const servicesList = settings?.services ?? [];
      const services = Array.isArray(servicesList) ? servicesList : [];
      const packages = Array.isArray(settings?.service_packages) ? settings.service_packages : [];
      const packageMinutes = tryResolvePackageBookingMinutes(dto.service_ids, services, packages);
      if (packageMinutes != null) {
        totalMinutes = packageMinutes;
        for (const sid of dto.service_ids) {
          const s = services.find((x: { id: string }) => x.id === sid);
          if (s) {
            const skill = (s as any).required_skill;
            if (skill && !requiredSkills.includes(skill)) requiredSkills.push(skill);
          }
        }
      } else {
        for (const sid of dto.service_ids) {
          const s = services.find((x: { id: string }) => x.id === sid);
          if (s) {
            totalMinutes += Number(s.duration_minutes) ?? 60;
            const skill = (s as any).required_skill;
            if (skill && !requiredSkills.includes(skill)) requiredSkills.push(skill);
          }
        }
      }
      if (requiredSkills.length === 0) requiredSkills = [Skill.MAINTENANCE];
    } else if (dto.items?.length) {
      for (const item of dto.items) {
        const min = Number(item.estimated_minutes);
        totalMinutes += (Number.isNaN(min) ? 60 : (min ?? 60));
        const skill = item.required_skill;
        if (skill && !requiredSkills.includes(skill)) requiredSkills.push(skill);
      }
      if (requiredSkills.length === 0) requiredSkills = [Skill.MAINTENANCE];
    } else {
      // Нет ни service_ids, ни items — считаем по умолчанию 1 час, чтобы клиент видел слоты.
      totalMinutes = 60;
      requiredSkills = [Skill.MAINTENANCE];
    }

    // ШАГ 1: Границы дня в часовом поясе СТО (из БД), затем в UTC для запросов и слотов.
    const parts = dto.date.split('-').map((x) => parseInt(x, 10));
    const y = parts[0];
    const m = parts[1] ?? 1;
    const d = parts[2] ?? 1;
    const dayStartLocal = DateTime.fromObject({ year: y, month: m, day: d }, { zone: timezone }).startOf('day');
    const wdStartStr = settings?.slots?.work_day_start ?? '09:00';
    const wdEndStr = settings?.slots?.work_day_end ?? '20:00';
    const bayCount = effectiveBayCountFromSlots(slotsBlock);
    const emptyMeta = {
      slots: [] as TimeSlot[],
      total_minutes: totalMinutes,
      required_skills: requiredSkills,
      slot_duration_minutes: slotDurationMinutes,
      work_day_start: wdStartStr,
      work_day_end: wdEndStr,
      scheduling_mode: schedulingMode,
      bay_count: schedulingMode === 'bay_based' ? bayCount : undefined,
    };
    if (!dayStartLocal.isValid) return emptyMeta;
    const dayEndLocal = dayStartLocal.plus({ days: 1 });
    const dayStart = dayStartLocal.toUTC().toJSDate();
    const dayEnd = dayEndLocal.toUTC().toJSDate();
    const dayOfWeek = dayStartLocal.weekday === 7 ? 0 : dayStartLocal.weekday;

    if (schedulingMode === 'bay_based') {
      return this.computeBayBasedSlots({
        organizationId: dto.organization_id,
        dayStartLocal,
        dayStart,
        dayEnd,
        totalMinutes,
        slotDurationMinutes,
        wdStartStr,
        wdEndStr,
        requiredSkills,
        bayCount,
      });
    }

    const masters = await this.staffRepo.find({
      where: { organizationId: dto.organization_id, isActive: true, role: 'master' },
    });
    const mastersWithSkills = masters.filter((m) => {
      const skills = Array.isArray((m as any).skills) ? (m as any).skills : [];
      return requiredSkills.every((need) => skills.includes(need));
    });
    if (mastersWithSkills.length === 0) {
      return { ...emptyMeta, scheduling_mode: 'staff_based' as const };
    }

    const masterIds = mastersWithSkills.map((x) => x.id);
    const schedules = await this.scheduleRepo.find({
      where: { masterId: In(masterIds), dayOfWeek, isWorkingDay: true },
    });
    const scheduleByMaster = new Map<string, { start: number; end: number }>();
    for (const sch of schedules) {
      let start = parseTime(sch.startTime);
      let end = parseTime(sch.endTime);
      // Пересечение с окном организации: нельзя «растягивать» смену мастера за пределы org work_day.
      if (orgWorkStart != null && orgWorkEnd != null) {
        start = Math.max(start, orgWorkStart);
        end = Math.min(end, orgWorkEnd);
      }
      if (end <= start) continue;
      const existing = scheduleByMaster.get(sch.masterId);
      if (!existing || start < existing.start) scheduleByMaster.set(sch.masterId, { start, end });
    }

    // Запрос заказов на запрошенную дату: пересечение [dayStart, dayEnd) с интервалом заказа (plannedStartTime..plannedEndTime или dateTime..+1ч)
    const ordersOnDay = await this.orderRepo
      .createQueryBuilder('order')
      .where('order.organization_id = :orgId', { orgId: dto.organization_id })
      .andWhere('order.status IN (:...statuses)', {
        statuses: ['pending_confirmation', 'confirmed', 'in_progress', 'pending_approval', 'completed'],
      })
      .andWhere(
        'COALESCE(order.planned_start_time, order.date_time) < :dayEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :dayStart',
        { dayStart: dayStart.toISOString(), dayEnd: dayEnd.toISOString() },
      )
      .getMany();

    // Занятость только по заказам с назначенным мастером. Заказы без мастера учитываются при подсчёте «свободных мест».
    const busyByMaster = new Map<string, [Date, Date][]>();
    const addBusyInterval = (masterId: string, startDate: Date, endDate: Date) => {
      const clipStart = new Date(Math.max(startDate.getTime(), dayStart.getTime()));
      const clipEnd = new Date(Math.min(endDate.getTime(), dayEnd.getTime()));
      if (clipStart >= clipEnd) return;
      if (!busyByMaster.has(masterId)) busyByMaster.set(masterId, []);
      busyByMaster.get(masterId)!.push([clipStart, clipEnd]);
    };
    for (const o of ordersOnDay) {
      const start = (o as any).plannedStartTime ?? (o as any).dateTime;
      const end = (o as any).plannedEndTime ?? addMinutes(start instanceof Date ? start : new Date(start), 60);
      const startDate = start instanceof Date ? start : new Date(start);
      const endDate = end instanceof Date ? end : new Date(end);
      const masterId = (o as any).masterId ?? null;
      if (masterId) addBusyInterval(masterId, startDate, endDate);
    }

    const mastersOnShift = mastersWithSkills.filter((m) => scheduleByMaster.has(m.id));
    const mastersOnShiftCount = mastersOnShift.length;
    const totalMs = totalMinutes * 60 * 1000;
    const stepMs = slotDurationMinutes * 60 * 1000;

    const orderIntervals = ordersOnDay.map((o) => {
      const start = (o as any).plannedStartTime ?? (o as any).dateTime;
      const end = (o as any).plannedEndTime ?? addMinutes(start instanceof Date ? start : new Date(start), 60);
      return [new Date(start instanceof Date ? start : new Date(start)), new Date(end instanceof Date ? end : new Date(end))] as [Date, Date];
    });

    const countOrdersOverlapping = (slotStartMs: number, slotEndMs: number): number => {
      return orderIntervals.filter(([s, e]) => slotStartMs < e.getTime() && slotEndMs > s.getTime()).length;
    };

    const mergedByMaster = new Map<string, [Date, Date][]>();
    for (const master of mastersOnShift) {
      const busy = busyByMaster.get(master.id) ?? [];
      busy.sort((a: [Date, Date], b: [Date, Date]) => a[0].getTime() - b[0].getTime());
      const merged: [Date, Date][] = [];
      for (const [s, e] of busy) {
        if (merged.length && s.getTime() <= merged[merged.length - 1][1].getTime()) {
          merged[merged.length - 1][1] = new Date(Math.max(merged[merged.length - 1][1].getTime(), e.getTime()));
        } else {
          merged.push([s, e]);
        }
      }
      mergedByMaster.set(master.id, merged);
      console.log('Занятые интервалы мастера:', master.name, merged.map(([a, b]) => [a.toISOString(), b.toISOString()]));
    }

    const allSlotStarts: number[] = [];
    for (const master of mastersOnShift) {
      const work = scheduleByMaster.get(master.id)!;
      const localH = Math.floor(work.start / 60);
      const localMin = work.start % 60;
      const workStartLocal = dayStartLocal.set({ hour: localH, minute: localMin, second: 0, millisecond: 0 });
      const endH = Math.floor(work.end / 60);
      const endMin = work.end % 60;
      const workEndLocal = dayStartLocal.set({ hour: endH, minute: endMin, second: 0, millisecond: 0 });
      const workStartMs = workStartLocal.toUTC().toMillis();
      const workEndMs = workEndLocal.toUTC().toMillis();
      for (let t = workStartMs; t + totalMs <= workEndMs; t += stepMs) allSlotStarts.push(t);
    }
    const uniqueSlotStarts = [...new Set(allSlotStarts)].sort((a, b) => a - b);

    const masterWorkWindow = new Map<string, { start: number; end: number }>();
    for (const master of mastersOnShift) {
      const work = scheduleByMaster.get(master.id)!;
      const localH = Math.floor(work.start / 60);
      const localMin = work.start % 60;
      const workStartLocal = dayStartLocal.set({ hour: localH, minute: localMin, second: 0, millisecond: 0 });
      const endH = Math.floor(work.end / 60);
      const endMin = work.end % 60;
      const workEndLocal = dayStartLocal.set({ hour: endH, minute: endMin, second: 0, millisecond: 0 });
      masterWorkWindow.set(master.id, {
        start: workStartLocal.toUTC().toMillis(),
        end: workEndLocal.toUTC().toMillis(),
      });
    }

    const slots: TimeSlot[] = [];
    for (const slotStartMs of uniqueSlotStarts) {
      const slotEndMs = slotStartMs + totalMs;
      const overlappingOrders = countOrdersOverlapping(slotStartMs, slotEndMs);
      const mastersOnShiftAtSlot = mastersOnShift.filter((m) => {
        const w = masterWorkWindow.get(m.id)!;
        return slotStartMs >= w.start && slotEndMs <= w.end;
      });
      const freeCapacity = mastersOnShiftAtSlot.length - overlappingOrders;
      if (freeCapacity <= 0) continue;

      const freeMasters = mastersOnShiftAtSlot.filter((m) => {
        const merged = mergedByMaster.get(m.id) ?? [];
        return !isOverlapping(slotStartMs, slotEndMs, merged);
      });
      const toEmit = Math.min(freeCapacity, freeMasters.length);
      for (let i = 0; i < toEmit; i++) {
        const master = freeMasters[i];
        slots.push({
          start: new Date(slotStartMs).toISOString(),
          end: new Date(slotEndMs).toISOString(),
          master_id: master.id,
          master_name: master.name,
          scheduling_mode: 'staff_based',
        });
      }
    }
    slots.sort((a, b) => a.start.localeCompare(b.start));

    // ——— Диагностика и предупреждение о заказах на дату ———
    const mastersOnDate = mastersWithSkills.filter((m) => scheduleByMaster.has(m.id));
    const ordersInDay = ordersOnDay.filter((o) => {
      const start = (o as any).plannedStartTime ?? (o as any).dateTime;
      const d = start instanceof Date ? start : new Date(start);
      return d >= dayStart && d < dayEnd;
    });
    if (ordersInDay.length > 0) {
      console.warn(
        `ВНИМАНИЕ: На эту дату найдено ${ordersInDay.length} активных заказов, они блокируют расписание.`,
      );
    }
    const slotStartsForLog = slots.slice(0, 20).map((s) => s.start);
    console.log('[available-slots] date=', dto.date, 'timezone=', timezone, 'dayOfWeek=', dayOfWeek, '(0=Вс, 5=Пт, 6=Сб)');
    console.log('[available-slots] requiredSkills=', requiredSkills);
    console.log('[available-slots] mastersWithSchedule=', mastersOnDate.length, mastersOnDate.map((m) => m.name));
    console.log('[available-slots] ordersOnThisDate=', ordersInDay.length, ordersInDay.map((o) => ({ id: (o as any).id, masterId: (o as any).masterId, start: (o as any).plannedStartTime ?? (o as any).dateTime })));
    console.log('[available-slots] slot_duration_min=', slotDurationMinutes, 'total_minutes=', totalMinutes);
    console.log('[available-slots] slots.count=', slots.length, 'first starts (ISO)=', slotStartsForLog);

    return {
      slots,
      total_minutes: totalMinutes,
      required_skills: requiredSkills,
      slot_duration_minutes: slotDurationMinutes,
      work_day_start: wdStartStr,
      work_day_end: wdEndStr,
      scheduling_mode: 'staff_based',
    };
  }

  /** Слоты по числу постов (без привязки к мастеру). */
  private async computeBayBasedSlots(opts: {
    organizationId: string;
    dayStartLocal: DateTime;
    dayStart: Date;
    dayEnd: Date;
    totalMinutes: number;
    slotDurationMinutes: number;
    wdStartStr: string;
    wdEndStr: string;
    requiredSkills: string[];
    bayCount: number;
  }): Promise<{
    slots: TimeSlot[];
    total_minutes: number;
    required_skills: string[];
    slot_duration_minutes: number;
    work_day_start: string;
    work_day_end: string;
    scheduling_mode: string;
    bay_count: number;
  }> {
    const {
      organizationId,
      dayStartLocal,
      dayStart,
      dayEnd,
      totalMinutes,
      slotDurationMinutes,
      wdStartStr,
      wdEndStr,
      requiredSkills,
      bayCount,
    } = opts;
    const ordersOnDay = await this.orderRepo
      .createQueryBuilder('order')
      .where('order.organization_id = :orgId', { orgId: organizationId })
      .andWhere('order.status IN (:...statuses)', {
        statuses: ['pending_confirmation', 'confirmed', 'in_progress', 'pending_approval', 'completed'],
      })
      .andWhere(
        'COALESCE(order.planned_start_time, order.date_time) < :dayEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :dayStart',
        { dayStart: dayStart.toISOString(), dayEnd: dayEnd.toISOString() },
      )
      .getMany();

    const orderIntervals = ordersOnDay.map((o) => {
      const start = (o as any).plannedStartTime ?? (o as any).dateTime;
      const end = (o as any).plannedEndTime ?? addMinutes(start instanceof Date ? start : new Date(start), 60);
      return [new Date(start instanceof Date ? start : new Date(start)), new Date(end instanceof Date ? end : new Date(end))] as [Date, Date];
    });

    const countOrdersOverlapping = (slotStartMs: number, slotEndMs: number): number => {
      return orderIntervals.filter(([s, e]) => slotStartMs < e.getTime() && slotEndMs > s.getTime()).length;
    };

    const workStart = parseTime(wdStartStr);
    const workEnd = parseTime(wdEndStr);
    const localH = Math.floor(workStart / 60);
    const localMin = workStart % 60;
    const workStartLocal = dayStartLocal.set({ hour: localH, minute: localMin, second: 0, millisecond: 0 });
    const endH = Math.floor(workEnd / 60);
    const endMin = workEnd % 60;
    const workEndLocal = dayStartLocal.set({ hour: endH, minute: endMin, second: 0, millisecond: 0 });
    const workStartMs = workStartLocal.toUTC().toMillis();
    const workEndMs = workEndLocal.toUTC().toMillis();
    const totalMs = totalMinutes * 60 * 1000;
    const stepMs = slotDurationMinutes * 60 * 1000;

    const slots: TimeSlot[] = [];
    for (let t = workStartMs; t + totalMs <= workEndMs; t += stepMs) {
      const slotEndMs = t + totalMs;
      const overlapping = countOrdersOverlapping(t, slotEndMs);
      const free = bayCount - overlapping;
      // Клиент не выбирает пост: одно доступное время = один слот (ёмкость учтена в overlapping).
      if (free > 0) {
        slots.push({
          start: new Date(t).toISOString(),
          end: new Date(slotEndMs).toISOString(),
          master_id: '',
          master_name: '',
          scheduling_mode: 'bay_based',
        });
      }
    }
    slots.sort((a, b) => a.start.localeCompare(b.start));

    return {
      slots,
      total_minutes: totalMinutes,
      required_skills: requiredSkills,
      slot_duration_minutes: slotDurationMinutes,
      work_day_start: wdStartStr,
      work_day_end: wdEndStr,
      scheduling_mode: 'bay_based',
      bay_count: bayCount,
    };
  }

  /**
   * Временный метод для разработки: удалить все заказы и позиции заказов из БД,
   * чтобы очистить календарь от тестовых данных и проверить сетку слотов на чистом дне.
   */
  async clearTestOrders(): Promise<{ deletedOrders: number; deletedItems: number }> {
    const resultItem = await this.orderItemRepo.createQueryBuilder().delete().from(OrderItem).execute();
    const resultOrder = await this.orderRepo.createQueryBuilder().delete().from(Order).execute();
    const deletedItems = resultItem.affected ?? 0;
    const deletedOrders = resultOrder.affected ?? 0;
    console.log('[clear-test-orders] Удалено заказов:', deletedOrders, ', позиций:', deletedItems);
    return { deletedOrders, deletedItems };
  }
}
