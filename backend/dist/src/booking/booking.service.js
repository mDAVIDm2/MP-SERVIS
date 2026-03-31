"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BookingService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const luxon_1 = require("luxon");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const master_schedule_entity_1 = require("../organizations/master-schedule.entity");
const order_entity_1 = require("../orders/order.entity");
const order_item_entity_1 = require("../orders/order-item.entity");
const organizations_service_1 = require("../organizations/organizations.service");
const organization_scheduling_1 = require("../organizations/organization-scheduling");
const bay_settings_util_1 = require("../organizations/bay-settings.util");
const skill_enum_1 = require("../shared/skill.enum");
function parseTime(t) {
    const [h, m] = t.split(':').map(Number);
    return (h ?? 0) * 60 + (m ?? 0);
}
function addMinutes(date, minutes) {
    return new Date(date.getTime() + minutes * 60 * 1000);
}
function isOverlapping(slotStartMs, slotEndMs, merged) {
    return merged.some(([bs, be]) => slotStartMs < be.getTime() && slotEndMs > bs.getTime());
}
let BookingService = class BookingService {
    constructor(staffRepo, scheduleRepo, orderRepo, orderItemRepo, orgService) {
        this.staffRepo = staffRepo;
        this.scheduleRepo = scheduleRepo;
        this.orderRepo = orderRepo;
        this.orderItemRepo = orderItemRepo;
        this.orgService = orgService;
    }
    async getAvailableSlots(dto) {
        let totalMinutes = 0;
        let requiredSkills = [];
        const org = await this.orgService.findOne(dto.organization_id);
        const timezone = org?.timezone ?? 'Europe/Moscow';
        const schedulingMode = (0, organization_scheduling_1.normalizeSchedulingMode)(org?.schedulingMode);
        const settings = (await this.orgService.getSettings(dto.organization_id));
        const slotDurationMinutes = Math.max(15, Number(settings?.slots?.slot_duration_minutes) || 30);
        const slotsBlock = settings?.slots;
        const orgWorkStart = settings?.slots?.work_day_start ? parseTime(settings.slots.work_day_start) : null;
        const orgWorkEnd = settings?.slots?.work_day_end ? parseTime(settings.slots.work_day_end) : null;
        if (dto.service_ids?.length) {
            const servicesList = settings?.services ?? [];
            const services = Array.isArray(servicesList) ? servicesList : [];
            for (const sid of dto.service_ids) {
                const s = services.find((x) => x.id === sid);
                if (s) {
                    totalMinutes += Number(s.duration_minutes) ?? 60;
                    const skill = s.required_skill;
                    if (skill && !requiredSkills.includes(skill))
                        requiredSkills.push(skill);
                }
            }
            if (requiredSkills.length === 0)
                requiredSkills = [skill_enum_1.Skill.MAINTENANCE];
        }
        else if (dto.items?.length) {
            for (const item of dto.items) {
                const min = Number(item.estimated_minutes);
                totalMinutes += (Number.isNaN(min) ? 60 : (min ?? 60));
                const skill = item.required_skill;
                if (skill && !requiredSkills.includes(skill))
                    requiredSkills.push(skill);
            }
            if (requiredSkills.length === 0)
                requiredSkills = [skill_enum_1.Skill.MAINTENANCE];
        }
        else {
            totalMinutes = 60;
            requiredSkills = [skill_enum_1.Skill.MAINTENANCE];
        }
        const parts = dto.date.split('-').map((x) => parseInt(x, 10));
        const y = parts[0];
        const m = parts[1] ?? 1;
        const d = parts[2] ?? 1;
        const dayStartLocal = luxon_1.DateTime.fromObject({ year: y, month: m, day: d }, { zone: timezone }).startOf('day');
        const wdStartStr = settings?.slots?.work_day_start ?? '09:00';
        const wdEndStr = settings?.slots?.work_day_end ?? '20:00';
        const bayCount = (0, bay_settings_util_1.effectiveBayCountFromSlots)(slotsBlock);
        const emptyMeta = {
            slots: [],
            total_minutes: totalMinutes,
            required_skills: requiredSkills,
            slot_duration_minutes: slotDurationMinutes,
            work_day_start: wdStartStr,
            work_day_end: wdEndStr,
            scheduling_mode: schedulingMode,
            bay_count: schedulingMode === 'bay_based' ? bayCount : undefined,
        };
        if (!dayStartLocal.isValid)
            return emptyMeta;
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
            const skills = Array.isArray(m.skills) ? m.skills : [];
            return requiredSkills.every((need) => skills.includes(need));
        });
        if (mastersWithSkills.length === 0) {
            return { ...emptyMeta, scheduling_mode: 'staff_based' };
        }
        const masterIds = mastersWithSkills.map((x) => x.id);
        const schedules = await this.scheduleRepo.find({
            where: { masterId: (0, typeorm_2.In)(masterIds), dayOfWeek, isWorkingDay: true },
        });
        const scheduleByMaster = new Map();
        for (const sch of schedules) {
            let start = parseTime(sch.startTime);
            let end = parseTime(sch.endTime);
            if (orgWorkStart != null && orgWorkEnd != null) {
                start = Math.min(start, orgWorkStart);
                end = Math.max(end, orgWorkEnd);
            }
            const existing = scheduleByMaster.get(sch.masterId);
            if (!existing || start < existing.start)
                scheduleByMaster.set(sch.masterId, { start, end });
        }
        const ordersOnDay = await this.orderRepo
            .createQueryBuilder('order')
            .where('order.organization_id = :orgId', { orgId: dto.organization_id })
            .andWhere('order.status IN (:...statuses)', {
            statuses: ['pending_confirmation', 'confirmed', 'in_progress', 'pending_approval', 'completed'],
        })
            .andWhere('COALESCE(order.planned_start_time, order.date_time) < :dayEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :dayStart', { dayStart: dayStart.toISOString(), dayEnd: dayEnd.toISOString() })
            .getMany();
        const busyByMaster = new Map();
        const addBusyInterval = (masterId, startDate, endDate) => {
            const clipStart = new Date(Math.max(startDate.getTime(), dayStart.getTime()));
            const clipEnd = new Date(Math.min(endDate.getTime(), dayEnd.getTime()));
            if (clipStart >= clipEnd)
                return;
            if (!busyByMaster.has(masterId))
                busyByMaster.set(masterId, []);
            busyByMaster.get(masterId).push([clipStart, clipEnd]);
        };
        for (const o of ordersOnDay) {
            const start = o.plannedStartTime ?? o.dateTime;
            const end = o.plannedEndTime ?? addMinutes(start instanceof Date ? start : new Date(start), 60);
            const startDate = start instanceof Date ? start : new Date(start);
            const endDate = end instanceof Date ? end : new Date(end);
            const masterId = o.masterId ?? null;
            if (masterId)
                addBusyInterval(masterId, startDate, endDate);
        }
        const mastersOnShift = mastersWithSkills.filter((m) => scheduleByMaster.has(m.id));
        const mastersOnShiftCount = mastersOnShift.length;
        const totalMs = totalMinutes * 60 * 1000;
        const stepMs = slotDurationMinutes * 60 * 1000;
        const orderIntervals = ordersOnDay.map((o) => {
            const start = o.plannedStartTime ?? o.dateTime;
            const end = o.plannedEndTime ?? addMinutes(start instanceof Date ? start : new Date(start), 60);
            return [new Date(start instanceof Date ? start : new Date(start)), new Date(end instanceof Date ? end : new Date(end))];
        });
        const countOrdersOverlapping = (slotStartMs, slotEndMs) => {
            return orderIntervals.filter(([s, e]) => slotStartMs < e.getTime() && slotEndMs > s.getTime()).length;
        };
        const mergedByMaster = new Map();
        for (const master of mastersOnShift) {
            const busy = busyByMaster.get(master.id) ?? [];
            busy.sort((a, b) => a[0].getTime() - b[0].getTime());
            const merged = [];
            for (const [s, e] of busy) {
                if (merged.length && s.getTime() <= merged[merged.length - 1][1].getTime()) {
                    merged[merged.length - 1][1] = new Date(Math.max(merged[merged.length - 1][1].getTime(), e.getTime()));
                }
                else {
                    merged.push([s, e]);
                }
            }
            mergedByMaster.set(master.id, merged);
            console.log('Занятые интервалы мастера:', master.name, merged.map(([a, b]) => [a.toISOString(), b.toISOString()]));
        }
        const allSlotStarts = [];
        for (const master of mastersOnShift) {
            const work = scheduleByMaster.get(master.id);
            const localH = Math.floor(work.start / 60);
            const localMin = work.start % 60;
            const workStartLocal = dayStartLocal.set({ hour: localH, minute: localMin, second: 0, millisecond: 0 });
            const endH = Math.floor(work.end / 60);
            const endMin = work.end % 60;
            const workEndLocal = dayStartLocal.set({ hour: endH, minute: endMin, second: 0, millisecond: 0 });
            const workStartMs = workStartLocal.toUTC().toMillis();
            const workEndMs = workEndLocal.toUTC().toMillis();
            for (let t = workStartMs; t + totalMs <= workEndMs; t += stepMs)
                allSlotStarts.push(t);
        }
        const uniqueSlotStarts = [...new Set(allSlotStarts)].sort((a, b) => a - b);
        const masterWorkWindow = new Map();
        for (const master of mastersOnShift) {
            const work = scheduleByMaster.get(master.id);
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
        const slots = [];
        for (const slotStartMs of uniqueSlotStarts) {
            const slotEndMs = slotStartMs + totalMs;
            const overlappingOrders = countOrdersOverlapping(slotStartMs, slotEndMs);
            const mastersOnShiftAtSlot = mastersOnShift.filter((m) => {
                const w = masterWorkWindow.get(m.id);
                return slotStartMs >= w.start && slotEndMs <= w.end;
            });
            const freeCapacity = mastersOnShiftAtSlot.length - overlappingOrders;
            if (freeCapacity <= 0)
                continue;
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
        const mastersOnDate = mastersWithSkills.filter((m) => scheduleByMaster.has(m.id));
        const ordersInDay = ordersOnDay.filter((o) => {
            const start = o.plannedStartTime ?? o.dateTime;
            const d = start instanceof Date ? start : new Date(start);
            return d >= dayStart && d < dayEnd;
        });
        if (ordersInDay.length > 0) {
            console.warn(`ВНИМАНИЕ: На эту дату найдено ${ordersInDay.length} активных заказов, они блокируют расписание.`);
        }
        const slotStartsForLog = slots.slice(0, 20).map((s) => s.start);
        console.log('[available-slots] date=', dto.date, 'timezone=', timezone, 'dayOfWeek=', dayOfWeek, '(0=Вс, 5=Пт, 6=Сб)');
        console.log('[available-slots] requiredSkills=', requiredSkills);
        console.log('[available-slots] mastersWithSchedule=', mastersOnDate.length, mastersOnDate.map((m) => m.name));
        console.log('[available-slots] ordersOnThisDate=', ordersInDay.length, ordersInDay.map((o) => ({ id: o.id, masterId: o.masterId, start: o.plannedStartTime ?? o.dateTime })));
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
    async computeBayBasedSlots(opts) {
        const { organizationId, dayStartLocal, dayStart, dayEnd, totalMinutes, slotDurationMinutes, wdStartStr, wdEndStr, requiredSkills, bayCount, } = opts;
        const ordersOnDay = await this.orderRepo
            .createQueryBuilder('order')
            .where('order.organization_id = :orgId', { orgId: organizationId })
            .andWhere('order.status IN (:...statuses)', {
            statuses: ['pending_confirmation', 'confirmed', 'in_progress', 'pending_approval', 'completed'],
        })
            .andWhere('COALESCE(order.planned_start_time, order.date_time) < :dayEnd AND COALESCE(order.planned_end_time, order.planned_start_time + INTERVAL \'1 hour\', order.date_time + INTERVAL \'1 hour\') > :dayStart', { dayStart: dayStart.toISOString(), dayEnd: dayEnd.toISOString() })
            .getMany();
        const orderIntervals = ordersOnDay.map((o) => {
            const start = o.plannedStartTime ?? o.dateTime;
            const end = o.plannedEndTime ?? addMinutes(start instanceof Date ? start : new Date(start), 60);
            return [new Date(start instanceof Date ? start : new Date(start)), new Date(end instanceof Date ? end : new Date(end))];
        });
        const countOrdersOverlapping = (slotStartMs, slotEndMs) => {
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
        const slots = [];
        for (let t = workStartMs; t + totalMs <= workEndMs; t += stepMs) {
            const slotEndMs = t + totalMs;
            const overlapping = countOrdersOverlapping(t, slotEndMs);
            const free = bayCount - overlapping;
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
    async clearTestOrders() {
        const resultItem = await this.orderItemRepo.createQueryBuilder().delete().from(order_item_entity_1.OrderItem).execute();
        const resultOrder = await this.orderRepo.createQueryBuilder().delete().from(order_entity_1.Order).execute();
        const deletedItems = resultItem.affected ?? 0;
        const deletedOrders = resultOrder.affected ?? 0;
        console.log('[clear-test-orders] Удалено заказов:', deletedOrders, ', позиций:', deletedItems);
        return { deletedOrders, deletedItems };
    }
};
exports.BookingService = BookingService;
exports.BookingService = BookingService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(staff_member_entity_1.StaffMember)),
    __param(1, (0, typeorm_1.InjectRepository)(master_schedule_entity_1.MasterSchedule)),
    __param(2, (0, typeorm_1.InjectRepository)(order_entity_1.Order)),
    __param(3, (0, typeorm_1.InjectRepository)(order_item_entity_1.OrderItem)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        organizations_service_1.OrganizationsService])
], BookingService);
//# sourceMappingURL=booking.service.js.map